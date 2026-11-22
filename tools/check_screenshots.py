#!/usr/bin/env python3
"""Fail when a mock screenshot is older than what it shows (WFA-9, forever_tools.screens).

The gallery renders come from tools/screenshots.py. The freshness check hashes the renderer, simulator scenario,
model, phrases and widgets to detect a stale mock.

    python3 tools/check_screenshots.py           # CI: fail on a stale image
    python3 tools/check_screenshots.py --record  # after the mocks are rendered again
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
    "media/Icon.tga",
    "tests/sim/professions_page_scenario.lua",
    "tools/forever-core.txt",
    "tools/screenshots.py",
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
