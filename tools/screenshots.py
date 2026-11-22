"""Render Tradewind's Professions and report mock screenshots from the pinned client art.

Fetch the simulator data with tools/forever_sim/fetch.py first. Then set FOREVER_CORE
to the core checkout and run this file with Pillow 13.0.0. It reads the text, rows,
tooltips and tab sizes that the addon creates in the simulator. The canvas uses the
client's templates and their offsets to reproduce that state without running WoW.
"""

import argparse
import os
import subprocess
import sys
from dataclasses import replace
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
CORE = Path(os.environ.get("FOREVER_CORE", ROOT.parent / "forever-core")).resolve()
MOCK = CORE / "tools/wowmock"
if not (MOCK / "wowmock.py").is_file():
    sys.exit(f"wowmock.py not found in {MOCK}; set FOREVER_CORE to the ForeverCore checkout")
sys.path.insert(0, str(MOCK))

from wowmock import (  # ty: ignore[import-not-found]
    ARIALN,
    FONTS,
    INSET_FRAME_LAYOUT,
    Font,
    TooltipLine,
    Ui,
    cooldown_icon,
    minimal_scrollbar,
    portrait_frame_art,
    scene,
    search_box,
    side_tab,
    three_slice_button,
    tiled,
    tooltip,
    wrap_text,
)

BUILD = "1.60.1.70124"
PAGES = ("craft", "shopping", "characters")
# The before proof uses the prior Craft now coordinates and width floor.
LEGACY_CRAFT_COLUMNS = [
    (36, 190, "LEFT"),
    (232, 100, "LEFT"),
    (336, 44, "RIGHT"),
    (388, 78, "RIGHT"),
    (470, 70, "RIGHT"),
    (544, 40, "RIGHT"),
]
SCENARIO = "tests/sim/professions_page_scenario.lua"


