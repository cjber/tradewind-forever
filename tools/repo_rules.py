#!/usr/bin/env python3
"""Check the rules this repository holds that no linter covers. CI runs it in the `project-rules` job.

- `syndicator-outside-integration`: only Integrations/Syndicator.lua names Syndicator. Its API is read in one place,
  through pcall and validated, so a missing, not-ready or malformed Syndicator is handled once and every other file
  sees a plain table or nil.
- `minimap-button`: no minimap button and no LibDBIcon or LibDataBroker. The addon opens from its slash words, the
  Professions side tab and the addon compartment.
- `chat-output`: no `print`, `SendChatMessage`, `DEFAULT_CHAT_FRAME` or a chat frame's `AddMessage`. Nothing is
  written to chat; a line the player should see goes on screen.
- `blizzard-table-write`: no assignment into a field of a Blizzard frame or table. Blizzard frames are read, hooked
  with `HookScript` or `hooksecurefunc`, and never written, so the addon cannot taint them.
- `unused-luacheck-global`: every `globals`/`read_globals` entry in .luacheckrc is named by some Lua or XML file;
  luacheck never reports an allowed global that nothing reads. Locales/phrases.txt counts as Lua: translators copy
  it into Locales/<locale>.lua, so its `GetLocale()` line needs the entry.
- `workflow-hashfiles-unmatched`: every pattern a workflow passes to `hashFiles()` matches a tracked file. A cache
  key built from a pattern that matches nothing never changes when the file it was meant to track does.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP = ("tests/", "types/", "tools/")
SYNDICATOR_OWNER = "Integrations/Syndicator.lua"
SYNDICATOR = re.compile(r"(?<![A-Za-z0-9_])Syndicator(?![A-Za-z0-9_])")
MINIMAP = re.compile(r"LibDBIcon|LibDataBroker|MinimapButton|Minimap\w*Button|LDBIcon")
CHAT = re.compile(r"(?<![A-Za-z0-9_.:])print\s*\(|SendChatMessage|DEFAULT_CHAT_FRAME|ChatFrame\d*:AddMessage")
BLIZZARD = (
    "GameTooltip",
    "ItemRefTooltip",
    "ProfessionsFrame",
    "ProfessionsBookFrame",
    "TradeSkillFrame",
    "UIParent",
    "WorldMapFrame",
    "ObjectiveTrackerFrame",
)
BLIZZARD_WRITE = re.compile(r"(?<![A-Za-z0-9_.])(" + "|".join(BLIZZARD) + r")(\.[A-Za-z_]\w*)+\s*=(?!=)")
LUACHECK = ".luacheckrc"
LUA_LIKE = re.compile(r"\.(lua|xml)$")
LUA_TEMPLATES = {"Locales/phrases.txt"}
WORKFLOW = re.compile(r"^\.github/workflows/[^/]+\.ya?ml$")
HASHFILES = re.compile(r"hashFiles\(([^)]*)\)")
QUOTED = re.compile(r"'([^']*)'")


def lua_code(line: str) -> str:
    """The line before its `--` comment, a `--` inside a quoted string left alone."""
    quote = None
    for index, char in enumerate(line):
        if quote:
            if char == "\\":
                continue
            if char == quote and line[index - 1] != "\\":
                quote = None
        elif char in "\"'":
            quote = char
        elif line.startswith("--", index):
            return line[:index]
    return line


def syndicator_reads(files: dict[str, str]) -> list[str]:
    hits = []
    for path, text in files.items():
        if not LUA_LIKE.search(path) or path.startswith(SKIP) or path == SYNDICATOR_OWNER:
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if SYNDICATOR.search(lua_code(line)):
                hits.append(
                    f"{path}:{number}: syndicator-outside-integration: read Syndicator only in {SYNDICATOR_OWNER}"
                )
    return hits


def minimap_buttons(files: dict[str, str]) -> list[str]:
    hits = []
    for path, text in files.items():
        if not LUA_LIKE.search(path) or path.startswith(SKIP):
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if MINIMAP.search(lua_code(line)):
                hits.append(
                    f"{path}:{number}: minimap-button: open from the slash words, the side tab or the addon compartment"
                )
    return hits


def chat_output(files: dict[str, str]) -> list[str]:
    hits = []
    for path, text in files.items():
        if not LUA_LIKE.search(path) or path.startswith(SKIP):
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if CHAT.search(lua_code(line)):
                hits.append(f"{path}:{number}: chat-output: nothing is written to chat; show it on screen")
    return hits


def blizzard_writes(files: dict[str, str]) -> list[str]:
    hits = []
    for path, text in files.items():
        if not LUA_LIKE.search(path) or path.startswith(SKIP):
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if BLIZZARD_WRITE.search(lua_code(line)):
                hits.append(f"{path}:{number}: blizzard-table-write: hook the Blizzard frame, never assign into it")
    return hits


def luacheck_entries(text: str) -> list[tuple[str, int]]:
    """(name, line) for each quoted name inside a `globals` or `read_globals` table that opens its own line."""
    found, inside = [], False
    for number, line in enumerate(text.splitlines(), 1):
        if re.match(r"\s*(read_)?globals\s*=\s*\{", line):
            inside = True
        if inside:
            found += [(name, number) for name in re.findall(r'"([A-Za-z_][A-Za-z0-9_]*)"', line)]
            if "}" in line:
                inside = False
    return found


def unused_luacheck_globals(files: dict[str, str]) -> list[str]:
    if LUACHECK not in files:
        return []
    corpus = "\n".join(t for p, t in files.items() if p != LUACHECK and (LUA_LIKE.search(p) or p in LUA_TEMPLATES))
    return [
        f"{LUACHECK}:{line}: unused-luacheck-global: `{name}` is named by no Lua or XML file; delete the entry"
        for name, line in luacheck_entries(files[LUACHECK])
        if not re.search(r"(?<![A-Za-z0-9_])" + re.escape(name) + r"(?![A-Za-z0-9_])", corpus)
    ]


def glob_matcher(pattern: str) -> re.Pattern[str]:
    parts = re.split(r"(\*\*/?|\*)", pattern)
    body = "".join(".*" if p.startswith("**") else "[^/]*" if p == "*" else re.escape(p) for p in parts)
    return re.compile(body + r"\Z")


def unmatched_hashfiles(files: dict[str, str]) -> list[str]:
    hits = []
    for path, text in files.items():
        if not WORKFLOW.match(path):
            continue
        for number, line in enumerate(text.splitlines(), 1):
            for call in HASHFILES.findall(line):
                for pattern in QUOTED.findall(call):
                    if pattern.startswith("!"):
                        continue
                    if not any(glob_matcher(pattern).match(p) for p in files):
                        hits.append(f"{path}:{number}: workflow-hashfiles-unmatched: `{pattern}` matches no file")
    return hits


RULES = (
    syndicator_reads,
    minimap_buttons,
    chat_output,
    blizzard_writes,
    unused_luacheck_globals,
    unmatched_hashfiles,
)


def findings(files: dict[str, str]) -> list[str]:
    return [hit for rule in RULES for hit in rule(files)]


def tracked_files() -> dict[str, str]:
    listing = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z"], capture_output=True, check=True).stdout
    files = {}
    for path in listing.decode().split("\0"):
        file = ROOT / path
        if path and file.is_file():
            files[path] = file.read_text(encoding="utf-8", errors="replace")
    return files


def main() -> int:
    hits = findings(tracked_files())
    for hit in hits:
        print(hit)
    return int(bool(hits))


if __name__ == "__main__":
    sys.exit(main())
