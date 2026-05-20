#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

KLIPPER_DIR="${KLIPPER_DIR:-$HOME/klipper}"
KATAPULT_DIR="${KATAPULT_DIR:-$HOME/katapult}"
PATCH_DIR="$SCRIPT_DIR/klipper_patch"

KATAPULT_PATCH="$SCRIPT_DIR/patches/katapult/0001-q2-mainboard-usb.patch"
KATAPULT_FALLBACK_COMMIT="b0bf421069e2aab810db43d6e15f38817d981451"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_git_repo() {
  local repo="$1"
  if [ ! -d "$repo/.git" ]; then
    die "Not a git repository: $repo"
  fi
}

apply_klipper_patch() {
  [ -f "$KLIPPER_DIR/klippy/extras/bulk_sensor.py" ] \
    || die "Missing stock bulk_sensor.py in $KLIPPER_DIR"

  echo "Applying Klipper changes from klipper_patch/ (stock bulk_sensor.py preserved)"

  install -D "$PATCH_DIR/klippy/extras/cs1237.py" \
    "$KLIPPER_DIR/klippy/extras/cs1237.py"

  python3 "$SCRIPT_DIR/scripts/merge_cs1237_extras.py" \
    "$KLIPPER_DIR/klippy/extras/load_cell.py" \
    "$KLIPPER_DIR/klippy/extras/load_cell_probe.py"

  install -D "$PATCH_DIR/src/sensor_cs1237.c" \
    "$KLIPPER_DIR/src/sensor_cs1237.c"
  install -D "$PATCH_DIR/src/generic/usb_cdc_ep.h" \
    "$KLIPPER_DIR/src/generic/usb_cdc_ep.h"
  cp "$PATCH_DIR/src/stm32/usbotg.c" "$KLIPPER_DIR/src/stm32/usbotg.c"

  python3 "$SCRIPT_DIR/scripts/merge_cs1237_kconfig.py" \
    "$KLIPPER_DIR/src/Kconfig"

  if ! grep -q 'STM32F4_GD32_USB_INIT_WORKAROUND' "$KLIPPER_DIR/src/stm32/Kconfig" 2>/dev/null; then
    python3 - <<'PY' "$KLIPPER_DIR/src/stm32/Kconfig" "$PATCH_DIR/src/stm32/Kconfig"
import sys
dst, src = sys.argv[1], sys.argv[2]
block = open(src).read().split("config STM32F4_GD32_USB_INIT_WORKAROUND")[1]
block = ("config STM32F4_GD32_USB_INIT_WORKAROUND" + block
         .split("\n\n######################################################################")[0])
text = open(dst).read()
if "STM32F4_GD32_USB_INIT_WORKAROUND" not in text:
    idx = text.find("config STM32F0_TRIM")
    end = text.find("\n\n######################################################################", idx)
    text = text[:end] + "\n" + block + text[end:]
    open(dst, "w").write(text)
    print("Merged GD32 USB Kconfig into", dst)
PY
  fi

  if ! grep -q 'sensor_cs1237' "$KLIPPER_DIR/src/Makefile"; then
    sed -i '/sensor_hx71x/a src-$(CONFIG_WANT_CS1237) += sensor_cs1237.c' \
      "$KLIPPER_DIR/src/Makefile"
    echo "Added sensor_cs1237.c to Makefile"
  fi

  if grep -q '^TRSYNC_TIMEOUT = 0.025' "$KLIPPER_DIR/klippy/mcu.py"; then
    sed -i 's/^TRSYNC_TIMEOUT = 0.025$/TRSYNC_TIMEOUT = 0.050/' \
      "$KLIPPER_DIR/klippy/mcu.py"
    echo "Updated TRSYNC_TIMEOUT in klippy/mcu.py"
  fi
}

echo "Using Klipper repo:  $KLIPPER_DIR"
echo "Using Katapult repo: $KATAPULT_DIR"

[ -f "$KATAPULT_PATCH" ] || die "Missing patch file: $KATAPULT_PATCH"
[ -d "$PATCH_DIR" ] || die "Missing klipper_patch directory"

require_git_repo "$KLIPPER_DIR"
require_git_repo "$KATAPULT_DIR"

echo
apply_klipper_patch

echo
echo "Checking Katapult patch applicability..."
if ! git -C "$KATAPULT_DIR" apply --check "$KATAPULT_PATCH"; then
  cat <<EOF
Katapult patch did not apply cleanly to $KATAPULT_DIR.
Try checking out the known-good fallback commit and rerun:

  cd "$KATAPULT_DIR" && git checkout $KATAPULT_FALLBACK_COMMIT
EOF
  exit 1
fi

echo "Applying Katapult patch..."
git -C "$KATAPULT_DIR" apply "$KATAPULT_PATCH"

echo
echo "Patch apply complete."
echo "Klipper: applied from klipper_patch/ (compatible with latest mainline)."
echo "Next steps: build/flash Katapult and Klipper per docs/INSTALL.md."
