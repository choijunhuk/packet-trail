extends RefCounted

const ENTRIES := {
	"legacy_intruder": {"id": "legacy_intruder", "title_key": "PACK_LEGACY_TITLE", "summary_key": "PACK_INTRUDER_SUMMARY", "role": "legacy", "start_mission": "M01", "main_count": 24, "optional_count": 4, "resource": "res://data/campaign/legacy_v1.json", "slot": "user://saves/legacy_continue_01.json", "campaign_id": "midnight", "content_version": 1},
	"intruder": {"id": "intruder", "title_key": "PACK_INTRUDER_TITLE", "summary_key": "PACK_INTRUDER_SUMMARY", "role": "intruder", "start_mission": "M01", "main_count": 24, "optional_count": 4, "resource": "res://data/campaign/packs/intruder_v2.json", "slot": "user://saves/intruder_v2_01.json", "campaign_id": "midnight", "content_version": 2},
	"defender": {"id": "defender", "title_key": "PACK_DEFENDER_TITLE", "summary_key": "PACK_DEFENDER_SUMMARY", "role": "defender", "start_mission": "D01", "main_count": 8, "optional_count": 0, "resource": "res://data/campaign/packs/defender_v1.json", "slot": "user://saves/defender_01.json", "campaign_id": "midnight_defender", "content_version": 1},
	"tracker": {"id": "tracker", "title_key": "PACK_TRACKER_TITLE", "summary_key": "PACK_TRACKER_SUMMARY", "role": "tracker", "start_mission": "T01", "main_count": 8, "optional_count": 0, "resource": "res://data/campaign/packs/tracker_v1.json", "slot": "user://saves/tracker_01.json", "campaign_id": "midnight_tracker", "content_version": 1},
	"challenge": {"id": "challenge", "title_key": "CH1_PACK_TITLE", "summary_key": "CH1_PACK_SUMMARY", "role": "challenge", "start_mission": "X01", "main_count": 3, "optional_count": 0, "resource": "res://data/campaign/packs/challenge_v1.json", "slot": "user://saves/challenge_01.json", "campaign_id": "midnight_challenge", "content_version": 1},
	"investigation": {"id": "investigation", "title_key": "IV1_PACK_TITLE", "summary_key": "IV1_PACK_SUMMARY", "role": "investigation", "mode": "commissions", "start_mission": "I01", "main_count": 0, "optional_count": 2, "resource": "res://data/campaign/packs/investigation_v1.json", "slot": "user://saves/investigation_01.json", "campaign_id": "midnight_investigation", "content_version": 1},
}
const PUBLIC_IDS := ["intruder", "defender", "tracker", "challenge"]
const COMMISSION_IDS := ["investigation"]
const LEGACY_SOURCE := "user://saves/campaign_01.json"


static func list_packs(include_legacy: bool = false) -> Array:
	var ids: Array = PUBLIC_IDS.duplicate()
	if include_legacy:
		ids.append("legacy_intruder")
	return _list(ids)


static func list_commissions() -> Array:
	return _list(COMMISSION_IDS)


static func list_all_packs(include_legacy: bool = false) -> Array:
	return list_packs(include_legacy) + list_commissions()


static func _list(ids: Array) -> Array:
	var result: Array = []
	for id in ids:
		var entry: Dictionary = ENTRIES[id]
		result.append({"id": id, "title": str(TranslationServer.translate(entry.title_key)), "summary": str(TranslationServer.translate(entry.summary_key)), "role": entry.role, "start_mission": entry.start_mission, "main_count": entry.main_count, "optional_count": entry.optional_count})
	for item in result:
		if COMMISSION_IDS.has(item.id): item["mode"] = "commissions"
	return result


static func get_pack(pack_id: String) -> Dictionary:
	return ENTRIES.get(pack_id, {}).duplicate(true)


static func default_slot(pack_id: String) -> String:
	return str(ENTRIES.get(pack_id, {}).get("slot", ""))


static func test_slot(base_json: String, pack_id: String) -> String:
	if not ENTRIES.has(pack_id) or not base_json.begins_with("user://tests/") or not base_json.ends_with(".json") or base_json.contains("\\") or base_json.trim_prefix("user://").contains(":"):
		return ""
	for part in base_json.trim_prefix("user://").split("/"):
		if part.is_empty() or part in [".", ".."]:
			return ""
	for index in range(base_json.length()):
		if base_json.unicode_at(index) < 32 or base_json.unicode_at(index) == 127:
			return ""
	return base_json.trim_suffix(".json") + "_" + pack_id + ".json"
