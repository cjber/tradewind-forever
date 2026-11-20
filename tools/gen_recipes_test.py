"""Recipe data and sell-price generation tests."""

import unittest

from gen_recipes import CREATE_ITEM, TRANS_DOOR, generate, output_of, reagents_by_spell, render


def skill(skill_id, parent=0, category=11):
    return {
        "ID": str(skill_id),
        "DisplayName_lang": f"Skill {skill_id}",
        "CategoryID": str(category),
        "CanLink": "1",
        "ParentSkillLineID": str(parent),
    }


def ability(spell, skill_id):
    return {"Spell": str(spell), "SkillLine": str(skill_id)}


def reagent(spell, items):
    row = {"SpellID": str(spell)}
    for slot in range(8):
        item, quantity = items[slot] if slot < len(items) else (0, 0)
        row[f"Reagent_{slot}"] = str(item)
        row[f"ReagentCount_{slot}"] = str(quantity)
    return row


def effect(spell, kind, item=0, base=1):
    row = {
        "SpellID": str(spell),
        "DifficultyID": "0",
        "EffectIndex": "0",
        "Effect": str(kind),
        "EffectItemType": str(item),
        "EffectBasePointsF": str(base),
        "Variance": "0",
    }
    row.update(
        {
            "EffectRealPointsPerLevel": "0",
            "EffectPointsPerResource": "0",
            "Coefficient": "0",
            "ResourceCoefficient": "0",
            "ScalingClass": "0",
            "EffectTriggerSpell": "0",
        }
    )
    return row


class RecipeDataTests(unittest.TestCase):
    def test_reagents_are_combined_and_unresolved_rows_are_omitted(self):
        rows = [
            reagent(1001, [(2001, 2), (2001, 3)]),
            reagent(1002, [(-1, 1)]),
        ]
        self.assertEqual(reagents_by_spell({1001, 1002}, rows), {1001: ((2001, 5),), 1002: None})

    def test_output_false_is_retained_and_scaled_yield_is_rejected(self):
        self.assertFalse(output_of(1001, [effect(1001, TRANS_DOOR)]))
        scaled = effect(1001, CREATE_ITEM, item=3001)
        scaled["Coefficient"] = "1"
        with self.assertRaisesRegex(ValueError, "scaled output"):
            output_of(1001, [scaled])

    def test_recipe_shape_and_reagent_sell_prices(self):
        ids = {1001, 1002, 1003}
        recipes, sell, stats = generate(
            ids,
            [ability(1001, 164), ability(1002, 164), ability(1003, 164), ability(1003, 171)],
            [skill(164), skill(171)],
            [reagent(1001, [(2001, 2), (2002, 1)]), reagent(1002, [(2001, 1)]), reagent(1003, [])],
            [
                effect(1001, CREATE_ITEM, item=3001, base=2),
                effect(1002, TRANS_DOOR),
                effect(1003, CREATE_ITEM, item=3003),
            ],
            [{"ID": "2001", "SellPrice": "4"}, {"ID": "2002", "SellPrice": "0"}, {"ID": "3001", "SellPrice": "9"}],
        )

        self.assertEqual(
            recipes,
            {
                1001: (164, ((2001, 2), (2002, 1)), (3001, 2.0)),
                1002: (164, ((2001, 1),), False),
            },
        )
        self.assertEqual(sell, {2001: 4, 3001: 9})
        self.assertEqual(stats["missing_sell_prices"], 1)

        content = render(recipes, sell, stats)
        self.assertIn("{ itemID = 2001, qty = 2 }", content)
        self.assertIn("output = { itemID = 3001, qty = 2 }", content)
        self.assertIn("output = false", content)
        self.assertIn("[2001] = 4,", content)
        self.assertNotIn("[2002] = 0,", content)


if __name__ == "__main__":
    unittest.main()
