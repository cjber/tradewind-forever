#!/usr/bin/env python3
"""Generate the bundled recipe facts for the pinned Forever client."""

import argparse
import math
import re
import sys
import urllib.error
from collections import Counter, defaultdict

try:
    from gen_thresholds import (
        BUILD,
        CREATE_ITEM,
        DUMMY,
        ENCHANT_ITEM,
        ROOT,
        SOURCE_DATE,
        TELEPORT_UNITS,
        TRANS_DOOR,
        db2,
        professions,
    )
except ModuleNotFoundError:
    from tools.gen_thresholds import (
        BUILD,
        CREATE_ITEM,
        DUMMY,
        ENCHANT_ITEM,
        ROOT,
        SOURCE_DATE,
        TELEPORT_UNITS,
        TRANS_DOOR,
        db2,
        professions,
    )

OUTPUT = ROOT / "Data" / "Recipes.lua"
THRESHOLDS = ROOT / "tools" / "data" / "Thresholds.lua"
THRESHOLD_ROW = re.compile(r"\s*\[(\d+)\] = \{ \d+, \d+, \d+, \d+ \},(?: --.*)?")
YIELD_MODIFIERS = (
    "EffectRealPointsPerLevel",
    "EffectPointsPerResource",
    "Coefficient",
    "ResourceCoefficient",
    "ScalingClass",
    "EffectTriggerSpell",
)


def threshold_ids():
    content = THRESHOLDS.read_text(encoding="utf-8")
    if f"wow_classic_beta {BUILD}," not in content:
        raise ValueError("Thresholds.lua build differs; run gen_thresholds.py first")
    ids = set()
    for line in content.splitlines():
        if not line.lstrip().startswith("["):
            continue
        match = THRESHOLD_ROW.fullmatch(line)
        if not match or int(match[1]) in ids:
            raise ValueError(f"Invalid/duplicate Thresholds.lua row: {line}")
        ids.add(int(match[1]))
    if not ids:
        raise ValueError("No recipe IDs in Thresholds.lua")
    return ids


def put_unique(table, key, value, label):
    if key in table and table[key] != value:
        raise ValueError(f"Conflicting {label} for {key}: {table[key]!r} / {value!r}")
    table[key] = value


def memberships(ids, ability_rows, skill_rows):
    """Return the canonical profession line for every threshold recipe."""
    skills, selected, _ = professions(skill_rows)
    result = defaultdict(set)
    for row in ability_rows:
        spell, sid = int(row["Spell"]), int(row["SkillLine"])
        if spell not in ids or sid not in selected:
            continue
        seen = set()
        while True:
            if sid in seen or sid not in skills:
                raise ValueError(f"Missing/cyclic SkillLine parent for recipe {spell}: {sid}")
            seen.add(sid)
            parent = int(skills[sid]["ParentSkillLineID"])
            if parent not in selected:
                break
            sid = parent
        result[spell].add(sid)
    missing = ids - result.keys()
    if missing:
        raise ValueError(f"Threshold recipes without a profession: {sorted(missing)}")
    return result


def reagents_by_spell(ids, rows):
    result = {}
    for row in rows:
        spell = int(row["SpellID"])
        if spell not in ids:
            continue
        reagents, unresolved = Counter(), False
        for slot in range(8):
            item = int(row[f"Reagent_{slot}"])
            quantity = int(row[f"ReagentCount_{slot}"])
            if item < 0:
                unresolved = True
            elif item == quantity == 0:
                continue
            elif item <= 0 or quantity <= 0:
                raise ValueError(f"Recipe {spell}: contradictory reagent {item} x {quantity}")
            else:
                reagents[item] += quantity
        value = None if unresolved else tuple(sorted(reagents.items()))
        put_unique(result, spell, value, "reagents")
    return result


def output_of(spell, rows):
    if not rows:
        raise ValueError(f"Recipe {spell}: no effects to resolve output")
    creates = [row for row in rows if int(row["Effect"]) == CREATE_ITEM]
    if not creates:
        effects = {int(row["Effect"]) for row in rows}
        if effects == {TRANS_DOOR} or (ENCHANT_ITEM in effects and effects <= {DUMMY, TELEPORT_UNITS, ENCHANT_ITEM}):
            if any(int(row["EffectItemType"]) or int(row["EffectTriggerSpell"]) for row in rows):
                raise ValueError(f"Recipe {spell}: indirect item/triggered output needs review")
            return False
        raise ValueError(f"Recipe {spell}: unresolved output effects {sorted(effects)}")
    if len(creates) != 1:
        raise ValueError(f"Recipe {spell}: multiple create-item effects")
    row = creates[0]
    item = int(row["EffectItemType"])
    base, variance = float(row["EffectBasePointsF"]), float(row["Variance"])
    if (
        item <= 0
        or not math.isfinite(base)
        or not math.isfinite(variance)
        or base < 0
        or variance < 0
        or (base == 0 and variance != 0)
        or any(float(row[key]) != 0 for key in YIELD_MODIFIERS)
    ):
        raise ValueError(f"Recipe {spell}: invalid or scaled output yield")
    if variance and base * (1 - variance / 2) < 1 - 1e-6:
        raise ValueError(f"Recipe {spell}: output variance crosses the minimum yield")
    return item, max(1, base)


