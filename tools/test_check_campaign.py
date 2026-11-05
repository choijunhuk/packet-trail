"""Message references and observed wire payloads have different meanings."""

import importlib.util
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location("check_campaign", Path(__file__).with_name("check_campaign.py"))
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class CampaignKeysTests(unittest.TestCase):
    def test_wire_bodies_do_not_become_translation_keys(self):
        data = {"missions": {"M19": {
            "pages": {"https://capture.packet.test": {"title": "PAGE_TITLE", "body": "PAGE_BODY"}},
            "challenges": {"packets": {"explain": "PACKET_EXPLAIN", "rows": [
                {"body": "encrypted"}, {"body": "marker:N47"}, {"body": "unrelated"}]}}
        }}}
        keys, errors = set(), []
        CHECK.presentation_keys(data, keys, errors)
        self.assertEqual(keys, {"PAGE_TITLE", "PAGE_BODY", "PACKET_EXPLAIN"})
        self.assertEqual(errors, [])

    def test_goal_names_are_checked_and_evidence_payload_is_preserved(self):
        data = {"goals": [{"label_display": "EVIDENCE_TITLE", "target_display": "guest@capture.packet.test"}],
                "pages": {"https://capture.packet.test/log": {
                    "title": "LOG_TITLE", "body": "observed packet bytes", "record_id": "capture"}}}
        keys, errors = set(), []
        CHECK.presentation_keys(data, keys, errors)
        self.assertEqual(keys, {"EVIDENCE_TITLE", "LOG_TITLE"})
        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
