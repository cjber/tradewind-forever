#!/usr/bin/env python3
"""Regenerate committed data twice and require fresh, byte-stable results."""

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from forever_tools import generated
from forever_tools.luadata import LuaDataError, Table, parse_tables
from forever_tools.report import Subset

ROOT = Path(__file__).resolve().parent.parent
OUTPUTS = ["tools/data/Thresholds.lua", "Data/Recipes.lua"]
GENERATORS = ["gen_thresholds.py", "gen_recipes.py"]
SEED_FILES = ["tools/gen_thresholds.py", "tools/gen_recipes.py", "tools/data/Thresholds.lua", "Data/Recipes.lua"]
SUBSETS = [Subset("ns.RecipeData", "ns.Thresholds", "recipe data covers threshold recipes only")]


def validate_data(root: Path) -> None:
    try:
        recipe_tables, _ = parse_tables((root / "Data/Recipes.lua").read_text(encoding="utf-8"))
        threshold_tables, _ = parse_tables((root / "tools/data/Thresholds.lua").read_text(encoding="utf-8"))
    except (OSError, LuaDataError) as error:
        raise SystemExit(f"Generated data is not valid Lua data: {error}") from error

    recipes = recipe_tables.get("ns.RecipeData")
    prices = recipe_tables.get("ns.ItemSellPrices")
    thresholds = threshold_tables.get("ns.Thresholds")
    if not all(isinstance(table, Table) for table in (recipes, prices, thresholds)):
        raise SystemExit("Generated data is missing RecipeData, ItemSellPrices or Thresholds")
    if not set(recipes.keyed) <= set(thresholds.keyed):
        missing = sorted(set(recipes.keyed) - set(thresholds.keyed))
        raise SystemExit(f"RecipeData has IDs absent from Thresholds: {missing[:8]}")

    referenced_items = set()
    for spell, record in recipes.keyed.items():
        if not isinstance(spell, int) or spell <= 0:
            raise SystemExit("RecipeData contains an invalid spell ID")
        if not isinstance(record, Table):
            raise SystemExit(f"Recipe {spell} is not a record")
        if set(record.keyed) != {"skillLine", "reagents", "output"}:
            raise SystemExit(f"Recipe {spell} has the wrong fields: {sorted(record.keyed)}")
        skill_line = record.keyed["skillLine"]
        if not isinstance(skill_line, int) or skill_line <= 0:
            raise SystemExit(f"Recipe {spell} has an invalid skill line")
        reagents = record.keyed["reagents"]
        if not isinstance(reagents, Table):
            raise SystemExit(f"Recipe {spell} reagents are not an array")
        for reagent in reagents.array:
            if not isinstance(reagent, Table) or set(reagent.keyed) != {"itemID", "qty"}:
                raise SystemExit(f"Recipe {spell} has a malformed reagent")
            item = reagent.keyed["itemID"]
            quantity = reagent.keyed["qty"]
            if not isinstance(item, int) or item <= 0 or not isinstance(quantity, int) or quantity <= 0:
                raise SystemExit(f"Recipe {spell} has an invalid reagent")
            referenced_items.add(item)
        output = record.keyed["output"]
        if output is False:
            continue
        if not isinstance(output, Table) or set(output.keyed) != {"itemID", "qty"}:
            raise SystemExit(f"Recipe {spell} has a malformed output")
        item, quantity = output.keyed["itemID"], output.keyed["qty"]
        if not isinstance(item, int) or item <= 0 or not isinstance(quantity, (int, float)) or quantity <= 0:
            raise SystemExit(f"Recipe {spell} has an invalid output")
        referenced_items.add(item)

    if not all(isinstance(item, int) and item > 0 for item in prices.keyed):
        raise SystemExit("ItemSellPrices contains an invalid item ID")
    if not all(isinstance(value, int) and value > 0 for value in prices.keyed.values()):
        raise SystemExit("ItemSellPrices contains an invalid copper value")
    if not set(prices.keyed) <= referenced_items:
        extra = sorted(set(prices.keyed) - referenced_items)
        raise SystemExit(f"ItemSellPrices has unreferenced IDs: {extra[:8]}")


def outputs(root: Path) -> dict[str, bytes]:
    values = {name: (root / name).read_bytes() for name in OUTPUTS}
    validate_data(root)
    return values


def regenerate(scratch: Path, offline: bool) -> None:
    for name in OUTPUTS:
        (scratch / name).unlink()
    for generator in GENERATORS:
        subprocess.run(
            [sys.executable, f"tools/{generator}", *(["--offline"] if offline else [])],
            cwd=scratch,
            check=True,
        )


def seed_generated(root: Path, scratch: Path) -> None:
    for name in SEED_FILES:
        destination = scratch / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / name, destination)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    shared = ROOT / "tools/.cache"
    shared.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="tradewind-generated-") as temporary:
        with generated.scratch_tree(ROOT, shared, "tools/.cache", "tradewind-generated-", Path(temporary)) as fresh:
            with generated.scratch_tree(
                ROOT, shared, "tools/.cache", "tradewind-generated-", Path(temporary)
            ) as second:
                seed_generated(ROOT, fresh)
                seed_generated(ROOT, second)
                expected = outputs(fresh)
                regenerate(fresh, args.offline)
                regenerate(second, True)
                actual = outputs(fresh)
                generated.compare(
                    expected,
                    actual,
                    "Stale generated files; run the canonical generators",
                    subsets=SUBSETS,
                )
                same_inputs = generated.same_tree(fresh / "tools/.cache", second / "tools/.cache")
                if not same_inputs:
                    regenerate(fresh, True)
                again = outputs(second if same_inputs else fresh)
                generated.compare(
                    actual,
                    again,
                    "Regeneration is not byte-for-byte reproducible",
                    subsets=SUBSETS,
                )
    print("Generated data is fresh and byte-stable.")


if __name__ == "__main__":
    main()
