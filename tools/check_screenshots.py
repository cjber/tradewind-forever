#!/usr/bin/env python3
"""Fail when a screenshot is older than what it shows (WFA-9, forever_tools.screens).

Until the profit window exists the three gallery images are copies of the icon, so each image's dump is the icon's
hash. Once the window ships, tools/screenshots.py renders the scenes and SOURCES names the layout files it reads.
docs/screenshots/scenes.sha256 holds each image's hash beside its dump's; after a render, `--record` rewrites it
(with `--force` for an image that came out the same).

    python3 tools/check_screenshots.py           # CI: fail on a stale image
    python3 tools/check_screenshots.py --record  # after the images are rendered
"""

import functools
import sys
from pathlib import Path

try:
    from tools.forever_tools import screens
except ModuleNotFoundError:
    from forever_tools import screens

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/screenshots"
SOURCES = ("media/icon-400.png",)
SCENES = {
    path.name: functools.partial(screens.files, ROOT, SOURCES)
    for pattern in screens.IMAGES
    for path in sorted(OUT.glob(pattern))
}


if __name__ == "__main__":
    sys.exit(screens.main(OUT, SCENES))
