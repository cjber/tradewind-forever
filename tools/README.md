# Tools

Run from the repository root with Python 3.

```sh
python3 tools/gate.py                  # the fast local gate; --changed runs only what the diff reaches
python3 tools/doctor.py                # the local toolchain against tools/toolchain.json
python3 tools/changelog.py 0.1.0       # one version's CHANGELOG entry
python3 tools/changelog.py --check     # every v* tag has a CHANGELOG entry and changes/*.md is well formed
python3 tools/forever_tools/credits.py # Data/Credits.lua from THIRD_PARTY.md
python3 -m tools.phrases --write       # Locales/phrases.txt, the template translators copy
python3 tools/deadcode.py --check      # code nothing reaches
python3 tools/repo_rules.py            # the rules no linter covers
```

`tools/forever_tools` and `tools/forever_sim` are vendored from forever-core and never edited here:
`python3 tools/forever_tools/sync.py update --source ../forever-core`, and the same for `forever_sim`.
`tools/forever-core.txt` pins the ForeverCore release the TOC names and the release workflow embeds.
`tools/typecheck.sh` runs lua-language-server over the addon; it needs about 5 GB, so CI runs it.
