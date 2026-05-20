#!/usr/bin/env python3
# Idempotently register cs1237 in load_cell.py and load_cell_probe.py
import sys


def merge_file(path):
    with open(path) as f:
        lines = f.readlines()
    if any("cs1237" in l for l in lines):
        print("Already patched: %s" % path)
        return
    out = []
    sensors_done = False
    for line in lines:
        if ("from . import" in line and "hx71x" in line and "ads1220" in line
                and "load_cell_probe" in path):
            line = line.replace("hx71x, ", "hx71x, cs1237, ")
        elif line.strip() == "from . import hx71x":
            out.append(line)
            out.append("from . import cs1237\n")
            continue
        out.append(line)
        if (not sensors_done
                and "sensors.update(hx71x.HX71X_SENSOR_TYPES)" in line):
            indent = line[: len(line) - len(line.lstrip())]
            out.append("%ssensors.update(cs1237.CS1237_SENSOR_TYPE)\n" % indent)
            sensors_done = True
    if not sensors_done:
        raise SystemExit("Could not find sensor registration in %s" % path)
    with open(path, "w") as f:
        f.writelines(out)
    print("Patched: %s" % path)


if __name__ == "__main__":
    for path in sys.argv[1:]:
        merge_file(path)
