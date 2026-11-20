"""The repository rules over the cases each one was written for."""

import unittest

from tools.repo_rules import (
    blizzard_writes,
    chat_output,
    minimap_buttons,
    syndicator_reads,
    unmatched_hashfiles,
    unused_luacheck_globals,
)

WORKFLOW = "      - with:\n          key: k-${{ hashFiles('tools/*.py', %s) }}\n"


class SyndicatorTest(unittest.TestCase):
    def test_only_the_integration_names_syndicator(self):
        read = "local api = Syndicator.API\n"
        self.assertEqual(syndicator_reads({"Integrations/Syndicator.lua": read, "tests/x_spec.lua": read}), [])
        self.assertEqual(len(syndicator_reads({"Core/Holdings.lua": read})), 1)
        self.assertEqual(syndicator_reads({"Core/Holdings.lua": "-- Syndicator is read elsewhere\n"}), [])
        self.assertEqual(syndicator_reads({"Core/Holdings.lua": "local SyndicatorReady = true\n"}), [])


class MinimapTest(unittest.TestCase):
    def test_no_minimap_button(self):
        self.assertEqual(len(minimap_buttons({"Core/Core.lua": 'local icon = LibStub("LibDBIcon-1.0")\n'})), 1)
        self.assertEqual(len(minimap_buttons({"UI/Button.lua": "local MinimapButton = nil\n"})), 1)
        self.assertEqual(minimap_buttons({"Core/Core.lua": "-- no LibDBIcon here\n"}), [])


class ChatTest(unittest.TestCase):
    def test_nothing_is_written_to_chat(self):
        self.assertEqual(len(chat_output({"Core/Core.lua": 'print("hello")\n'})), 1)
        self.assertEqual(len(chat_output({"Core/Core.lua": 'SendChatMessage("x", "SAY")\n'})), 1)
        self.assertEqual(len(chat_output({"Core/Core.lua": 'DEFAULT_CHAT_FRAME:AddMessage("x")\n'})), 1)
        self.assertEqual(len(chat_output({"Core/Core.lua": 'ChatFrame1:AddMessage("x")\n'})), 1)
        self.assertEqual(chat_output({"Core/Core.lua": 'UIErrorsFrame:AddMessage("x")\n'}), [])
        self.assertEqual(chat_output({"Core/Core.lua": 'ns.Print("x")\nns.Alert("x")\n'}), [])
        self.assertEqual(chat_output({"tests/x_spec.lua": 'print("ok")\n'}), [])


class BlizzardTest(unittest.TestCase):
    def test_blizzard_frames_are_hooked_not_written(self):
        self.assertEqual(len(blizzard_writes({"UI/Tab.lua": "ProfessionsFrame.CraftingPage.x = 1\n"})), 1)
        self.assertEqual(len(blizzard_writes({"UI/Tab.lua": "GameTooltip.owner = nil\n"})), 1)
        self.assertEqual(blizzard_writes({"UI/Tab.lua": "if GameTooltip.owner == nil then end\n"}), [])
        self.assertEqual(blizzard_writes({"UI/Tab.lua": 'ProfessionsFrame:HookScript("OnShow", fn)\n'}), [])
        self.assertEqual(blizzard_writes({"UI/Tab.lua": "ns.GameTooltip.owner = nil\n"}), [])


class LuacheckGlobalTest(unittest.TestCase):
    def test_an_entry_nothing_names_fails(self):
        config = '\nread_globals = {\n\t"CreateFrame",\n\t"GetLocale",\n\t"tInvert",\n}\n'
        files = {".luacheckrc": config, "a.lua": 'CreateFrame("Frame")', "Locales/phrases.txt": "GetLocale()"}
        hits = unused_luacheck_globals(files)
        self.assertEqual([hit.split(": ")[0] for hit in hits], [".luacheckrc:5"])


class HashFilesTest(unittest.TestCase):
    def test_a_pattern_matching_nothing_fails(self):
        files = {"tools/a.py": "", "tools/uv.lock": ""}
        self.assertEqual(unmatched_hashfiles({**files, ".github/workflows/ci.yml": WORKFLOW % "'**/*.lock'"}), [])
        dead = unmatched_hashfiles({**files, ".github/workflows/ci.yml": WORKFLOW % "'tools/db2.py'"})
        self.assertEqual([hit.split(": ")[0] for hit in dead], [".github/workflows/ci.yml:2"])


if __name__ == "__main__":
    unittest.main()
