# Third-party inputs

Everything Tradewind Forever is built from that it did not write itself: where each comes from, where its pin lives, its
licence, and whether any of it reaches the zip players install. The addon itself is GPL-3.0-or-later ([LICENSE](LICENSE)).

## Ships in the zip

| Input | Used for | Pin | Licence |
|---|---|---|---|
| [ForeverCore](https://github.com/cjber/forever-core) | The shared runtime: registration, the report window, the credits page, profession tabs and the public API kit, embedded under `Libs/ForeverCore` by the release workflow | `tools/forever-core.txt` | MIT |

`media/` is this addon's own: the icon is drawn in `media/icon.svg`.

## Read in game, never bundled

| Input | Used for | Licence |
|---|---|---|
| Auctionator, if installed | Auction prices and their age, through its public API | Their own; nothing is copied |
| TradeSkillMaster, if installed | Auction prices and sales per day, through its public price sources | Their own; nothing is copied |
| Syndicator, if installed | What your other characters hold in bags and bank, through its public API | Their own; nothing is copied |

## Build and test only

| Input | Used for | Pin | Licence |
|---|---|---|---|
| [WoW: Forever and Classic Era client tables, via wago.tools](https://wago.tools) | Skill thresholds, profession membership, reagents, recipe outputs and positive vendor sell-back prices in `tools/data/Thresholds.lua` and `Data/Recipes.lua`; the generators read `SkillLineAbility`, `SkillLine`, `SpellReagents`, `SpellEffect`, `ItemSparse`, `SpellName`, `ItemEffect` and `ItemXItemEffect` | `BUILD` and `TEACH_BUILD` in `tools/gen_thresholds.py` | Blizzard Entertainment's game data; build-only, never bundled |
| [Ketho's WoW API annotations](https://github.com/Ketho/vscode-wow-api) | lua-language-server types in `tools/typecheck.sh` | `revision` in `tools/typecheck.sh` | MIT |
| [FrameXML annotations](https://github.com/NumyAddon/FramexmlAnnotations) | FrameXML types, the Ketho checkout's `Annotations/FrameXML` submodule | The gitlink in that Ketho revision | MIT |
| [forever_tools](https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-forever-addon/tooling/forever_tools) | Shared lints and release checks, vendored in `tools/forever_tools/` | `revision` in `tools/forever_tools/MANIFEST.json` | MIT |
| Ko-fi's Support me on Ko-fi button | The support button in the README (`ko-fi.com/img/githubbutton_sm.svg`) and its PNG render, `docs/kofi-button.png`, in the store description | None: the README links Ko-fi's live file; the PNG is rendered from it | Ko-fi's brand asset, used as Ko-fi provides it for linking to a Ko-fi page |
| `docs/github-sponsors-button.png` | The GitHub Sponsors button in the README and store description; drawn here to match the Ko-fi button, with the heart from GitHub's [Octicons](https://github.com/primer/octicons) and the Adwaita Sans font | None | Octicons: MIT; Adwaita Sans: SIL OFL 1.1 |
| `docs/discord-button.png` | The Discord button on the store page; drawn in forever-core with Discord's logo from [Simple Icons](https://simpleicons.org) and the Adwaita Sans font | None | Simple Icons: CC0; Adwaita Sans: SIL OFL 1.1; the logo is Discord's, used to link to a Discord server |

CI tools (StyLua, ruff, ty, luacheck, lua-language-server, actionlint, zizmor, gitleaks, the BigWigs packager) are pinned in `.github/workflows/` and `tools/typecheck.sh`, except luajit and luacheck, which come from the runner's apt; they build and check the addon and are never part of it.

## Players

Credit for the reports and requests behind the addon.

| Who | What | Notes |
|---|---|---|

## Inspired by

Credit for the addons and projects an idea came from.

| Who | What | Notes |
|---|---|---|
| [SkillUp Forever](https://github.com/cjber/skillup-forever) | The recipe and price design | Same author; the same recipe universe is planned. |