def capture_widgets(cooking=False, width=None):
    env = {**os.environ, "FOREVER_CORE": str(CORE), "TRADEWIND_MOCK_SCENES": "1"}
    if cooking:
        env["TRADEWIND_MOCK_COOKING"] = "1"
    if width:
        env["TRADEWIND_MOCK_WIDTH"] = str(width)
    result = subprocess.run(
        ["luajit", "tools/forever_sim/run.lua", SCENARIO, "--only=mock proof"],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode:
        sys.exit(result.stdout + result.stderr)
    return result.stdout


def read_widgets(dump):
    result = {"host": {}}
    section = result["host"]
    for line in dump.splitlines():
        if not line.startswith("PROOF\t"):
            continue
        _, kind, *fields = line.split("\t")
        if kind == "section":
            section = result.setdefault(fields[0], {})
        else:
            section.setdefault(kind, []).append(fields)
    return result


def native_tab(canvas, x, bottom, width, height, text, selected):
    # PanelTopTabButtonMixin flips the cap art and selects the bottom three quarters of each atlas.
    ui = canvas.ui
    prefix = "uiframe-activetab" if selected else "uiframe-tab"
    left, middle, right = (
        ui.atlas(f"{prefix}-left"),
        ui.atlas(f"_{prefix}-center"),
        ui.atlas(f"{prefix}-right"),
    )
    x_left = x - (1 if selected else 3)
    x_right = x + width + (8 if selected else 7) - right.width
    for art, art_x, art_w in (
        (left, x_left, left.width),
        (middle, x_left + left.width, x_right - x_left - left.width),
        (right, x_right, right.width),
    ):
        height_drawn = art.height * 0.75
        image = art.image.crop((0, round(art.image.height / 4), art.image.width, art.image.height))
        image = image.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        canvas.draw(replace(art, image=image, height=height_drawn), art_x, bottom - height_drawn, art_w, height_drawn)
    font = FONTS["GameFontHighlightSmall" if selected else "GameFontNormalSmall"]
    canvas.text(
        x, bottom - height / 2 - 5 + (4 if selected else 8), text, font, width=width, box_height=10, justify="CENTER"
    )


def professions_mock(ui, host, widgets, page, hover=False, proof=None):
    host_w, host_h, profession = host["host"][0]
    width, height = float(host_w), float(host_h)
    scroll_width, scroll_height, total_height = map(float, widgets["scroll"][0])
    canvas = ui.canvas(width + 80, height + 32)
    fx, fy = 14, 14
    page_x, page_y = fx + 4, fy + 28
    inset_x, inset_y = page_x + 14, page_y + 78
    inset_w, inset_h = width - 36, height - 154
    canvas.draw(ui.atlas("Profession-Background-Overview"), page_x, page_y, width - 8, height - 32)
    icon = 133971 if profession == "Cooking" else 136241
    portrait_frame_art(canvas, fx, fy, width, height, icon, profession)
    if proof == "before":
        # Model the lifted page covering the part of the native portrait inside its bounds.
        canvas.draw(ui.atlas("Profession-Background-Overview"), page_x, page_y, width - 8, height - 32)
    # Same fallback as SkillUp's mock: the native Overview icon has no known FileDataID.
    side_tab(canvas, fx + width, fy + 60, 136241)
    side_tab(canvas, fx + width, fy + 117, 136241)
    side_tab(canvas, fx + width, fy + 174, 133971 if profession == "Cooking" else 136248)
    side_tab(canvas, fx + width, fy + 231, 133785, selected=True)

    title, summary, footer = (line[0] for line in widgets["text"])
    canvas.text(page_x + 74, page_y + 12, title, FONTS["GameFontNormalLarge"])
    canvas.text(page_x + width - 370, page_y + 16, summary, FONTS["GameFontHighlightSmall"], width=340, justify="RIGHT")
    search_box(canvas, page_x + 22, page_y + 48, 200)
    canvas.draw(ui.atlas("common-insideframe"), inset_x + 2, inset_y + 2, inset_w - 4, inset_h - 4)
    tab_x = page_x + 236
    for tab_page, (text, w, h, *_anchors) in zip(PAGES, host["tab"], strict=True):
        w, h = float(w), float(h)
        native_tab(canvas, tab_x, inset_y + 2, w, h, text, selected=tab_page == page)
        tab_x += w + 3

    headings = widgets["heading"]
    columns = [(float(x) - 4, float(w), align) for _, x, w, align in headings]
    if proof == "before":
        stretch = max(1, scroll_width / 584)
        columns = [(x * stretch, w * stretch, align) for x, w, align in LEGACY_CRAFT_COLUMNS]
    for (heading, *_), (x, w, align) in zip(headings, columns, strict=True):
        canvas.text(
            inset_x + 4 + x,
            inset_y + 10,
            heading,
            FONTS["GameFontNormalSmall"],
            width=w,
            justify=align,
        )
    rows = widgets.get("row", [])
    if not rows:
        canvas.text(inset_x + 12, inset_y + 42, widgets["empty"][0][0], FONTS["GameFontDisableSmall"])

    list_x, list_y = inset_x + 4, inset_y + 32
    visible = canvas.ui.canvas(scroll_width, scroll_height)
    for index, (item_id, lines) in enumerate(rows[: int(scroll_height / 30) + 1]):
        row_y = 30 * index
        atlases = [("common-button-list-large", "BLEND")]
        if hover and index == 0:
            atlases.append(("common-button-list-large-hover", "ADD"))
        for atlas, blend in atlases:
            art = ui.atlas(atlas)
            scale = 30 / art.height
            art = replace(art, width=art.width * scale, height=30, slice=tuple(m * scale for m in art.slice))
            visible.draw(art, 4, row_y, scroll_width - 8, 30, blend=blend)
        if item_id:
            cooldown_icon(visible, 8, row_y + 3, 24, ui.item(int(item_id)).icon)
        for label, (x, w, align) in zip(lines.split(" | "), columns, strict=True):
            visible.text(4 + x, row_y + 8, label, FONTS["GameFontHighlight"], width=w, justify=align)
    canvas.paste(visible, list_x, list_y)
    if total_height > scroll_height:
        minimal_scrollbar(
            canvas, list_x + scroll_width + 6, list_y - 2, scroll_height - 3, scroll_height / total_height
        )
    canvas.text(page_x + 22, fy + height - 32, footer, FONTS["GameFontHighlight"])
    if page == "craft":
        three_slice_button(canvas, fx + width - 168, fy + height - 38, 150, 24, "Shopping list")

    if proof:
        marks = ImageDraw.Draw(canvas.image)
        for box in (
            (fx - 3, fy - 7, fx + 55, fy + 51),
            (inset_x - 2, inset_y - 2, inset_x + inset_w + 2, inset_y + inset_h + 2),
            (inset_x + scroll_width - 122, inset_y + 7, inset_x + scroll_width + 7, inset_y + 25),
        ):
            marks.rectangle(tuple(canvas.px(v) for v in box), outline="#ffd058", width=2)
        canvas.text(fx + 65, fy + 27, f"MOCK | {proof.upper()}", FONTS["GameFontNormalSmall"])
    layers = [(canvas, 0, 0)]
    if hover:
        lines = [TooltipLine(left, tuple(map(float, rgb)), right or None) for left, right, *rgb in widgets["tip"]]
        layers.append((tooltip(ui, lines), list_x + scroll_width - 4, list_y))
    return scene(ui, layers, margin=10)


def report_mock(ui, widgets):
    # ForeverCore.UI/Report.lua: native portrait frame, inset and scroll area with all text selected.
    width, height = map(float, widgets["size"][0])
    canvas = ui.canvas(width + 28, height + 28)
    x, y = 14, 14
    rock = ui.texture("interface/framegeneral/ui-background-rock.blp")
    tiled(canvas, rock, x + 2, y + 21, width - 4, height - 23, rock.width, rock.height)
    canvas.draw(ui.atlas("_UI-Frame-TopTileStreaks"), x, y + 21, width - 2, 43)
    portrait_frame_art(
        canvas,
        x,
        y,
        width,
        height,
        Image.open(ROOT / "media/Icon.tga"),
        "Tradewind Forever report",
    )
    hint = "The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it, then paste it into your bug report."
    font = FONTS["GameFontNormal"]
    canvas.text(x + 70, y + 32, "\n".join(wrap_text(canvas, hint, font, width - 86)), font)
    marble = ui.texture("interface/framegeneral/ui-background-marble.blp")
    tiled(canvas, marble, x + 12, y + 66, width - 24, height - 78, marble.width, marble.height)
    canvas.nine_slice(INSET_FRAME_LAYOUT, x + 10, y + 64, width - 20, height - 74)
    # ChatFontNormal inherits NumberFont_Shadow_Med in Blizzard_Fonts_Shared.
    font = Font(ARIALN, 14, shadow=(1, -1))
    line_y = y + 72
    lines = [row for raw in widgets["log"] for row in wrap_text(canvas, raw[0], font, width - 66)]
    for line in lines:
        if line_y + font.height > y + height - 18:
            break
        canvas.fill(x + 18, line_y, canvas.text_width(line, font), font.height, (0.26, 0.26, 0.26, 1))
        canvas.text(x + 18, line_y, line, font)
        line_y += font.height
    minimal_scrollbar(canvas, x + width - 32, y + 70, height - 91, min(1, (height - 90) / (len(lines) * font.height)))
    return scene(ui, [(canvas, 0, 0)], margin=10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/screenshots")
    parser.add_argument("--cooking-proof", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    ui = Ui(build=BUILD, scale=1)
    if args.cooking_proof:
        for label, width in (("default", None), ("narrow", 620)):
            widgets = read_widgets(capture_widgets(cooking=True, width=width))
            for state in ("before", "after"):
                professions_mock(ui, widgets["host"], widgets["craft"], "craft", proof=state).save(
                    args.output / f"cooking-{label}-{state}.png"
                )
        return
    widgets = read_widgets(capture_widgets())
    for name, key, hover in (
        ("craft-now", "craft", False),
        ("craft-now-tooltip", "craft", True),
        ("shopping", "shopping", False),
        ("characters", "characters", True),
    ):
        professions_mock(ui, widgets["host"], widgets[key], key, hover).save(args.output / f"{name}.png")
    report_mock(ui, widgets["report"]).save(args.output / "report.png")


if __name__ == "__main__":
    main()
