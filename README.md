<p align="center"><img src="https://raw.githubusercontent.com/cjber/tradewind-forever/main/media/icon-400.png" width="96" alt=""></p>

<h1 align="center">Tradewind Forever</h1>

<p align="center">
See which recipes pay for each of your characters, from what they hold, in the Professions window.<br>
<a href="https://github.com/cjber/tradewind-forever/actions/workflows/ci.yml"><img src="https://github.com/cjber/tradewind-forever/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<a href="https://github.com/cjber/tradewind-forever/releases/latest"><img src="https://img.shields.io/github/v/release/cjber/tradewind-forever" alt="Latest release"></a>
<br><br><a href="https://github.com/sponsors/cjber"><img src="docs/github-sponsors-button.png" alt="Sponsor me on GitHub"></a> <a href="https://ko-fi.com/cjber"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi"></a>
</p>

Tradewind Forever adds a Tradewind tab to the Professions window with three lists. Craft now ranks the recipes each of your characters can make from its own bags and bank by profit per craft. Shopping lists the reagents to buy to make the best rows again, priced where you buy them. Characters shows what is recorded for each one. It lists and explains: it never crafts, buys or posts.

Prices come from Auctionator or TradeSkillMaster when you have one installed, a vendor buyer's price from the merchant windows you have opened, and what your other characters hold from Syndicator. Nothing is sent to other players.

## Known limitations

- A price is never guessed. Without Auctionator or TradeSkillMaster, an auction price is unknown and shown as `?`, not zero; unknown amounts are left out of every total.
- A character you have not logged in to with Tradewind installed shows as not scanned, and a bank you have not opened since installing counts as unknown holdings.
- Holdings come from the client's own counts, or Syndicator when it knows the character. Without Syndicator, a character's bank is counted from the client's cached bank contents, which has not been confirmed on the Forever client; equipped items count as held only without Syndicator.
- A merchant's price is only known after you have opened that merchant's window once.
- Recipes and sell prices are bundled from the game's data at one client build; what the client shows at a window wins.
- Auction house cut and sales per day follow SkillUp Forever's figures and have not been re-checked on the Forever client.
- TradeSkillMaster's recent-sale and minimum-buyout figures are read the way SkillUp Forever reads them.
- The client refuses an addon opening the Professions window, so `/tradewind` asks you to open it and then shows the tab.

## Install

Download the zip from [Releases](https://github.com/cjber/tradewind-forever/releases) and extract it into the WoW: Forever client's `Interface/AddOns/` folder (`_forever_` on the live client), so you end up with `AddOns/TradewindForever/TradewindForever.toc`.

## Usage

- `/tradewind` or `/tw` opens the Tradewind tab in the Professions window, also from the addon compartment. `/tradewind report` shows the report for a bug report.
- `/rl` reloads the interface.

## Works alongside

Auctionator, TradeSkillMaster and Syndicator are optional and only read, through their public APIs. Nothing is read from their saved variables.

<!-- forever-family:start -->

## The Forever addons

Each one works on its own, and they work together when you install more than one.

| Addon | What it does | Issues |
|---|---|---|
| [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) | Plans journeys on foot, by air, by sea and through portals, with directions in the tracker. | [Issues](https://github.com/cjber/shortest-path-forever/issues) |
| [Adventure Guide Forever](https://www.curseforge.com/wow/addons/adventure-guide-forever) | Suggests quests for your level and routes you from one to the next. | [Issues](https://github.com/cjber/adventure-guide-forever/issues) |
| [SkillUp Forever](https://www.curseforge.com/wow/addons/skillup-forever) | Shows skill-up chances, recipe costs and levelling routes in the Professions window. | [Issues](https://github.com/cjber/skillup-forever/issues) |
| [Legacy Forever](https://www.curseforge.com/wow/addons/legacy-forever) | Shows your unfinished Legacy challenges on the world map and tracks the ones you choose. | [Issues](https://github.com/cjber/legacy-forever/issues) |
| [Tweaks Forever](https://www.curseforge.com/wow/addons/tweaks-forever) | Adds quest automation, rare alerts and merchant options to the game's settings. | [Issues](https://github.com/cjber/tweaks-forever/issues) |
| [Field Guide Forever](https://www.curseforge.com/wow/addons/field-guide-forever) | Keeps a cosmetic journal of the creatures you kill, zone by zone. | [Issues](https://github.com/cjber/field-guide-forever/issues) |
| [Commissions Forever](https://www.curseforge.com/wow/addons/commissions-forever) | Lists your commission turn-ins, the materials in your bags and the next NPC to visit. | [Issues](https://github.com/cjber/commissions-forever/issues) |
| [Macro Assist Forever](https://www.curseforge.com/wow/addons/macro-assist-forever) | Adds a macro window with every macro in one list, a mono editor with live checks, and history. | [Issues](https://github.com/cjber/macro-assist-forever/issues) |

Bug reports, feature requests and pull requests are welcome on each addon's GitHub. Everyone whose report or idea ships is thanked by name on the Thanks page in game, in the store page and in the changelog, unless they ask not to be.

For help, ideas and each day's release notes, join [cjber's Workshop on Discord](https://discord.gg/FpHugGxRJY).

<!-- forever-family:end -->


## Development

```sh
tools/typecheck.sh                              # LuaLS 3.19.1 + multi-value lint
luacheck . && stylua --check .                  # lint and format
for spec in tests/*_spec.lua; do luajit "$spec" || exit 1; done
python3 tools/check_screenshots.py --record     # after retaking the in-game captures in docs/screenshots
```

[tools/README.md](tools/README.md) covers the `Data/` generators and [AGENTS.md](AGENTS.md) the rest, including releasing and contributing. Report security problems privately, as [SECURITY.md](https://github.com/cjber/.github/blob/main/SECURITY.md) describes.

## Support

The addon is free and stays GPL-3.0. If it saves you time, you can [sponsor me on GitHub](https://github.com/sponsors/cjber), which takes no fees, or [buy me a coffee on Ko-fi](https://ko-fi.com/cjber); nothing is locked behind it and there is no paid version.

## Credits

Game data comes from [wago.tools](https://wago.tools), [CMaNGOS classic-db](https://github.com/cmangos/classic-db) (GPL-3.0) and [Warcraft Wiki](https://warcraft.wiki.gg/wiki/Zones_by_level_(original)). Quest sparkles use the same settings as [Forever Loot Sparkles](https://github.com/svengabr/ForeverLootSparkles) by Ashtar Senior. Some features were inspired by [Polestar](https://github.com/fitzforge/polestar) by Fitz, such as rare alerts, and the rare waypoint by [RareScanner](https://www.curseforge.com/wow/addons/rarescanner); no code was copied. Fitz is welcome to use our code.

<!-- forever-credits:start -->

Thanks to everyone who reports a bug or asks for a feature.

<!-- forever-credits:end -->

## Licence

GPL-3.0-or-later. Every input and its licence: [THIRD_PARTY.md](THIRD_PARTY.md).

Made by Cillian Berragan · [cillian.dev](https://cillian.dev) · [GitHub](https://github.com/cjber) · [Twitter](https://twitter.com/cjberragan)

Built with AI assistance.
