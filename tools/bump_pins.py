#!/usr/bin/env python3
"""Move the Forever and Classic Era generator pins to their newest upstream builds."""

import datetime
import json
import re
import sys
import urllib.request
from pathlib import Path

try:
    from forever_tools.latest_build import latest, version_key
except ModuleNotFoundError:
    from tools.forever_tools.latest_build import latest, version_key

TOOLS = Path(__file__).resolve().parent
BUILD = re.compile(r"\d+(\.\d+){3}")
USER_AGENT = "TradewindForever/1.0"


def newest(product, prefix):
    request = urllib.request.Request("https://wago.tools/api/builds", headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        builds = json.load(response).get(product, [])
    versions = [build["version"] for build in builds if build["version"].startswith(prefix)]
    if not versions:
        raise SystemExit(f"no {prefix}x build of {product} listed on wago.tools")
    return max(versions, key=version_key)


PINS = {
    "BUILD": ("gen_thresholds.py", "Forever", BUILD, lambda _: latest(USER_AGENT)),
    "TEACH_BUILD": ("gen_thresholds.py", "Classic Era", BUILD, lambda _: newest("wow_classic_era", "1.1")),
}


def repin(source, name, value):
    """Return source with one module-level string pin replaced, and the value it held."""
    line = re.compile(rf"^{name} = \"([^\"]*)\"$", re.MULTILINE)
    found = line.findall(source)
    if len(found) != 1:
        raise SystemExit(f"expected one {name} pin, found {len(found)}")
    return line.sub(f'{name} = "{value}"', source), found[0]


def main():
    moved = []
    for name, (filename, label, shape, newest_value) in PINS.items():
        path = TOOLS / filename
        source = path.read_text(encoding="utf-8")
        _, pinned = repin(source, name, "")
        value = newest_value(pinned)
        if not shape.fullmatch(value):
            raise SystemExit(f"{name}: upstream gave {value!r}")
        if value == pinned:
            print(f"{name}: already on {pinned}", file=sys.stderr)
            continue
        path.write_text(repin(source, name, value)[0], encoding="utf-8")
        moved.append(f"{label} {value[:12]}")
    if moved:
        path = TOOLS / "gen_thresholds.py"
        today = datetime.datetime.now(datetime.UTC).date().isoformat()
        path.write_text(repin(path.read_text(encoding="utf-8"), "SOURCE_DATE", today)[0], encoding="utf-8")
        print(", ".join(moved))


if __name__ == "__main__":
    main()
