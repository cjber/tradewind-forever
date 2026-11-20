# AGENTS.md

Tradewind Forever is a WoW: Forever addon (Interface 16001): one crafting profit list across this account's characters,
counting only what each can make from its own bags and bank, priced through Auctionator or TradeSkillMaster when
installed (a price is unknown otherwise, never zero). It carries ForeverCore inside its zip (`X-Forever-Core-Embed: 1`,
the release pinned in `tools/forever-core.txt`), which owns registration, the report window, the credits page,
profession tabs and the API kit. It lists and explains; it never crafts, buys or posts. Players install the zip the
BigWigs packager builds on a `v*` tag.

## Commands

```sh
python3 tools/doctor.py             # first on a new machine: every tool pin, with a fix for each problem
python3 tools/gate.py               # the fast local gate: format, lint, typecheck, specs, changelog, rules
python3 tools/gate.py --changed     # only the steps the diff against origin/main reaches
```

`gate.py` loads ForeverCore from `$FOREVER_CORE`, else `../forever-core`: set it in a worktree. Its typecheck step runs
`tools/typecheck.sh` (about 5 GB); run the other steps locally and leave typecheck to CI. CI adds the simulator, the
package build (with the embed step), actionlint, zizmor and gitleaks. A change's player-facing notes go in
`changes/<issue>.md`; only the release commit edits `CHANGELOG.md` (`python3 tools/changelog.py release X.Y.Z`).
Release: `.agents/skills/release/SKILL.md`.

## Layout

- `Core/ForeverRequire.lua` is copied byte for byte from forever-core's `tools/consumer/`: never edit it.
  `Core/Require.lua` calls it with the member checks (every ForeverCore member this addon calls, and the minor of
  the modules that carry one) and the slash words; `tests/core_dependency_spec.lua` covers each member.
- `Core/Core.lua` registers with ForeverCore once (`ns.core`) and owns the slash command, the saved variables and the
  addon compartment entry. The slash command prints nothing to chat. Everything shared is ForeverCore's: never copy
  one of its files here.
- `Core/Model.lua` is pure: rows, profit, sort and the shopping list from plain tables, no client calls. Unknown is
  `nil`, never 0. `Core/Holdings.lua` reads one source per character per pass, `Core/Recipes.lua` records recipes,
  `Core/Store.lua` owns the saved variable and its schema, and `Core/API.lua` is the published API (`docs/api.md`).
- `Integrations/Prices.lua` reads Auctionator and TradeSkillMaster, `Merchant.lua` records merchant prices, and
  `Syndicator.lua` is the only file that names Syndicator; `tools/repo_rules.py` enforces it.
- `UI/Window.lua` registers the Professions tab through ForeverCore's `ProfessionTabs`; the client refuses an addon
  opening the window, so the slash command shows one error line and selects the tab when the window opens. `UI/RowArt.lua`
  is the one place row art is sized (`tools/lint_art.py`).
- `Data/Credits.lua` is generated from `THIRD_PARTY.md` by `python3 tools/forever_tools/credits.py`; never hand-edit.
- `Locales/enUS.lua` makes `ns.L` keyed by the English phrase, text is a whole `L["..."]` phrase;
  `python3 -m tools.phrases --write` after a change (`tests/locale_spec.lua` checks both).
- `tools/forever_tools/` and `tools/forever_sim/` are vendored from forever-core: never edit them here.

## Rules

- Lua 5.1 in the game's sandbox: no `require`; a new file goes in `TradewindForever.toc` or never runs.
- Nothing is written to chat (`tools/repo_rules.py`), no minimap button, and no assignment into a Blizzard frame:
  hook it with `HookScript` or `hooksecurefunc` (WFA-38).
- Missing data renders `?`, never a guess; an unknown price or holding is excluded from totals, not counted as zero.
- Never stretch art: draw at native aspect, item icons through ForeverCore's `Art.Icon`; `tools/lint_art.py` checks it.
- Nothing is sent to other players, and no protected action runs: the addon reads and lists only.
- Host globals go in `.luacheckrc`, missing Forever or integration APIs get real types in `types/`, never
  `diagnostics.globals`. A scalar `select(...)` in last position is parenthesized or carries `-- multi-value: reason`.
- ForeverCore ships first: bump the pin in `tools/forever-core.txt` and the TOC's `X-Forever-Core` together, only to a
  release `wowaddon --flavor forever info cf:1796337` shows as `latest`.

## Waivers

WFA-28 exceptions, because no addon or public API holds them; what the client shows at a window wins over the
bundled value:

- Recipe reagents, outputs and sell prices (`Data/Recipes.lua`, `tools/data/Thresholds.lua`) come from
  the client's own DB2 tables through wago.tools at the pinned build, 1.60.1.70959; a generated file is never
  hand-edited.

## Standards

- `wow-forever-addon`: https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-forever-addon (the WFA-*
  requirements every WoW: Forever addon meets: UI look, assets, README and store page, CI and release)
- `repo-standards`: the RS-* requirements every cjber and agent-labs-dev repo meets; its `audit.py` checks this repo.
