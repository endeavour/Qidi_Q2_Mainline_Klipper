#!/usr/bin/env python3
# Idempotently add CS1237 Kconfig symbols to src/Kconfig
import sys

MARKER = "WANT_CS1237"

BLOCK_DEFAULT = """config WANT_CS1237
    bool
    depends on HAVE_GPIO
    default y
"""

BLOCK_MENU = """config WANT_CS1237
    bool "Support CS1237 ADC chip"
    depends on HAVE_GPIO
"""


def merge(path):
    with open(path) as f:
        text = f.read()
    if MARKER in text:
        print("Kconfig already has CS1237 entries: %s" % path)
        return

    if "config WANT_HX71X\n    bool\n    depends on HAVE_GPIO" in text:
        text = text.replace(
            "config WANT_HX71X\n    bool\n    depends on HAVE_GPIO\n    default y\n",
            "config WANT_HX71X\n    bool\n    depends on HAVE_GPIO\n    default y\n"
            + BLOCK_DEFAULT,
            1)
    else:
        raise SystemExit("Could not find WANT_HX71X default block in %s" % path)

    text = text.replace(
        "|| WANT_HX71X || WANT_ADS1220 || WANT_LDC1612 || WANT_SENSOR_ANGLE",
        "|| WANT_HX71X || WANT_CS1237 || WANT_ADS1220 || WANT_LDC1612"
        " || WANT_SENSOR_ANGLE",
    )

    text = text.replace(
        "depends on WANT_ADC || WANT_HX71X || WANT_ADS1220 || WANT_LDC1612",
        "depends on WANT_ADC || WANT_HX71X || WANT_CS1237 || WANT_ADS1220"
        " || WANT_LDC1612",
    )

    if 'bool "Support HX711 and HX717 ADC chips"' in text:
        text = text.replace(
            'bool "Support HX711 and HX717 ADC chips"\n    depends on HAVE_GPIO\n',
            'bool "Support HX711 and HX717 ADC chips"\n    depends on HAVE_GPIO\n'
            + BLOCK_MENU + "\n",
            1,
        )

    with open(path, "w") as f:
        f.write(text)
    print("Merged CS1237 into %s" % path)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: merge_cs1237_kconfig.py <path/to/src/Kconfig>")
        sys.exit(1)
    merge(sys.argv[1])
