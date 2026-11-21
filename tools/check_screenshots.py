#!/usr/bin/env python3
"""Fail when a screenshot is older than what it shows (WFA-9, forever_tools.screens).

The gallery images are captures of the addon in game, so each image's dump is the hash of the files that lay out what
it shows: the window, its tabs and tooltips, the model that fills them and the English phrases. A change to any of
them marks every capture stale until it is retaken and `--record` rewrites docs/screenshots/scenes/<image>.sha256 (with
`--force` for a capture that came out the same).

    python3 tools/check_screenshots.py           # CI: fail on a stale image
    python3 tools/check_screenshots.py --record  # after the captures are retaken
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
SOURCES = (
    "Core/Model.lua",
    "Core/Report.lua",
    "Locales/enUS.lua",
    "UI/Characters.lua",
    "UI/CraftNow.lua",
    "UI/Format.lua",
    "UI/RowArt.lua",
    "UI/Shopping.lua",
    "UI/Tooltip.lua",
    "UI/Window.lua",
)
SCENES = {
    path.name: functools.partial(screens.files, ROOT, SOURCES)
    for pattern in screens.IMAGES
    for path in sorted(OUT.glob(pattern))
}


if __name__ == "__main__":
    sys.exit(screens.main(OUT, SCENES))