def generate(ids, ability_rows, skill_rows, reagent_rows, effect_rows, item_rows):
    member = memberships(ids, ability_rows, skill_rows)
    lines = {spell: next(iter(sids)) for spell, sids in member.items() if len(sids) == 1}
    reagents = reagents_by_spell(ids, reagent_rows)
    effects = defaultdict(dict)
    for row in effect_rows:
        spell = int(row["SpellID"])
        if spell in ids and int(row["DifficultyID"]) == 0:
            put_unique(effects[spell], int(row["EffectIndex"]), row, f"effects of recipe {spell}")
    recipes = {}
    for spell in sorted(ids):
        if spell in lines and reagents.get(spell) is not None:
            recipes[spell] = (lines[spell], reagents[spell], output_of(spell, list(effects[spell].values())))
    if not recipes:
        raise ValueError("No resolved recipes; leaving existing output untouched")

    referenced_items = set()
    for _, recipe_reagents, output in recipes.values():
        referenced_items.update(item for item, _ in recipe_reagents)
        if output is not False:
            referenced_items.add(output[0])
    sell = {}
    for row in item_rows:
        item = int(row["ID"])
        if item not in referenced_items:
            continue
        copper = int(row["SellPrice"])
        if copper < 0:
            raise ValueError(f"Item {item}: negative sell price")
        if copper > 0:
            put_unique(sell, item, copper, "sell price")

    stats = {
        "thresholds": len(ids),
        "recipes": len(recipes),
        "omitted_reagents": len(ids) - len(recipes),
        "multi_profession": len(ids) - len(lines),
        "reagent_entries": sum(len(r) for _, r, _ in recipes.values()),
        "distinct_reagents": len({item for _, r, _ in recipes.values() for item, _ in r}),
        "item_outputs": sum(o is not False for _, _, o in recipes.values()),
        "non_item_outputs": sum(o is False for _, _, o in recipes.values()),
        "referenced_items": len(referenced_items),
        "sell_prices": len(sell),
        "missing_sell_prices": len(referenced_items - sell.keys()),
    }
    return recipes, sell, stats


def render(recipes, sell, stats):
    lines = [
        "-- Generated by tools/gen_recipes.py - do not edit.",
        "-- luacheck: ignore 631",
        f"-- Source: wago.tools DB2, wow_classic_beta {BUILD}, {SOURCE_DATE}.",
        f"-- DB2: https://wago.tools/db2/SpellReagents/csv?build={BUILD}",
        "-- Command: python3 tools/gen_recipes.py",
        "-- SkillLineAbility, SkillLine, SpellReagents, SpellEffect, ItemSparse: same source and build.",
        "-- Threshold recipe spell IDs only; skillLine is the parent profession ID.",
        "-- Output quantity is mean yield; false is verified non-item output. Missing recipes are unknown.",
        "-- ItemSellPrices covers positive vendor sell-back values for referenced reagents and outputs.",
        "-- " + "; ".join(f"{key}={value}" for key, value in stats.items()) + ".",
        "---@type string, TWNamespace",
        "local _, ns = ...",
        "-- stylua: ignore",
        "ns.RecipeData = {",
    ]
    for spell, (skill, reagents, output) in sorted(recipes.items()):
        reagent_text = ", ".join(f"{{ itemID = {item}, qty = {quantity} }}" for item, quantity in reagents)
        out = "false" if output is False else f"{{ itemID = {output[0]}, qty = {output[1]:g} }}"
        lines.append(f"\t[{spell}] = {{ skillLine = {skill}, reagents = {{ {reagent_text} }}, output = {out} }},")
    lines.extend(["}", "", "-- stylua: ignore", "ns.ItemSellPrices = {"])
    for item, copper in sorted(sell.items()):
        lines.append(f"\t[{item}] = {copper},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--refresh", action="store_true", help="redownload the pinned sources")
    mode.add_argument("--offline", action="store_true", help="use cached sources only")
    args = parser.parse_args()
    options = {"refresh": args.refresh, "offline": args.offline}
    ids = threshold_ids()
    recipes, sell, stats = generate(
        ids,
        db2("SkillLineAbility", ("Spell", "SkillLine"), **options),
        db2("SkillLine", ("ID", "DisplayName_lang", "CategoryID", "CanLink", "ParentSkillLineID"), **options),
        db2(
            "SpellReagents",
            ("SpellID", *(f"Reagent_{i}" for i in range(8)), *(f"ReagentCount_{i}" for i in range(8))),
            **options,
        ),
        db2(
            "SpellEffect",
            (
                "SpellID",
                "DifficultyID",
                "EffectIndex",
                "Effect",
                "EffectItemType",
                "EffectBasePointsF",
                "Variance",
                *YIELD_MODIFIERS,
            ),
            **options,
        ),
        db2("ItemSparse", ("ID", "SellPrice"), **options),
    )
    content = render(recipes, sell, stats)
    OUTPUT.write_text(content, encoding="utf-8")
    for key, value in stats.items():
        print(f"{key}: {value}")
    print(f"Unresolved reagent recipes omitted: {sorted(ids - recipes.keys())}")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}: {len(content.encode('utf-8')):,} bytes")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, urllib.error.URLError) as error:
        sys.exit(f"error: {error}")
