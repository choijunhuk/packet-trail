#!/usr/bin/env python3
"""Build independent public packs; never rewrite the preserved legacy inputs."""

import ast
import copy
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "godot/data/campaign"
PACKS = DATA / "packs"
TEXT = {pack: {"ko": {}, "en": {}} for pack in ["intruder", "defender", "tracker"]}
PREFIX = {"intruder": "IN2_", "defender": "DF1_", "tracker": "TR1_"}
FILES = {"intruder": "intruder_v2", "defender": "defender_v1", "tracker": "tracker_v1"}
PRESERVED = [DATA / "campaign.json", DATA / "legacy_v1.json", DATA / "locales/ko.json", DATA / "locales/en.json",
             ROOT / "godot/tests/fixtures/campaign_solutions.json", ROOT / "tools/build_campaign_content.py"]


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def text(pack, suffix, ko, en):
    key = PREFIX[pack] + suffix
    assert key not in TEXT[pack]["ko"], key
    TEXT[pack]["ko"][key], TEXT[pack]["en"][key] = ko, en
    return key


def authored_constants():
    module = ast.parse((ROOT / "tools/build_campaign_content.py").read_text(encoding="utf-8"))
    names = {"STORIES", "AUTHORED", "ACCESS"}
    return {node.targets[0].id: ast.literal_eval(node.value) for node in module.body
            if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name) and node.targets[0].id in names}


def cmd(line, **extra):
    return {"kind": "command", "line": line, **extra}


def login(domain, account, secret):
    return [cmd("ssh " + account + "@" + domain), {"kind": "password", "value": secret}]


def action(challenge_id, operation, **params):
    return {"kind": "tool", "tool_id": challenge_id, "params": {"action": operation, **params}}


def typed(challenge_id, value, **extra):
    return {"kind": "tool", "tool_id": challenge_id, "params": {"input": value}, **extra}


def source_entry(content="", *, kind="file", owner="operator", group="staff", mode="640", record_id="", display_key=None):
    result = {"kind": kind, "owner": owner, "group": group, "mode": mode, "content": content, "record_id": record_id}
    if display_key:
        result["display_content_key"] = display_key
    return result


def namespace_mission(raw, prefix, locales):
    """Public domains/account handles stay readable; their host identity is scoped."""
    mission = copy.deepcopy(raw)
    identities = {}
    for field in ["hosts", "records", "policies", "challenges"]:
        identities.update({key: prefix.lower() + key for key in mission.get(field, {})})
    for host in mission['hosts'].values():
        for file in host['files'].values():
            if file.get('record_id'):identities.setdefault(file['record_id'],prefix.lower()+file['record_id'])
    facts = {g["id"] for g in mission["goals"] if g["kind"] == "fact"}
    for record in mission["records"].values():
        facts.update(record.get("grants_facts", []))
    for challenge in mission["challenges"].values():
        if challenge.get("fact_id"):
            facts.add(challenge["fact_id"])
    identities.update({fact: prefix.lower() + fact for fact in facts})
    keys = {key: prefix + key for key in locales["en"]}

    def visit(value, field=""):
        if isinstance(value, dict):
            result={}
            for key,item in value.items():
                scoped_key=identities.get(key,key) if field in {'hosts','records','policies','challenges','required_policies'} else key
                if key=='id' and value.get('kind') in {'fact','policy'}:
                    result[scoped_key]=identities.get(item,item)
                else:result[scoped_key]=visit(item,key)
            return result
        if isinstance(value, list):
            return [visit(item, field) for item in value]
        if not isinstance(value, str):
            return value
        if field in {"content", "password", "domain", "address"}:
            return value
        if value in keys:
            return keys[value]
        if field in {'host_id','via','record_id','policy_id','challenge_id','fact_id','grants_facts','requires_facts','target'} and value in identities:
            return identities[value]
        if field in {"source", "allowed_sources"}:
            head, separator, tail = value.partition(":")
            if head == "model" and tail in identities:
                return "model:" + identities[tail]
            if head in identities:
                return identities[head] + separator + tail
            if separator:return prefix.lower()+head+separator+tail
        return value

    return visit(mission), identities


def strip_repeated_exhibits(mission, access):
    mid = mission["mission_id"]
    if mid == "M01":
        return
    for rid in list(mission["records"]):
        if "_EXHIBIT_" in rid:
            del mission["records"][rid]
    mission["goals"] = [goal for goal in mission["goals"]
        if "_EXHIBIT_" not in str(goal.get("record_id", "")) and "_exhibit_" not in str(goal.get("id", ""))]
    for cid in list(mission["challenges"]):
        if "_exhibit_" in cid:
            del mission["challenges"][cid]
        else:
            challenge = mission["challenges"][cid]
            challenge["requires_facts"] = [fact for fact in challenge.get("requires_facts", []) if "_exhibit_" not in fact]
    for host in access[mid][4:6]:
        mission["hosts"].pop(host, None)
    mission["milestones"] = []
    for goal in mission["goals"]:
        goal.pop("label_display", None)
        goal.pop("target_display", None)


def copy_intruder_base():
    legacy = read(DATA / "legacy_v1.json")
    constants = authored_constants()
    old_text = {lang: read(DATA / "locales" / (lang + ".json")) for lang in ["ko", "en"]}
    prose = read(ROOT / "godot/locales/operational-prose.json")
    for key, value in old_text["ko"].items():
        for original, translations in prose.items():
            value = value.replace(original, translations[0])
        TEXT["intruder"]["ko"]["IN2_" + key] = value
    TEXT["intruder"]["en"].update({"IN2_" + key: value for key, value in old_text["en"].items()})
    result = {"schema_version": 1, "content_version": 2, "campaign_id": "midnight", "start_mission": "M01",
              "mission_order": list(legacy["mission_order"]), "missions": {}, "endings": []}
    maps = {}
    stories = {row[0]: row for row in constants["STORIES"]}
    for mid in legacy["mission_order"]:
        mission = copy.deepcopy(legacy["missions"][mid])
        strip_repeated_exhibits(mission, constants["ACCESS"])
        mission, identities = namespace_mission(mission, "IN2_", old_text)
        row = stories[mid]
        TEXT["intruder"]["ko"]["IN2_" + mid + "_BRIEF"] = row[5]
        TEXT["intruder"]["en"]["IN2_" + mid + "_BRIEF"] = row[6]
        if mid != "M01":
            TEXT["intruder"]["ko"]["IN2_" + mid + "_GOAL"] = constants["AUTHORED"][mid][0]
            TEXT["intruder"]["en"]["IN2_" + mid + "_GOAL"] = constants["AUTHORED"][mid][1]
        result["missions"][mid], maps[mid] = mission, identities
    return result, constants, maps


DEFENDER_STORIES = [
 ("D01", "문을 닫지 않고 막기", "Keep the Door Working", "도윤", "Doyun",
  "야간 서비스 담당 첫날입니다. 저는 현장 기술자 도윤이에요. 왼쪽에는 시민이 자기 접수증을 읽는 요청, 오른쪽에는 다른 사람의 접수증을 읽는 요청이 있습니다. 서버를 끄면 둘 다 사라집니다. 우리가 원하는 결과는 아니죠.\n\n업무 계정으로 접속한 뒤 정상 요청을 먼저 한 번 보세요. 소유자 검사를 고쳐도 되고, 원래의 노출된 길을 닫고 좁은 위임 경로로 옮겨도 됩니다. 무엇이 막혔는지보다 누가 계속 일할 수 있는지 확인해 주세요.",
  "It is your first night on service duty. I am Doyun, the field technician. One request reads a citizen's own receipt; another reads somebody else's. Turning off the server removes both. That is not our goal.\n\nConnect with the work account and observe a legitimate request first. Repair ownership checks, or close the exposed route and move legitimate work to a narrow delegation path. Check who can still work, not merely what disappeared.",
  "서린과 정비사는 자기 일을 계속하고, 무관한 열람은 막혔습니다. 첫 대응의 기준이 생겼군요. 다음 경보에서는 같은 주소에서 정상 시민과 반복 시도가 함께 들어옵니다.",
  "Serin and the technician can still work; unrelated access is blocked. We have a standard for the next response. The next alert mixes legitimate citizens and repeated attempts behind one address."),
 ("D02", "같은 주소의 두 사람", "Two People, One Address", "도윤", "Doyun",
  "병원 중계의 주소에서 로그인 실패가 쏟아집니다. 같은 주소의 정상 작업도 있어요. 그 주소를 통째로 막자는 제안은 쉽지만 누가 피해를 보는지부터 봐야 합니다.\n\n계정별 반복 시도를 제한하거나 정상 업무를 검증된 인증 경로로 분리해 주세요. 제한 후에도 야간 작업자의 정상 인증이 가능한지 확인합니다. 실제 시간을 기다릴 필요는 없습니다.",
  "Login failures are arriving from the hospital relay's address, alongside legitimate work. Blocking the entire address is easy; first see who would lose access.\n\nLimit repeated attempts per account, or move legitimate work through an approved authentication route. Verify valid staff authentication after the limit. No real-time waiting is required.",
  "주소 하나로 사람을 묶지 않아서 병원 작업을 살렸습니다. 이번 실패 기록의 임시 계정에는 아직 살아 있는 세션이 남아 있군요.",
  "Not treating one address as one person kept hospital work alive. The temporary account in these failures still has a live session."),
 ("D03", "끝나야 할 열쇠", "A Key That Must Expire", "서윤", "Seoyun",
  "서윤입니다. 임시 정비 계정의 작업은 끝났지만 그 세션으로 자료를 읽을 수 있습니다. 정상 장기 작업도 같은 서비스에 붙어 있어 전부 로그아웃시키면 문제가 생겨요.\n\n노출된 세션만 폐기하거나 끝난 권한을 좁혀 교체하세요. 새 정상 세션이 살아 있는지와 옛 세션이 다시 쓰이지 않는지를 따로 확인해야 합니다.",
  "I am Seoyun. The temporary maintenance job ended, yet its session still reads records. A legitimate long-running job uses the same service, so logging out everyone would cause harm.\n\nRevoke only the exposed session, or constrain and replace the expired authority. Verify fresh legitimate access and refusal of the old session separately.",
  "끝난 권한은 거부되고 정상 작업은 남았습니다. 옛 세션의 거부는 화면의 안심 문구가 아니라 서버 응답에서 확인됐습니다. 다음 자료는 사진이라는 이름으로 들어옵니다.",
  "Retired authority is refused while legitimate work remains. The old session's refusal was verified in the server response, not a reassuring screen label. The next input arrives under a photograph's name."),
 ("D04", "사진 작업대", "The Photo Workbench", "도윤", "Doyun",
  "정비 사진 한 장이 처리 작업으로 실행됐습니다. 확장자를 금지하는 것만으로는 내용과 저장 위치의 관계를 고칠 수 없어요. 그렇다고 사진 접수를 닫으면 현장이 멈춥니다.\n\n형식과 비실행 저장 경계를 고치거나, 파일을 격리 처리해 승인된 사진만 배포하세요. 잘못된 파일의 거부와 정상 JPEG의 생성·열람이 함께 필요합니다.",
  "A maintenance photo ran as a processing job. Banning an extension alone will not repair the relationship between content and storage. Closing photo intake would stop field work.\n\nRepair validation and non-executable storage, or quarantine processing and publish approved photos only. Both rejection of the disguised file and creation of a normal JPEG are required.",
  "정상 사진은 들어오고 잘못된 처리 효과는 막혔습니다. 파일을 읽는 작업자가 내부의 다른 서비스도 볼 수 있다는 사실이 다음 문제입니다.",
  "Normal photos arrive and the incorrect processing effect is blocked. The next issue is what other internal services the file worker can reach."),
 ("D05", "안쪽으로 향한 요청", "Requests Heading Inward", "태경", "Taegyeong",
  "시청 서비스 담당 태경입니다. 미리보기 작업이 내부 자료에 닿았습니다. 내부 연결을 전부 끊으면 건강 확인과 시민 화면도 실패합니다. 허용된 용도와 목적지를 구분해야 합니다.\n\n내부 서비스의 객체 권한을 좁히거나 검증된 프록시로 필요한 요청만 넘기세요. 숨은 공격자 표시가 아니라 실제 요청 주체와 대상이 정책을 결정해야 합니다.",
  "I am Taegyeong, the city service liaison. Preview work reached an internal record. Cutting every internal connection would break health checks and citizen pages. Separate the permitted purpose and destination.\n\nConstrain internal object authority, or pass only required requests through an approved proxy. Policies must use requester and target, not a hidden attacker label.",
  "건강 확인과 미리보기는 남고 내부 자료의 비인가 읽기는 막혔습니다. 좁은 경계를 만들었군요. 다만 급히 고친 파일 권한 때문에 배포 작업이 멈췄습니다.",
  "Health checks and previews work while unauthorized internal reads fail. The boundary is narrow. A rushed file-permission change has now stopped deployment."),
 ("D06", "고친 권한, 멈춘 작업", "Repaired Rights, Stopped Work", "도윤", "Doyun",
  "비담당 계정의 쓰기를 막으려다 배포 계정도 상위 폴더에 들어가지 못합니다. 파일 한 장의 권한만 보면 원인을 놓쳐요. 현재 그룹과 경로의 각 문을 확인해 주세요.\n\n필요한 그룹·ACL만 고치거나 승인된 작업 계정과 경로로 이관할 수 있습니다. 모두에게 전체 권한을 주는 것은 해결이 아닙니다.",
  "A change intended to stop unrelated writes also prevents deployment from traversing an ancestor folder. Looking only at the file misses the cause. Inspect current groups and every directory gate.\n\nRepair only the required group or ACL, or migrate to an approved job account and path. Granting everyone full authority is not a solution.",
  "배포와 정비는 동작하고 비담당 쓰기는 거부됩니다. 필요한 권한을 좁히는 기준을 지켰어요. 이제 실제 위협과 잘못된 긴급 규칙이 동시에 들어옵니다.",
  "Deployment and maintenance work while unrelated writes are refused. Necessary authority stayed narrow. Now a real threat and an incorrect emergency rule arrive together."),
 ("D07", "두 장애의 한밤", "Two Failures in One Night", "태경", "Taegyeong",
  "내부 비인가 요청을 막았지만 정상 알림도 끊겼습니다. 직전 상태 전체로 돌아가면 이미 폐기한 열쇠까지 되살릴 수 있어요. 이번에는 되돌리기의 범위가 대응의 핵심입니다.\n\n잘못된 정책 그룹만 부분적으로 되돌리거나, 정상 업무를 승인된 대기 서비스로 옮기세요. 노출 세션의 폐기와 수집한 자료는 rollback 대상이 아닙니다.",
  "Unauthorized internal requests stopped, but so did legitimate notifications. Restoring the entire previous world could revive a key already revoked. The rollback boundary is now the central decision.\n\nRoll back only the incorrect policy group, or move legitimate work to an approved standby service. Session revocation and collected evidence are not rollback targets.",
  "알림은 다시 전달되고 폐기 세션은 돌아오지 않았습니다. 임시 이관과 완전 복구를 같은 것으로 부르지 않고 인계하겠습니다.",
  "Notifications are delivered again without reviving the retired session. The handoff will distinguish a controlled temporary migration from complete restoration."),
 ("D08", "계속 돌아가는 도시", "The City That Keeps Working", "도윤", "Doyun",
  "마지막 야간 교대입니다. 웹 접수, 내부 알림, 정비 작업이 서로 얽혀 있습니다. 경보를 없애는 것과 도시를 지키는 것은 같은 일이 아니에요.\n\n기존 서비스를 정밀 복구하거나 승인된 대체 경로로 연속성을 유지하세요. 선택한 조합에서 정상 업무와 모델링한 위협을 모두 확인하고, 아직 제한된 부분을 사실대로 인계합니다.",
  "This is the final night handoff. Web receipts, internal notifications and maintenance work are connected. Removing alerts is not the same as protecting the city.\n\nPrecisely restore the existing services or maintain continuity through approved alternatives. Check legitimate work and the modeled threats under your chosen configuration, and report remaining restrictions honestly.",
  "도시는 계속 돌아갑니다. 막힌 공격 경로와 살아 있는 업무가 같은 기록에 남았습니다. 모든 위험이 사라졌다고 선언하는 대신, 다음 교대가 확인하고 되돌릴 수 있는 상태를 넘깁니다.",
  "The city keeps working. Blocked threat routes and functioning services share one record. Instead of declaring all risk gone, you hand the next shift a state it can verify and safely revise."),
]

TRACKER_STORIES = [
 ("T01", "한 주소의 여러 그림자", "Several Shadows at One Address",
  "독립 기록 조사 팀의 민서입니다. 오늘 처음 들어온 분도 시작할 수 있도록 관측 두 개와 수집 허가를 준비했습니다. 같은 IP가 보이지만 그것이 같은 사람이라는 뜻은 아닙니다.\n\n계정/세션 기록이나 중계 양끝 중 어디를 더 보면 두 설명을 구분할 수 있을까요? 현재 보이는 연결을 확인하고 다음 관찰 지점을 남겨 주세요. 범인의 이름을 맞히는 의뢰가 아닙니다.",
  "I am Minseo from the independent records team. You can begin here without prior cases; two observations and collection authorization are ready. The same IP does not establish the same person.\n\nWould session records or both sides of the relay better distinguish the explanations? Establish the visible connection and nominate the next observation point. This is not a job to guess a culprit's name.",
  "한 주소 뒤의 연결과 사람의 정체를 구분했습니다. 다음 사건은 기록 시계가 서로 다른데도 같은 시간이라고 불린 전송입니다.",
  "You separated a connection behind one address from a person's identity. The next transmission was called simultaneous even though its clocks disagree."),
 ("T02", "맞지 않는 두 시계", "Two Clocks That Disagree",
  "두 서버가 같은 시각을 남겼지만 기준 이벤트와 오차 범위가 다릅니다. 정확한 초를 만들어 내지 말고 가능한 순서부터 좁혀 보세요.\n\n공통 이벤트를 기준으로 보정하거나 서명 인계의 순서와 독립 기록을 함께 볼 수 있습니다. 어느 쪽도 내부의 정답 시계를 보여 주지는 않습니다.",
  "Two servers recorded the same time with different anchors and error intervals. Narrow the possible order instead of inventing exact seconds.\n\nUse a shared reference event, or combine signed handoff order with independent records. Neither route reveals a hidden perfect clock.",
  "분리된 시간 구간은 순서를 지지하고 겹치는 구간은 아직 모른다고 남겼습니다. 다음 사본은 누가 만들고 전달했는지부터 확인해야 합니다.",
  "Separated time intervals support an order; overlapping ones remain unresolved. For the next copy, first establish who collected and transferred it."),
 ("T03", "복사된 기록의 출처", "The Copy's Provenance",
  "사본 두 개가 다릅니다. 변조, 재배포, 수집 누락이 모두 가능한 설명이에요. 해시가 같으면 수집 뒤 바뀌지 않았다는 근거가 되지만 내용이 참이라는 보증은 아닙니다.\n\n독립 수신 기록이나 인계 출처를 연결해 자료가 어느 경로로 왔는지 확인하세요. 출처가 약한 문장의 내용으로 사람을 확정하지 않습니다.",
  "Two copies differ. Modification, republication and collection gaps are all possible. A matching hash supports integrity after collection, not the truth of the content.\n\nConnect independent receipt records or custody sources to establish the copy's route. Do not attribute a person from a weakly sourced statement.",
  "보관한 사본의 출처와 원자료가 주장한 내용을 나누어 기록했습니다. 이제 새 관측 하나를 어디서 얻을지 선택해 봅시다.",
  "You recorded the copy's provenance separately from what its source claimed. Now choose where one new observation would help most."),
 ("T04", "다음 접속을 기다리는 곳", "Where to Watch the Next Connection",
  "이미 가진 기록을 반복해서 읽어도 두 후보 경로는 갈라지지 않습니다. 허가된 관찰 지점을 고르고 가상 관측 구간을 다음으로 옮겨 주세요. 실제 시간을 기다리지는 않습니다.\n\n중계 경계를 볼 수도, 제한된 종단 계측을 볼 수도 있습니다. 새 관측이 어느 설명을 지지하거나 반박하는지 확인하세요.",
  "Rereading the current records will not distinguish the two routes. Choose an authorized sensor and advance its simulated observation window. No real-time waiting is involved.\n\nWatch the relay boundary or a limited endpoint. Determine which explanation the new observation supports or contradicts.",
  "다음 관찰의 위치를 선택한 결과가 연결을 좁혔습니다. 다음 기록에서는 계정 이름과 실제 세션 사용자를 같은 것으로 볼 수 없습니다.",
  "Your choice of observation point narrowed the connection. In the next record, an account name cannot be equated with the session's physical user."),
 ("T05", "도난당한 이름", "A Stolen Name",
  "같은 계정 이름이 두 경로에 나타납니다. 공유 계정, 남은 세션, 탈취 모두 가능한 설명입니다. 이름을 가진 사람을 먼저 지목하면 관측보다 결론이 앞섭니다.\n\n세션 생애와 경로 또는 위임·폐기 기록을 연결해 현재 입증되는 연결을 확인하세요. 누가 직접 키보드를 쳤는지는 알 수 없는 채로 남을 수도 있습니다.",
  "One account name appears on two routes. Sharing, retained sessions and theft remain possible explanations. Naming the person first puts conclusion ahead of evidence.\n\nConnect session lifetime and routes, or delegation and revocation records. Who physically used the keyboard may remain unknown.",
  "계정과 세션의 연결은 확인했고 사람의 정체는 과장하지 않았습니다. 다음 전송에는 내용을 볼 수 없는 구간이 있습니다.",
  "The account and session connection is established without overstating identity. The next transmission contains a segment whose content is not visible."),
 ("T06", "보이지 않는 구간", "The Unseen Segment",
  "암호화된 구간을 사이에 두고 기록이 끊겼습니다. 본문을 임의로 복호화하는 도구는 없습니다. 하지만 허가된 메타데이터와 종단 기록으로 제한된 연결을 확인할 수 있어요.\n\n어느 지점이 무엇을 볼 수 있었는지 남기고, 다른 사람의 내용을 수집하지 않는 방법으로 다음 목표를 좁혀 주세요.",
  "The record crosses an encrypted segment. There is no button that arbitrarily decrypts its body. Authorized metadata and endpoint records can still support a bounded connection.\n\nRecord who could see what and narrow the next target without collecting unrelated people's content.",
  "보이지 않는 내용을 만들어 내지 않고도 이동 연결을 확인했습니다. 그런데 새 자료 하나가 이전의 유력한 설명과 맞지 않습니다.",
  "You established the movement without inventing unseen content. A new record now conflicts with a previously plausible explanation."),
 ("T07", "맞는 가설을 버릴 때", "When a Plausible Hypothesis Must Go",
  "앞 조사자의 메모는 같은 세션이라고 추정했습니다. 그것을 당신의 믿음으로 받아들일 필요는 없습니다. 새 관측을 먼저 확인하고 곧바로 더 나은 연결을 만들 수도 있어요.\n\n기준 이벤트나 경쟁 설명이 예측한 다음 관측을 확보하세요. 이전 가설을 세웠다면 이력과 반증을 남겨 정정하고, 그렇지 않다면 지지되는 관계로 바로 인계할 수 있습니다.",
  "A prior investigator's note suggested one session. You need not adopt it as your belief. Inspect new observations first and go directly to a better-supported connection.\n\nCollect an anchor event or the next observation predicted by competing explanations. Revise a prior hypothesis with its history if you made one; otherwise hand off the supported relation directly.",
  "새 관측은 이전 메모의 한계를 드러냈습니다. 틀린 가설을 지우지 않고 정정할 수도, 처음부터 독립된 관측으로 진행할 수도 있었습니다. 마지막에는 무엇까지 입증했는지 정리합시다.",
  "The new observation exposed the prior note's limit. You could revise without erasing history, or proceed directly from independent evidence. For the final handoff, state exactly what was established."),
 ("T08", "마지막 연결의 범위", "The Limit of the Final Connection",
  "마지막 인계입니다. 서로 다른 관찰 지점과 출처로 연결된 최소 경로를 확인해 주세요. 모든 후보의 실명을 알아야 끝나는 사건은 아닙니다.\n\n어느 전송이 어느 경계를 지났고, 어떤 주장이 반박됐으며, 어디에는 아직 관측이 없는지를 구분합니다. 요구된 연결과 후속 관찰을 생략한 채 전부 모른다고 적는 것도 충분하지 않습니다.",
  "This is the final handoff. Establish the minimal route connected by independent viewpoints and sources. The case does not require every candidate's real name.\n\nSeparate which transmission crossed which boundary, which claim was contradicted, and where no observation exists. Writing 'unknown' everywhere without the required links and follow-up is not sufficient.",
  "관찰이 지지하는 연결은 남고 알 수 없는 정체는 꾸며지지 않았습니다. 다음 팀은 출처와 반증, 아직 필요한 관찰을 함께 받습니다. 추적은 정답 이름의 공개가 아니라 검증 가능한 인계로 끝납니다.",
  "Supported connections remain; unknown identities are not invented. The next team receives provenance, contradictions and the observations still needed. The pursuit ends with a verifiable handoff, not a revealed answer name."),
]


def simple_host(host_id, domain, name_key, accounts, *, via=None, service_policy=None):
    owner = next(iter(accounts))
    address_bytes=hashlib.sha256(host_id.encode()).digest()
    service = {"protocol": "https", "state": "open"}
    if service_policy:
        service["required_policies"] = service_policy
    return {"name": name_key, "domain": domain, "address": f"10.53.{address_bytes[0]%250}.{address_bytes[1]%250+1}", "via": via or ["local"],
            "services": {"22": {"protocol": "ssh", "state": "open"}, "443": service},
            "accounts": accounts,
            "files": {"/": source_entry(kind="dir", owner=owner, mode="755"),
                      "/public": source_entry(kind="dir",owner=owner,mode="755"),
                      "/desk": source_entry(kind="dir", owner=owner, mode="750")}}


def account(secret, groups=None):
    return {"password": secret, "groups": groups or ["staff"], "home": "/desk"}


def mission_shell(pack, mid, title_ko, title_en, sender_ko, sender_en, brief_ko, brief_en, reply_ko, reply_en):
    prefix = PREFIX[pack]
    title_key = text(pack, mid + "_TITLE", title_ko, title_en)
    sender_key = text(pack, mid + "_SENDER", sender_ko, sender_en)
    brief_key = text(pack, mid + "_BRIEF", brief_ko, brief_en)
    reply_key = text(pack, mid + "_REPLY", reply_ko, reply_en)
    host_id, record_id = prefix.lower() + mid.lower() + "_desk", prefix.lower() + mid.lower() + "_handoff"
    domain = mid.lower() + "." + pack + ".packet.test"
    host_name = text(pack, mid + "_DESK_NAME", title_ko + " 담당실", title_en + " Desk")
    user, secret = ("operator", "night-duty") if pack == "defender" else ("investigator", "source-custody")
    intro_access = f"\n\n{user}@{domain}\n{secret}\n"
    TEXT[pack]["ko"][brief_key] += "\n인가된 업무 계정은 아래와 같습니다. 접속 뒤 사건 도구에서 현재 관찰과 허용 조작을 확인할 수 있습니다." + intro_access
    TEXT[pack]["en"][brief_key] += "\nThe authorized work account is below. After connecting, the case tool shows current observations and permitted actions." + intro_access
    return {"schema_version": 1, "mission_id": mid, "title": title_key, "chapter": 1 if int(mid[1:]) <= 2 else 2 if int(mid[1:]) <= 4 else 3 if int(mid[1:]) <= 7 else 4,
            "optional": False, "prerequisites": [] if mid.endswith("01") else [mid[0] + f"{int(mid[1:])-1:02}"],
            "alert_max": 2, "initial_web_url": "https://" + domain, "goal": {"record_id": record_id, "destination": "/home/player/archive"},
            "goals": [{"kind": "sources_preserved"}], "records": {record_id: {"content": "Night duty handoff\nScope: authorized service and observations only.\n", "allowed_sources": ["handoff:" + host_id]}},
            "hosts": {host_id: simple_host(host_id, domain, host_name, {user: account(secret), "citizen_a": account("a-sample", ["citizens"]),
                "citizen_b": account("b-sample", ["citizens"]), "outsider": account("unused-sample", ["visitors"]),
                "notifier": account("ward-sample", ["jobs"])})},
            "pages": {"https://" + domain: {"title": title_key, "body": brief_key, "links": []}},
            "mail": {"intro": {"id": "intro", "sender": sender_key, "subject": title_key, "body": brief_key},
                     "complete": {"id": "complete", "sender": sender_key, "subject": title_key, "body": reply_key}},
            "policies": {}, "challenges": {}, "milestones": []}, host_id, domain, user, secret


def add_guidance(pack, mission, goal_ko, goal_en, hints, principle, abstraction, limit):
    mid = mission["mission_id"]
    mission["goal_text"] = text(pack, mid + "_GOAL", goal_ko, goal_en)
    mission["hints"] = [text(pack, mid + f"_HINT_{i+1}", *hint) for i, hint in enumerate(hints)]
    mission["principle"] = text(pack, mid + "_PRINCIPLE", *principle)
    mission["abstraction"] = text(pack, mid + "_ABSTRACTION", *abstraction)
    mission["limit"] = text(pack, mid + "_LIMIT", *limit)
    mission["tutorial"] = mission["hints"][0]
    mission["explain"] = mission["principle"]


def vm_program():
    return {"entry": "main", "functions": {
        "main": [
            {"label": "entry", "op": "LOAD", "dst": "fmt", "input": "format_ok"},
            {"op": "BRANCH", "reg": "fmt", "then": "signed", "else": "deny"},
            {"label": "signed", "op": "CALL", "function": "check_signature", "dst": "sig"},
            {"op": "BRANCH", "reg": "sig", "then": "grant", "else": "deny"},
            {"label": "grant", "op": "SET_OUTPUT", "key": "release", "value": True}, {"op": "HALT"},
            {"label": "deny", "op": "SET_OUTPUT", "key": "release", "value": False}, {"op": "HALT"}],
        "check_signature": [{"op": "LOAD", "dst": "ok", "input": "signature_ok"}, {"op": "RET", "reg": "ok"}]}}


def configure_vm(mission, pack, challenge_id, *, record_id=None):
    mid = mission["mission_id"]
    name = text(pack, mid + "_VM_NAME", "배포 검증기의 분기와 호출", "Deployment Verifier Branches and Calls")
    definition = {"kind": "branch_vm", "name": name,
        "inputs": {"format_ok": {"type": "bool"}, "signature_ok": {"type": "bool"},
                   "retention_scope": {"type": "enum", "choices": ["authorized", "excluded"]}},
        "limits": {"steps": 256, "stack": 16, "memory": 64}, "program": vm_program(),
        "outcomes": {"normal": {"input_scope": "authorized", "output": {"release": True}},
                     "counterexample": {"input_scope": "excluded", "output": {"release": True}}}}
    if record_id:
        source = "vm:" + challenge_id
        definition.update({"record_id": record_id, "source": source})
        mission["records"][record_id]["allowed_sources"].append(source)
    mission["challenges"][challenge_id] = definition
    mission["goals"] = [{"kind": "vm_cases", "challenge_id": challenge_id, "requirements": ["normal", "counterexample"]}, {"kind": "sources_preserved"}]
    a = [action(challenge_id, "inspect", section="listing"),
         action(challenge_id, "set_input", case_id="valid", values={"format_ok": True, "signature_ok": True, "retention_scope": "authorized"}),
         action(challenge_id, "run", case_id="valid"),
         action(challenge_id, "set_input", case_id="scope_gap", values={"format_ok": True, "signature_ok": True, "retention_scope": "excluded"}),
         action(challenge_id, "run", case_id="scope_gap"), action(challenge_id, "inspect", section="trace")]
    b = [action(challenge_id, "set_input", case_id="format_denied", values={"format_ok": False, "signature_ok": True, "retention_scope": "excluded"}),
         action(challenge_id, "run", case_id="format_denied"),
         action(challenge_id, "set_input", case_id="signature_denied", values={"format_ok": True, "signature_ok": False, "retention_scope": "excluded"}),
         action(challenge_id, "run", case_id="signature_denied"),
         action(challenge_id, "set_input", case_id="blackbox_counter", values={"format_ok": True, "signature_ok": True, "retention_scope": "excluded"}),
         action(challenge_id, "run", case_id="blackbox_counter"), action(challenge_id, "inspect", section="call_graph"),
         action(challenge_id, "set_input", case_id="blackbox_valid", values={"format_ok": True, "signature_ok": True, "retention_scope": "authorized"}),
         action(challenge_id, "run", case_id="blackbox_valid")]
    return a, b


def response_definition(pack, mission, host_id, domain, user, profile):
    mid, prefix = mission["mission_id"], PREFIX[pack].lower()
    cid = prefix + mid.lower() + "_response"
    gateway_id, gateway_domain = prefix + mid.lower() + "_gateway", "gateway." + domain
    gateway_name = text(pack, mid + "_GATEWAY_NAME", "승인된 업무 경로", "Approved Work Route")
    mission["hosts"][gateway_id] = simple_host(gateway_id, gateway_domain, gateway_name,
        copy.deepcopy(mission["hosts"][host_id]["accounts"]), via=[host_id])
    names=["direct_open", "gateway_open", "owner_check", "retry_limit", "session_guard", "photo_check", "no_execution", "target_scope", "notify_open", "standby_open"]
    if profile=='csrf':names+=['context_token','context_origin']
    policy = {name: prefix + mid.lower() + "_" + name for name in names}
    mission["policies"].update({pid: value for name, pid in policy.items() for value in [name in {"direct_open", "gateway_open", "no_execution", "target_scope", "notify_open"}]})
    mission["hosts"][host_id]["services"]["443"]["required_policies"] = {policy["direct_open"]: True}
    mission["hosts"][gateway_id]["services"]["443"]["required_policies"] = {policy["gateway_open"]: True}
    labels = {
        "direct_open": ("원래 업무 입구 열기", "Enable Original Work Entrance"),
        "gateway_open": ("승인 경로 열기", "Enable Approved Route"),
        "owner_check": ("접수 소유자 검사", "Receipt Ownership Check"),
        "retry_limit": ("계정별 반복 시도 제한", "Per-account Retry Limit"),
        "session_guard": ("끝난 세션 권한 검사", "Check Expired Session Authority"),
        "photo_check": ("사진 내용 형식 검사", "Validate Photo Content Type"),
        "no_execution": ("업로드 파일 비실행 저장", "Store Uploads Without Execution"),
        "target_scope": ("알림 목적지 범위 제한", "Constrain Notification Targets"),
        "notify_open": ("주 알림 경로 열기", "Enable Primary Notification Route"),
        "standby_open": ("대기 알림 경로 열기", "Enable Standby Notification Route"),
        "context_token": ("원래 폼의 계정별 nonce 검사", "Check Per-account Nonces at the Original Form"),
        "context_origin": ("원래 폼의 요청 출처 검사", "Check Request Origin at the Original Form"),
    }
    controls = {name: {"policy_id": pid, "values": [False, True], "group": "availability" if name in {"direct_open", "gateway_open", "notify_open", "standby_open"} else "security",
                       "label": text(pack, mid + "_CONTROL_" + name.upper(), *labels[name])} for name, pid in policy.items()}
    objects = {}
    for obj, owner in [("C731", "citizen_a"), ("C732", "citizen_b"), ("HEALTH", "notifier"), ("SECRET", user)]:
        rid = prefix + mid.lower() + "_" + obj.lower()
        objects[obj] = {"owner": owner, "record_id": rid}
        mission["records"][rid] = {"content": f"Receipt {obj}\nCustodian {owner}\nService: night duty\n", "allowed_sources": ["service:" + cid + ":" + obj]}
    endpoints, cases = {}, {}
    scopes = {"citizen_a": ["C731"], "citizen_b": ["C732"], user: ["C731", "C732", "SECRET"], "notifier": ["HEALTH"]}

    def endpoint(eid, operation, path, *, gateway=False, **fields):
        endpoints[eid] = {"host_id": gateway_id if gateway else host_id, "method": "POST" if operation not in {"object_read", "delegated_read", "vfs_read"} else "GET",
                          "path_prefix": path, "operation": operation, **fields}

    def case(case_id, label_ko, label_en, actor, path, expect_status, *, method="GET", body=None, business=None, expected_value=True, gateway_default=False, token_ref=None, alternate=True):
        label = text(pack, mid + "_CASE_" + case_id.upper(), label_ko, label_en)
        ref = {"host_id": host_id, "account_id": actor}
        if token_ref:
            ref["token_ref"] = token_ref
        origin = gateway_domain if gateway_default else domain
        value = {"label": label, "class": "normal" if expected_value else "threat", "actor_ref": ref,
            "request": {"method": method, "url": "https://" + origin + path, "body": copy.deepcopy(body or {}), "headers": {}},
            "expect": {"statuses": expect_status}}
        if business:
            value["expect"].update({"business_key": business, "value": expected_value})
        if alternate and not gateway_default:
            value["routes"] = {"gateway": {"method": method, "url": "https://" + gateway_domain + path, "body": copy.deepcopy(body or {}), "headers": {}}}
        cases[case_id] = value

    if profile in {"objects", "internal", "final"}:
        endpoint("receipts", "object_read", "/tickets/", owner_policy=policy["owner_check"])
        endpoint("delegated", "delegated_read", "/tickets/", gateway=True, scopes=scopes)
        case("own_a", "시민 A의 자기 접수", "Citizen A's Own Receipt", "citizen_a", "/tickets/C731", [200], business="ticket:C731:read")
        case("own_b", "시민 B의 자기 접수", "Citizen B's Own Receipt", "citizen_b", "/tickets/C732", [200], business="ticket:C732:read")
        case("staff", "담당자의 위임된 접수", "Assigned Staff's Delegated Receipt", user, "/tickets/C731", [200], gateway_default=True, business="ticket:C731:read")
        case("foreign_direct", "무관한 계정의 원래 입구 요청", "Unrelated Account at the Original Entrance", "outsider", "/tickets/C731", [401,403,404,503], expected_value=False, business="ticket:C731:read", alternate=False)
        case("foreign_gateway", "무관한 계정의 승인 경로 요청", "Unrelated Account at the Approved Route", "outsider", "/tickets/C731", [401,403,404], gateway_default=True, expected_value=False, business="ticket:C731:read")
    if profile in {"auth","restoration"}:
        safe_rate = prefix + mid.lower() + "_approved_rate"
        mission["policies"][safe_rate] = True
        for gate in [False, True]:
            endpoint("gateway_login" if gate else "login", "auth_login", "/sign-in", gateway=gate,
                     rate_policy=safe_rate if gate else policy["retry_limit"], limit=2, cooldown=2)
        for number in range(1,4):
            case("failed_" + str(number), f"반복 실패 {number}", f"Repeated Failure {number}", "citizen_a", "/sign-in", [401,503] if number<3 else [429,503],
                 method="POST", body={"username": "citizen_a", "password": "incorrect"}, expected_value=False, business="auth:citizen_a:login", alternate=False)
            case("gateway_failed_" + str(number), f"승인 경로의 반복 실패 {number}", f"Repeated Failure {number} at the Approved Route", "outsider", "/sign-in", [401] if number<3 else [429],
                 method="POST", body={"username": "outsider", "password": "incorrect"}, expected_value=False,
                 business="auth:outsider:login", gateway_default=True)
        case("legitimate", "같은 출처의 정상 시민", "Legitimate Citizen at the Shared Origin", "citizen_b", "/sign-in", [200], method="POST", body={"username": "citizen_b", "password": "b-sample"}, business="auth:citizen_b:login")
        case("ward_job", "병원 알림 작업의 정상 인증", "Valid Ward Notification Job Authentication", "notifier", "/sign-in", [200], method="POST", body={"username": "notifier", "password": "ward-sample"}, business="auth:notifier:login")
    if profile in {"session", "rollback", "final","restoration"}:
        tokens = {"old_shift": {"account_id": "citizen_a", "revoked": False, "expires_tick": 999, "scope": ["C731"]},
                  "fresh_shift": {"account_id": "citizen_a", "revoked": False, "expires_tick": 999, "scope": ["C731"]},
                  "other_job": {"account_id": "notifier", "revoked": False, "expires_tick": 999, "scope": ["HEALTH"]}}
        safe_session = prefix + mid.lower() + "_approved_session_guard"
        mission["policies"][safe_session] = True
        for gate in [False, True]:
            issued_tokens = {ref: value for ref,value in tokens.items() if not (gate and profile=="session" and ref=="old_shift")}
            endpoint("gateway_session" if gate else "session", "session_use", "/session", gateway=gate,
                     revocation_policy=safe_session if gate else policy["session_guard"], initial_tokens=issued_tokens)
        case("fresh", "새 정상 세션", "Fresh Legitimate Session", "citizen_a", "/session", [200], method="POST", body={"token_ref": "fresh_shift"}, token_ref="fresh_shift", business="session:fresh_shift:use")
        case("other_job", "다른 정상 장기 작업", "Other Legitimate Long-running Job", "notifier", "/session", [200], method="POST", body={"token_ref": "other_job"}, token_ref="other_job", business="session:other_job:use")
        case("retired", "원래 경로의 끝난 세션", "Retired Authority at the Original Route", "citizen_a", "/session", [401,403,503], method="POST", body={"token_ref": "old_shift"}, token_ref="old_shift", expected_value=False, business="session:old_shift:use",alternate=False)
        case("retired_gateway", "승인 경로의 끝난 세션", "Retired Authority at the Approved Route", "citizen_a", "/session", [401,403], method="POST", body={"token_ref": "old_shift"}, token_ref="old_shift", expected_value=False, business="session:old_shift:use",gateway_default=True)
    if profile in {"upload","restoration"}:
        safe_photo, safe_execution = prefix + mid.lower() + "_approved_photo", prefix + mid.lower() + "_approved_no_execution"
        mission["policies"].update({safe_photo: True, safe_execution: True, policy["no_execution"]: False})
        for gate in [False, True]:
            endpoint("gateway_upload" if gate else "upload", "upload_create", "/photos", gateway=gate,
                     validation_policy=safe_photo if gate else policy["photo_check"], nonexecuting_policy=safe_execution if gate else policy["no_execution"])
        case("photo", "정상 JPEG 사진 생성", "Create a Legitimate JPEG", "citizen_a", "/photos", [201], method="POST", body={"filename":"normal.jpg","mime":"image/jpeg","signature":"JPEG"}, business="upload:normal.jpg:created")
        case("disguised", "사진으로 위장한 입력", "Input Disguised as a Photo", "citizen_a", "/photos", [415,503], method="POST", body={"filename":"fake.jpg","mime":"image/jpeg","signature":"SCRIPT"}, expected_value=False, business="upload:fake.jpg:created", alternate=False)
        case("disguised_gateway", "승인 처리 경로의 위장 파일", "Disguised File at the Approved Processor", "citizen_a", "/photos", [415], method="POST", body={"filename":"fake.jpg","mime":"image/jpeg","signature":"SCRIPT"}, expected_value=False, business="upload:fake.jpg:created", gateway_default=True)
    if profile in {"notify", "rollback", "final","restoration"}:
        for gate in [False, True]:
            endpoint("standby_notify" if gate else "notify", "notify_send", "/notify", gateway=gate,
                     enabled_policy=policy["standby_open"] if gate else policy["notify_open"], allowed_targets=["ward"], target_policy=policy["target_scope"])
        case("notify", "정상 병원 알림 전달", "Deliver a Legitimate Ward Notification", "notifier", "/notify", [200,201], method="POST", body={"target":"ward","message":"handoff-ready"}, business="notify:ward:delivered")
        case("internal_target", "허용 밖 내부 목적지", "An Out-of-scope Internal Target", "notifier", "/notify", [403,503], method="POST", body={"target":"control","message":"unrelated"}, expected_value=False, business="notify:control:delivered", alternate=False)
        case("standby_target", "대기 경로의 허용 밖 목적지", "Out-of-scope Target at Standby", "notifier", "/notify", [403,503], method="POST", body={"target":"control","message":"unrelated"}, expected_value=False, business="notify:control:delivered", gateway_default=True)
    if profile=='csrf':
        safe_context=prefix+mid.lower()+'_gateway_context'
        mission['policies'][safe_context]=True
        for gate in [False,True]:
            endpoint('gateway_setting' if gate else 'setting','csrf_change','/settings',gateway=gate,
                origin='https://'+(gateway_domain if gate else domain),
                token_policy=safe_context if gate else policy['context_token'],
                origin_policy=safe_context if gate else policy['context_origin'],
                tokens={'citizen_a':'gateway-intent-A' if gate else 'form-intent-A','citizen_b':'gateway-intent-B' if gate else 'form-intent-B'},
                scopes={'citizen_a':['notifications'],'citizen_b':['notifications']},own_setting='notifications')
        for who,suffix in [('citizen_a','a'),('citizen_b','b')]:
            body={'setting_id':'notifications','token':'form-intent-'+suffix.upper(),'value':'ward-notify'}
            case('save_'+suffix,'정상 시민 '+suffix.upper()+'의 알림 설정','Legitimate Citizen '+suffix.upper()+' Saving Notifications',who,'/settings',[200],method='POST',body=body,business='setting:'+who+':value',expected_value='ward-notify')
            cases['save_'+suffix]['request']['headers']={'Origin':'https://'+domain}
            cases['save_'+suffix]['routes']['gateway']['headers']={'Origin':'https://'+gateway_domain}
            cases['save_'+suffix]['routes']['gateway']['body']['token']='gateway-intent-'+suffix.upper()
        bad={'setting_id':'notifications','token':'missing-nonce','value':'unwanted-target'}
        case('forged_direct','외부 공지에서 유도된 설정 변경','Setting Change Induced by an External Notice','citizen_a','/settings',[403,503],method='POST',body=bad,business='setting:citizen_a:updated',expected_value=False,alternate=False)
        cases['forged_direct']['request']['headers']={'Origin':'https://news.packet.test'}
        case('forged_gateway','승인 경로로 온 위조된 변경','Forged Change at the Approved Route','citizen_a','/settings',[403],method='POST',body=bad,business='setting:citizen_a:updated',expected_value=False,gateway_default=True)
        cases['forged_gateway']['request']['headers']={'Origin':'https://news.packet.test'}
        outscope={'setting_id':'notifications','token':'form-intent-A','value':'unwanted-target'}
        case('unassigned_gateway','위임되지 않은 계정의 설정 변경','Setting Change by an Undelegated Account','outsider','/settings',[401,403],method='POST',body=outscope,business='setting:outsider:updated',expected_value=False,gateway_default=True)
        cases['unassigned_gateway']['request']['headers']={'Origin':'https://'+gateway_domain}
    if profile == "internal":
        endpoints.clear(); cases.clear()
        internal_id, internal_domain = prefix + mid.lower() + "_internal", "internal." + domain
        name = text(pack, mid + "_INTERNAL_NAME", "내부 건강·보존 서비스", "Internal Health and Retention Service")
        mission["hosts"][internal_id] = simple_host(internal_id, internal_domain, name,
            copy.deepcopy(mission["hosts"][host_id]["accounts"]), via=[host_id], service_policy={policy["direct_open"]: True})
        mission["hosts"][host_id]["services"]["443"].pop("required_policies", None)
        preview_policy = prefix + mid.lower() + "_preview_owned"
        mission["policies"][preview_policy] = True
        endpoint("preview", "object_read", "/preview/", owner_policy=preview_policy)
        endpoints["internal"] = {"host_id": internal_id, "method": "GET", "path_prefix": "/state/", "operation": "object_read", "owner_policy": policy["owner_check"]}
        endpoint("proxy", "delegated_read", "/state/", gateway=True, scopes={"notifier": ["HEALTH"]})
        case("preview", "시민의 정상 미리보기", "Citizen's Legitimate Preview", "citizen_a", "/preview/C731", [200], business="ticket:C731:read", alternate=False)
        case("health", "작업자의 필수 건강 확인", "Worker's Required Health Check", "notifier", "/state/HEALTH", [200], business="ticket:HEALTH:read")
        cases["health"]["request"]["url"] = "https://" + internal_domain + "/state/HEALTH"
        case("secret", "작업자의 범위 밖 보존 자료", "Worker Reading Out-of-scope Retention Data", "notifier", "/state/SECRET", [403,503], business="ticket:SECRET:read", expected_value=False, alternate=False)
        cases["secret"]["request"]["url"] = "https://" + internal_domain + "/state/SECRET"
        case("proxy_secret", "승인 프록시의 범위 밖 요청", "Out-of-scope Request at the Approved Proxy", "notifier", "/state/SECRET", [403], business="ticket:SECRET:read", expected_value=False, gateway_default=True)
    if profile == "vfs":
        for hid, folder, group in [(host_id, "/deploy", "deploy"), (gateway_id, "/approved", "jobs")]:
            host = mission["hosts"][hid]
            host["files"][folder] = source_entry(kind="dir", owner=user, group=group, mode="750")
            host["files"][folder + "/status.txt"] = source_entry("PENDING\n", owner=user, group=group, mode="660")
        for gate, folder in [(False, "/deploy"), (True, "/approved")]:
            endpoint("approved_read" if gate else "deployment_read", "vfs_read", "/deployment/read", gateway=gate, file_path=folder + "/status.txt")
            endpoint("approved_write" if gate else "deployment_write", "vfs_write", "/deployment/write", gateway=gate, file_path=folder + "/status.txt")
        case("read", "배포 계정의 상태 읽기", "Deployment Account Reading Its Status", "notifier", "/deployment/read", [200])
        case("write", "배포 계정의 작업 결과 쓰기", "Deployment Account Writing Its Work Result", "notifier", "/deployment/write", [200,201], method="POST", body={"content":"DEPLOYMENT READY\n"})
        case("foreign_write", "비담당 계정의 배포 파일 변경", "Unrelated Account Modifying Deployment", "outsider", "/deployment/write", [403], method="POST", body={"content":"UNAUTHORIZED\n"}, expected_value=False, alternate=False)
        case("foreign_approved", "승인 경로의 비담당 쓰기", "Unrelated Write at the Approved Route", "outsider", "/deployment/write", [403], method="POST", body={"content":"UNAUTHORIZED\n"}, expected_value=False, gateway_default=True)
    used_controls = {
        "objects": ["direct_open", "gateway_open", "owner_check"],
        "auth": ["direct_open", "gateway_open", "retry_limit"],
        "session": ["direct_open", "gateway_open", "session_guard"],
        "upload": ["direct_open", "gateway_open", "photo_check", "no_execution"],
        "internal": ["direct_open", "gateway_open", "owner_check"],
        "rollback": ["notify_open", "standby_open", "session_guard", "target_scope"],
        "final": ["direct_open", "gateway_open", "owner_check", "session_guard", "target_scope", "notify_open", "standby_open"],
        "restoration": ["direct_open","gateway_open","retry_limit","session_guard","photo_check","no_execution","target_scope","notify_open","standby_open"],
        "csrf":['direct_open','gateway_open','context_token','context_origin'],
    }.get(profile, ["direct_open", "gateway_open", "notify_open", "standby_open", "target_scope"])
    controls = {key: value for key, value in controls.items() if key in used_controls}
    if profile == "vfs":
        controls = {
            "job_groups": {"kind":"actor_groups","host_id":host_id,"account_id":"notifier","values":[["jobs"],["jobs","deploy"]],"group":"permissions",
                "label":text(pack,mid+"_JOB_GROUPS","배포 계정의 필요한 그룹","Required Deployment Account Groups")},
            "directory_mode": {"kind":"vfs_mode","host_id":host_id,"file_path":"/deploy","values":["750","777"],"group":"permissions",
                "label":text(pack,mid+"_DIRECTORY_MODE","배포 폴더의 탐색 권한","Deployment Folder Traversal Rights")},
            "file_mode": {"kind":"vfs_mode","host_id":host_id,"file_path":"/deploy/status.txt","values":["660","666"],"group":"permissions",
                "label":text(pack,mid+"_FILE_MODE","작업 결과 파일의 권한","Work Result File Rights")}}
    definition = {"kind": "response_lab", "name": text(pack, mid + "_LAB_NAME", "현재 업무와 대응 검증", "Live Work and Response Checks"),
        "host_id": host_id, "requires_session": {"host_id": host_id, "account_id": user}, "controls": controls,
        "bindings": {"objects": objects, "endpoints": endpoints}, "cases": cases,
        "checkpoint_groups": {"availability": [name for name, control in controls.items() if control["group"] == "availability"],
                              "security": [name for name, control in controls.items() if control["group"] == "security"]}}
    if profile == "vfs":
        definition["bindings"]["write_scope"] = ["/deploy/status.txt","/approved/status.txt"]
        definition["checkpoint_groups"] = {"permissions":list(controls)}
    return cid, definition, policy, gateway_id


DEFENDER_GUIDANCE = {
 "D01": ("타인 접수 열람은 거부하고 두 시민과 담당자의 정상 열람을 유지한다.", "Refuse unrelated receipt access while preserving both citizens' and assigned staff reads.",
           "소유자 검사 또는 좁은 위임 경로가 결과를 어떻게 바꾸는지 보세요.", "Observe how ownership checks or narrow delegation change the result."),
 "D02": ("반복 인증 실패를 제한하되 같은 출처의 정상 시민·알림 작업을 살린다.", "Limit repeated authentication failures while retaining legitimate citizen and notification access at the shared origin.",
           "주소 전체가 아닌 계정별 시도와 승인된 인증 경로를 비교하세요.", "Compare account-specific attempts and approved authentication routes instead of blocking an address."),
 "D03": ("끝난 세션은 거부되고 다른 정상 세션은 계속 동작하게 한다.", "Refuse expired authority while keeping other legitimate sessions working.",
           "표적 폐기 또는 옛 세션을 발급하지 않은 승인 경로로의 교체를 비교하세요.", "Compare targeted revocation with migration to an approved route that did not issue the old session."),
 "D04": ("위장 파일은 만들지 않고 정상 JPEG는 안전한 처리 경로에 생성한다.", "Prevent disguised-file creation while creating a legitimate JPEG through a safe processor.",
           "이름·MIME·내용 표식과 실제 저장/실행 상태를 분리하세요.", "Separate name, MIME type and content signature from actual storage and execution state."),
 "D05": ("미리보기·건강 확인을 살리고 내부 자료의 비인가 읽기를 막는다.", "Preserve previews and health checks while preventing unauthorized internal reads.",
           "작업자가 요청한 객체의 소유권과 승인 프록시의 scope를 비교하세요.", "Compare the worker's object ownership with the approved proxy's scope."),
 "D06": ("배포 계정의 읽기·쓰기는 살리고 비담당 파일 변경은 거부한다.", "Enable deployment reads and writes while refusing unrelated modifications.",
           "상위 폴더와 현재 그룹을 보거나 승인된 대체 경로를 사용하세요.", "Inspect ancestor directories and current groups, or use the approved alternative route."),
 "D07": ("정상 알림을 복구하고 폐기한 세션과 범위 밖 목적지는 계속 거부한다.", "Restore notifications while keeping revoked sessions and out-of-scope targets refused.",
           "정책 그룹만 되돌릴 수 있고 폐기한 열쇠는 돌아오지 않습니다.", "Only the policy group is rolled back; a revoked key does not return."),
 "D08": ("선택한 경로에서 접수·알림·세션의 정상 업무와 위협 행렬을 모두 만족한다.", "Satisfy legitimate receipt, notification and session work alongside threat refusal on the chosen routes.",
           "한 서비스의 성공으로 다른 업무를 확인한 것으로 세지 마세요.", "Success in one service does not establish another workflow."),
}


def build_defender():
    pack, missions, fixtures = "defender", {}, {}
    profiles = {"D01":"objects","D02":"auth","D03":"session","D04":"upload","D05":"internal","D06":"vfs","D07":"rollback","D08":"final"}
    for row in DEFENDER_STORIES:
        mid = row[0]
        mission, host_id, domain, user, secret = mission_shell(pack,*row)
        cid, definition, policies, gateway_id = response_definition(pack,mission,host_id,domain,user,profiles[mid])
        mission["challenges"][cid] = definition
        mission["goals"].insert(0,{"kind":"response_matrix","challenge_id":cid,"case_ids":list(definition["cases"])})
        goal_ko,goal_en,clue_ko,clue_en = DEFENDER_GUIDANCE[mid]
        add_guidance(pack,mission,goal_ko,goal_en,
            [("정상 업무와 문제가 되는 요청을 따로 관찰하세요. "+clue_ko,"Observe legitimate work separately from the problematic requests. "+clue_en),
             ("현재 actor·대상·경로를 고정하고 대응 범위 하나만 바꿔 결과를 비교하세요.","Hold actor, target and route fixed and change one response scope to compare results."),
             ("원래 경로의 정밀 제어 또는 승인된 대체 경로를 선택할 수 있습니다. 모든 종료는 정상 업무도 실패시킵니다.","Choose precise control of the original route or an approved alternative. Turning everything off also fails legitimate work.")],
            (clue_ko,clue_en),
            ("등록된 요청과 계정·서비스·정책만 있는 작은 모의 업무입니다. 실제 결과는 같은 세계 handler에서 나옵니다.","This is a bounded work model with registered requests, accounts, services and policies. Actual outcomes come from the shared world handlers."),
            ("관찰한 시나리오 밖의 모든 공격을 막았다는 보증은 아닙니다.","Passing the observed scenarios does not establish prevention of every possible attack."))
        setup=login(domain,user,secret)+[action(cid,"inspect")]
        a,b=list(setup),list(setup)
        if mid in {"D01","D05","D08"}:
            a.append(action(cid,"set_control",control_id="owner_check",value=True))
            b.append(action(cid,"set_control",control_id="direct_open",value=False))
        if mid=="D02":
            a.append(action(cid,"set_control",control_id="retry_limit",value=True))
            b.append(action(cid,"set_control",control_id="direct_open",value=False))
        if mid=="D03":
            a.append(action(cid,"set_control",control_id="session_guard",value=True))
            a.append(action(cid,"revoke",token_ref="old_shift"))
            b.append(action(cid,"set_control",control_id="direct_open",value=False))
        if mid=="D04":
            a += [action(cid,"set_control",control_id="photo_check",value=True),action(cid,"set_control",control_id="no_execution",value=True)]
            b.append(action(cid,"set_control",control_id="direct_open",value=False))
        if mid=="D06":
            a.append(action(cid,"set_control",control_id="job_groups",value=["jobs","deploy"]))
        if mid in {"D07","D08"}:
            a.append(action(cid,"set_control",control_id="session_guard",value=True));b.append(action(cid,"set_control",control_id="session_guard",value=True))
            a.append(action(cid,"revoke",token_ref="old_shift"));b.append(action(cid,"revoke",token_ref="old_shift"))
        if mid=="D08":
            b.append(action(cid,"set_control",control_id="standby_open",value=True))
        if mid=="D07":
            mission['policies'][policies['notify_open']]=False
            definition['initial_checkpoints']={'baseline_availability':{
                'group':'availability','values':{'notify_open':True,'standby_open':False},
                'label':text(pack,mid+'_BASELINE_CHECKPOINT','정상 인계 시점의 알림 가용성','Notification Availability at the Verified Handoff')}}
            for path in [a,b]:
                path.append(action(cid,'probe',case_id='notify'))
            a.append(action(cid,"rollback",checkpoint_id="baseline_availability",group="availability"))
            b.append(action(cid,"set_control",control_id="standby_open",value=True))
        for case_id,case in definition["cases"].items():
            a.append(action(cid,"probe",case_id=case_id))
            route="gateway" if case.get("class")=="normal" and "gateway" in case.get("routes",{}) else None
            if mid=="D07" and case_id!="notify":route=None
            b.append(action(cid,"probe",case_id=case_id,**({"route_id":route} if route else {})))
        expected={"completed":True,"sources_preserved":True,"facts":[],"archive_record_ids":[],"policies":{},
                  "model_outcomes":{cid:{"kind":"response_matrix","case_ids":list(definition["cases"])}}}
        expected_a,expected_b=copy.deepcopy(expected),copy.deepcopy(expected)
        if mid in {'D01','D05','D08'}:expected_a['policies'][policies['owner_check']]=True
        if mid in {'D01','D02','D03','D04','D05','D08'}:expected_b['policies'][policies['direct_open']]=False
        if mid=='D02':expected_a['policies'][policies['retry_limit']]=True
        if mid in {'D03','D07','D08'}:expected_a['policies'][policies['session_guard']]=True
        if mid in {'D07','D08'}:expected_b['policies'][policies['session_guard']]=True
        if mid=='D04':expected_a['policies'].update({policies['photo_check']:True,policies['no_execution']:True})
        if mid=='D07':
            expected_a['policies'].update({policies['notify_open']:True,policies['standby_open']:False})
            expected_b['policies'].update({policies['notify_open']:False,policies['standby_open']:True})
        if mid=="D06":
            expected_a["remote_files"]={host_id:{"/deploy/status.txt":{"content":"DEPLOYMENT READY\n"}}}
            expected_b["remote_files"]={gateway_id:{"/approved/status.txt":{"content":"DEPLOYMENT READY\n"}}}
        mission["milestones"]=[{"id":PREFIX[pack]+mid+"_brief","title":mission["title"],"text":mission["mail"]["intro"]["body"]},
                               {"id":PREFIX[pack]+mid+"_checks","title":definition["name"],"text":mission["goal_text"]}]
        missions[mid]=mission
        fixtures[mid]={"paths":[{"id":"precise","name":"Precise response in the current workflow","actions":a,"expected":expected_a},
                                {"id":"approved_route","name":"Approved alternative or scoped authority","actions":b,"expected":expected_b}],
                       "negative_hints":["all_services_off_does_not_complete","normal_and_threat_outcomes_both_required"]}
    result=pack_shell("defender",missions,"midnight_defender",1)
    result["contacts"]={"C02":{"name_key":missions["D01"]["mail"]["intro"]["sender"],"introduced_by":["D01"],"face_gate":{"when":"introduced","mission_id":"D01","explicit":False}},
                        "C01":{"name_key":missions["D03"]["mail"]["intro"]["sender"],"introduced_by":["D03"],"face_gate":{"when":"introduced","mission_id":"D03","explicit":True}},
                        "C04":{"name_key":missions["D05"]["mail"]["intro"]["sender"],"introduced_by":["D05"],"face_gate":{"when":"introduced","mission_id":"D05","explicit":False}}}
    return result,fixtures


def observed(event, time, public, source, *, offset=(0,0), authority="server_issued", vantage="relay"):
    return {"event_id":event,"observed_at":list(time),"clock_offset":list(offset),"public":copy.deepcopy(public),
            "provenance":{"source_id":source,"collector":"authorized-export","vantage":vantage,"acquisition":"bounded-observation","marker_authority":authority}}


def build_tracker():
    pack,missions,fixtures="tracker",{},{}
    for row in TRACKER_STORIES:
        mid,title_ko,title_en,brief_ko,brief_en,reply_ko,reply_en=row
        mission,host_id,domain,user,secret=mission_shell(pack,mid,title_ko,title_en,"민서","Minseo",brief_ko,brief_en,reply_ko,reply_en)
        prefix=PREFIX[pack]+mid+"_"
        cid=PREFIX[pack].lower()+mid.lower()+"_observations"
        sensor_a,sensor_b,sensor_next=[prefix.lower()+suffix for suffix in ["field","independent","next"]]
        request="N"+mid[1:];target={"T01":"relay","T03":"archive","T04":"north","T05":"retention","T06":"vault","T07":"east","T08":"vault"}.get(mid,"relay")
        event_from,event_to=prefix+"DEPART",prefix+"ARRIVE"
        fields={"request_tag":request,"from_node":"edge","to_node":target,"session_tag":"S1","shared_address":"10.53.9.8"}
        a_rows=[observed(event_from,(110,112),fields,mid+":field",vantage="edge")]
        b_rows=[observed(event_from,(110,113),fields,mid+":receiver",vantage=target)]
        claims=[{"kind":"forwarded_to","left":"request:"+request,"right":"node:"+target}]
        required=[{"kind":"forwarded_to","request_tag":request,"target_node":target}]
        early=[];refuted=[];initial={}
        if mid=="T01":
            early=[observed(prefix+"ADDRESS_A",(100,115),{"session_tag":"S1","shared_address":"10.53.9.8"},mid+":shared-address",authority="client_supplied"),
                   observed(prefix+"ADDRESS_B",(100,115),{"session_tag":"S2","shared_address":"10.53.9.8"},mid+":shared-address",authority="client_supplied")]
        if mid=="T02":
            a_rows=[observed(event_from,(200,202),{"request_tag":request,"from_node":"edge","to_node":"relay"},mid+":clock-a",offset=(90,92)),
                    observed(event_to,(140,142),{"request_tag":request,"from_node":"relay","to_node":"vault"},mid+":clock-b",offset=(20,22))]
            b_rows=[observed(event_from,(109,111),{"request_tag":request,"from_node":"edge","to_node":"relay"},mid+":signed-order"),
                    observed(event_to,(119,121),{"request_tag":request,"from_node":"relay","to_node":"vault"},mid+":recipient")]
            claims=[{"kind":"before","left":"event:"+event_from,"right":"event:"+event_to}]
            required=copy.deepcopy(claims)
        if mid=="T03":
            early=[observed(prefix+"COPY",(100,130),{"record_digest":"paper-N47","claimed_account":"maint"},mid+":republished-copy",authority="client_supplied")]
            for rows in [a_rows,b_rows]:
                rows[0]["public"]["record_digest"]="paper-N47"
        if mid=="T04":
            early=[observed(prefix+"RELAY",(100,105),{"request_tag":request,"from_node":"edge","to_node":"relay"},mid+":old-window")]
        if mid=="T05":
            a_rows.insert(0,observed(prefix+"ROTATE",(100,102),{"account_handle":"maint","event":"credential-replaced"},mid+":credential-history"))
            b_rows.insert(0,observed(prefix+"ROTATE",(99,103),{"account_handle":"maint","event":"credential-replaced"},mid+":signed-delegation"))
            for rows in [a_rows,b_rows]:rows[-1]["public"]["account_handle"]="maint"
            claims.append({"kind":"before","left":"event:"+prefix+"ROTATE","right":"event:"+event_from})
            required.append(copy.deepcopy(claims[-1]))
        if mid=="T06":
            a_rows[0]["public"].update({"encrypted":True,"size_bucket":"small"})
            b_rows[0]["public"].update({"application_event":"handoff-marker","authorized_excerpt":"delivery accepted"})
        if mid=="T07":
            prior={"kind":"same_session","left":"session:S1","right":"session:S2"}
            initial={"prior":{"label":text(pack,mid+"_PRIOR","앞 조사자의 동일 세션 추측","Prior Investigator's Same-session Suggestion"),"claim":prior,"source_id":"prior-notes"}}
            # The prior statement is not endorsed by the player or graded against
            # a hidden identity; trusted observations can contradict it directly.
            early=[observed(prefix+"WEAK_A",(90,130),{"session_tag":"S1","shared_address":"10.53.9.8"},mid+":prior-notes",authority="client_supplied"),
                   observed(prefix+"WEAK_B",(90,130),{"session_tag":"S2","shared_address":"10.53.9.8"},mid+":prior-notes",authority="client_supplied")]
            for rows,source in [(a_rows,"field"),(b_rows,"independent")]:
                rows += [observed(prefix+"TRUSTED_A",(110,112),{"session_tag":"S1","shared_address":"10.53.9.8"},mid+":"+source+"-registry"),
                         observed(prefix+"TRUSTED_B",(110,112),{"session_tag":"S2","shared_address":"10.53.9.8"},mid+":"+source+"-registry")]
            refuted=["prior"]
        if mid=="T08":
            a_rows=[observed(event_from,(110,112),{"request_tag":request,"from_node":"edge","to_node":"relay","session_tag":"S1"},mid+":edge-outbox",vantage="edge"),
                    observed(event_to,(118,120),{"request_tag":request,"from_node":"relay","to_node":"vault","session_tag":"S1"},mid+":relay-outbox",vantage="relay")]
            b_rows=[observed(event_from,(109,113),{"request_tag":request,"from_node":"edge","to_node":"relay","session_tag":"S1"},mid+":relay-inbox",vantage="relay"),
                    observed(event_to,(117,121),{"request_tag":request,"from_node":"relay","to_node":"vault","session_tag":"S1"},mid+":vault-inbox",vantage="vault")]
            claims=[{"kind":"forwarded_to","left":"request:"+request,"right":"node:relay"},
                    {"kind":"forwarded_to","left":"request:"+request,"right":"node:vault"}]
            required=[{"kind":"forwarded_to","request_tag":request,"target_node":node} for node in ["relay","vault"]]
        sensors={}
        for sid,label_ko,label_en,rows,source in [(sensor_a,"현장 관측","Field Observation",a_rows,"field"),(sensor_b,"독립 출처 관측","Independent Source Observation",b_rows,"independent")]:
            windows=([{"rows":early}] if sid==sensor_a and early else [])+[{"rows":rows}]
            times=[r["observed_at"] for window in windows for r in window["rows"]]
            sensors[sid]={"label":text(pack,mid+"_SENSOR_"+source.upper(),label_ko,label_en),"host_id":host_id,
                          "visibility":"endpoint" if mid=="T06" and sid==sensor_b else "metadata",
                          "coverage":{"sampling":"complete","window":[min(t[0] for t in times),max(t[1] for t in times)]},"windows":windows,
                          "requires_session":{"host_id":host_id,"account_id":user}}
        sensors[sensor_next]={"label":text(pack,mid+"_NEXT_SENSOR","다음 인계 관찰 지점","Next Handoff Vantage"),"host_id":host_id,"visibility":"metadata",
                              "coverage":{"sampling":"sampled","window":[150,180]},"windows":[{"rows":[]}],"requires_session":{"host_id":host_id,"account_id":user}}
        definition={"kind":"observation_case","name":text(pack,mid+"_TOOL_NAME","출처·관측·가설","Sources, Observations and Hypotheses"),
                    "sensors":sensors,"claim_types":["same_session","forwarded_to","before"],"initial_claims":initial,
                    "handoff_requirements":{"supported":required,"refuted":refuted,"next_vantage":[sensor_next],"allow_identity_unknown":True}}
        mission["challenges"][cid]=definition
        mission["goals"].insert(0,{"kind":"observation_handoff","challenge_id":cid})
        add_guidance(pack,mission,"요구된 연결을 관측으로 뒷받침하고 반증·미확정 범위와 다음 관찰 지점을 인계한다.",
            "Support the required connection with observations and hand off contradictions, uncertainty and the next vantage.",
            [("현재 관측이 말하는 범위와 아직 모르는 것을 나누세요.","Separate what current observations establish from what remains unknown."),
             ("같은 IP나 이름 대신 출처·서버 발급 표식·보정된 시간 구간을 연결하세요.","Connect provenance, server-issued markers and corrected time intervals rather than an IP or a name."),
             ("현장 또는 독립 출처에서 새 관측을 확보하세요. 이전 메모를 믿거나 일부러 틀린 가설을 만들 의무는 없습니다.","Collect new field or independent observations. You need not accept a prior note or intentionally form an incorrect hypothesis.")],
            ("가설의 상태는 수집한 공개 관측에서만 계산하며 내부 범인의 이름과 대조하지 않습니다.","Hypothesis status is derived only from collected public observations, never compared to a hidden culprit's name."),
            ("허가된 유한 관측 구간과 작은 관계 종류만 있는 모의 사건입니다.","This is a bounded case with authorized observation windows and a small set of relation types."),
            ("지지된 세션·전송 연결이 사람의 실명이나 보이지 않는 내용을 증명하지는 않습니다.","A supported session or transmission link does not establish a person's identity or unseen content."))
        setup=login(domain,user,secret)+[action(cid,"inspect")]
        a,b=list(setup),list(setup)
        if early:
            a.append(action(cid,"collect",sensor_id=sensor_a))
            if mid=="T07":
                weak_ids=[sensor_a+":0:"+r["event_id"] for r in early]
                a += [action(cid,"hypothesize",hypothesis_id="tentative",claim=initial["prior"]["claim"],observation_ids=weak_ids),action(cid,"test",hypothesis_id="tentative")]
            a.append(action(cid,"advance_watch",sensor_id=sensor_a))
        a.append(action(cid,"collect",sensor_id=sensor_a));b.append(action(cid,"collect",sensor_id=sensor_b))
        ids_a=[sensor_a+(":1:" if early else ":0:")+r["event_id"] for r in a_rows]
        ids_b=[sensor_b+":0:"+r["event_id"] for r in b_rows]
        hypothesis_ids=[]
        for number,claim in enumerate(claims):
            hid="supported_"+str(number+1);hypothesis_ids.append(hid)
            a += [action(cid,"hypothesize",hypothesis_id=hid,claim=claim,observation_ids=ids_a),action(cid,"test",hypothesis_id=hid)]
        if mid=="T07":
            a.append(action(cid,"revise",hypothesis_id="tentative",replacement_claim=claims[0],reason_observation_ids=ids_a))
        a.append(action(cid,"handoff",supported_hypothesis_ids=hypothesis_ids,next_sensor_id=sensor_next))
        direct_claims=[{**claim,"observation_ids":ids_b} for claim in claims]
        b.append(action(cid,"handoff",claims=direct_claims,supported_hypothesis_ids=[],next_sensor_id=sensor_next))
        expected={"completed":True,"sources_preserved":True,"facts":[],"archive_record_ids":[],"policies":{},
                  "model_outcomes":{cid:{"kind":"observation_handoff","supported":required,"refuted_initial_claims":refuted,"next_sensor_id":sensor_next}}}
        missions[mid]=mission
        fixtures[mid]={"paths":[{"id":"field_hypotheses","name":"Field observation with explicit hypothesis evaluation","actions":a,"expected":copy.deepcopy(expected)},
                                {"id":"independent_handoff","name":"Independent observations with direct supported handoff","actions":b,"expected":copy.deepcopy(expected)}],
                       "negative_hints":["shared_address_is_not_identity","uncollected_observation_cannot_support_claim","unknown_only_cannot_complete"]}
    result=pack_shell("tracker",missions,"midnight_tracker",1)
    result["contacts"]={"C03":{"name_key":missions["T01"]["mail"]["intro"]["sender"],"introduced_by":["T01"],"face_gate":{"when":"introduced","mission_id":"T01","explicit":False}}}
    return result,fixtures


def pack_shell(pack,missions,campaign_id,content_version):
    names={"intruder":("침투자 · 심야접속","Intruder · Midnight Access"),
           "defender":("방어자 · 계속 돌아가는 도시","Defender · The City That Keeps Working"),
           "tracker":("추적자 · 남은 연결의 범위","Tracker · The Remaining Connection")}
    title=text(pack,"PACK_TITLE",*names[pack])
    end_title=text(pack,"ENDING_TITLE","검증 가능한 인계" if pack=="tracker" else "다음 교대로" if pack=="defender" else "남겨진 기록",
                   "A Verifiable Handoff" if pack=="tracker" else "To the Next Shift" if pack=="defender" else "The Retained Record")
    last=list(missions)[-1]
    return {"schema_version":1,"content_version":content_version,"campaign_id":campaign_id,"title":title,
            "start_mission":list(missions)[0],"mission_order":list(missions),"missions":missions,
            "endings":[{"id":PREFIX[pack].lower()+"handoff","title":end_title,"text":missions[last]["mail"]["complete"]["body"],"requires_facts":[]}]}


def public_keys(value,known):
    found=set()
    if isinstance(value,dict):
        for item in value.values():found.update(public_keys(item,known))
    elif isinstance(value,list):
        for item in value:found.update(public_keys(item,known))
    elif isinstance(value,str) and value in known:
        found.add(value)
    return found


def write_pack(pack,definition):
    used=public_keys(definition,TEXT[pack]["en"])
    for lang in ["ko","en"]:
        assert used<=set(TEXT[pack][lang])
        source={key:TEXT[pack][lang][key] for key in sorted(used)}
        write(DATA/"locales"/(FILES[pack]+"."+lang+".json"),source)
    write(PACKS/(FILES[pack]+".json"),definition)
    return len(used)


def remap(value,identities,field=''):
    if isinstance(value,dict):return {(identities.get(k,k) if field in {'policies','remote_files','model_states','model_outcomes'} else k):remap(v,identities,k) for k,v in value.items()}
    if isinstance(value,list):return [remap(v,identities,field) for v in value]
    if isinstance(value,str):
        if field in {'host_id','record_id','challenge_id','tool_id','fact_id','facts','archive_record_ids','target'}:return identities.get(value,value)
        if field=='line':
            tokens=value.split(' ',2)
            if len(tokens)>=2 and tokens[0] in {'configure','tool','nmap','route'}:
                tokens[1]=identities.get(tokens[1],tokens[1]);return ' '.join(tokens)
        return value
    return value


def remove_ledger_visits(actions,mission,proof_hosts):
    domains={h['domain']:hid for hid,h in mission['hosts'].items()}
    stack=['local'];pending=None;kept=[]
    for item in actions:
        if item['kind']=='command' and item['line'].startswith('ssh '):
            account_name,domain=item['line'][4:].split('@',1);pending=domains[domain]
            if pending not in proof_hosts:kept.append(copy.deepcopy(item))
        elif item['kind']=='password':
            stack.append(pending)
            if pending not in proof_hosts:kept.append(copy.deepcopy(item))
            pending=None
        elif item['kind']=='command' and item['line']=='exit':
            source=stack.pop()
            if source not in proof_hosts:kept.append(copy.deepcopy(item))
        elif stack[-1] not in proof_hosts and not (item['kind']=='tool' and '_exhibit_' in item['tool_id']):
            kept.append(copy.deepcopy(item))
    # After optional ledger visits disappear, don't force a redundant logout and
    # reauthentication at the same target with the same already-valid identity.
    result=[];stack=[('local','')];pending=None;i=0
    while i<len(kept):
        item=kept[i]
        if item['kind']=='command' and item['line']=='exit' and i+2<len(kept):
            nxt,pw=kept[i+1:i+3]
            if nxt['kind']=='command' and nxt['line'].startswith('ssh ') and pw['kind']=='password':
                user,domain=nxt['line'][4:].split('@',1)
                if stack[-1]==(domain,user):i+=3;continue
        result.append(item)
        if item['kind']=='command' and item['line'].startswith('ssh '):
            user,domain=item['line'][4:].split('@',1);pending=(domain,user)
        elif item['kind']=='password':stack.append(pending);pending=None
        elif item['kind']=='command' and item['line']=='exit':stack.pop()
        i+=1
    return result


def replace_access_alternative(mission,mid,identities,raw_access):
    """Current, authorized object access replaces a canned 'retained proof' answer."""
    host_id=identities['custody'+mid.lower()]
    owner=raw_access[mid][2]
    cid=identities[mid.lower()+'_alternate']
    rid=mission['goal']['record_id']
    source='object:'+cid
    policy=PREFIX['intruder'].lower()+mid.lower()+'_delegated_scope'
    resource={'M04':'B204','M05':'C731','M09':'R609','M11':'marker','M14':'HEALTH','M16':'retention-note','M18':'token-status','M21':'ECHO-21'}.get(mid,'target')
    mission['policies'][policy]=True
    mission['records'][rid]['allowed_sources']=[s for s in mission['records'][rid]['allowed_sources'] if s!='model:'+cid]
    mission['records'][rid]['allowed_sources'].append(source)
    mission['challenges'][cid]={'kind':'idor','name':'IN2_TOOL_IDOR_NAME','host_id':host_id,'policy_id':policy,
        'objects':{resource:{'owner':owner,'record_id':rid,'source':source}},'record_id':rid,'source':source,
        'fact_id':identities[mid.lower()+'_evidence'],'requires_session':{'host_id':host_id,'account_id':owner}}
    url='https://'+mission['hosts'][host_id]['domain']+'/assigned'
    mission['pages'][url]={'title':'IN2_'+mid+'_TITLE','body':'IN2_'+mid+'_ROUTE','links':[],'host_id':host_id,
        'challenge_id':cid,'requires_session':{'host_id':host_id,'account_id':owner}}
    return {'kind':'request','method':'GET','url':url,'body':{'input':{'object_id':resource}},'headers':{}}


def configure_final_boundaries(mission,identities,access):
    pack,mid='intruder','M24';host_id=identities['control'];domain=mission['hosts'][host_id]['domain'];user=access[mid][0]
    for who,secret,groups in [('citizen_a','a-sample',['citizens']),('citizen_b','b-sample',['citizens']),('outsider','unused-sample',['visitors']),('notifier','ward-sample',['jobs'])]:
        mission['hosts'][host_id]['accounts'][who]=account(secret,groups)
    cid,definition,policies,gateway=response_definition(pack,mission,host_id,domain,user,'objects')
    mission['policies'][policies['owner_check']]=True
    vault=PREFIX[pack].lower()+'m24_vault';vault_domain='vault.'+domain
    edge=PREFIX[pack].lower()+'m24_edge';edge_domain='edge.'+domain
    vault_name=text(pack,'M24_VAULT_NAME','제한된 지시 보관 서비스','Limited Directive Vault')
    edge_name=text(pack,'M24_EDGE_NAME','공용 관찰 노드','Public Observation Node')
    mission['hosts'][vault]=simple_host(vault,vault_domain,vault_name,copy.deepcopy(mission['hosts'][host_id]['accounts']),via=[host_id,gateway])
    mission['hosts'][edge]=simple_host(edge,edge_domain,edge_name,copy.deepcopy(mission['hosts'][host_id]['accounts']))
    svc_policy=PREFIX[pack].lower()+'m24_service_scope';mission['policies'][svc_policy]=True
    definition['bindings']['endpoints']['vault']={'host_id':vault,'method':'GET','path_prefix':'/scope/','operation':'object_read','owner_policy':svc_policy}
    definition['bindings']['endpoints']['vault_delegate']={'host_id':gateway,'method':'GET','path_prefix':'/scope/','operation':'delegated_read','scopes':{user:['SECRET']}}
    labels=[('route_allowed','현재 중계에서 내부 건강 자료','Internal Health Record from the Current Relay',host_id,'notifier','HEALTH',[200],True),
            ('route_denied','공용 노드에서 내부 직접 경로','Direct Internal Route from the Public Node',edge,'outsider','HEALTH',[403,503],False),
            ('service_allowed','제한 자격의 지시 자료 읽기','Directive Read by a Limited Credential',host_id,user,'SECRET',[200],True),
            ('service_denied','범위 밖 자격의 지시 요청','Directive Request Outside Credential Scope',host_id,'outsider','SECRET',[403],False)]
    for case_id,ko,en,actor_host,actor,obj,statuses,value in labels:
        label=text(pack,'M24_CASE_'+case_id.upper(),ko,en)
        definition['cases'][case_id]={'label':label,'class':'normal' if value else 'threat','actor_ref':{'host_id':actor_host,'account_id':actor},
            'request':{'method':'GET','url':'https://'+vault_domain+'/scope/'+obj,'body':{},'headers':{}},'expect':{'statuses':statuses}}
        if case_id=='service_allowed':
            definition['cases'][case_id]['routes']={'gateway':{'method':'GET','url':'https://'+mission['hosts'][gateway]['domain']+'/scope/SECRET','body':{},'headers':{}}}
    mission['challenges']={cid:definition}
    rid=mission['goal']['record_id'];canonical=mission['records'][rid]['content']
    mission['records'][rid]['allowed_sources']=[]
    definition['bindings']['objects']['SECRET']['record_id']=rid
    for h in [host_id,gateway]:
        mission['hosts'][h]['files']['/desk']=source_entry(kind='dir',owner=user,mode='750')
        mission['hosts'][h]['files']['/desk/final-directive.log']=source_entry(canonical,owner=user,mode='640',record_id=rid,display_key='IN2_M24_AUDIT')
        mission['records'][rid]['allowed_sources'].append(h+':/desk/final-directive.log')
    mission['goals']=[{'kind':'record_acquired','record_id':rid},{'kind':'sources_preserved'},
        {'kind':'current_boundaries','cases':{
            'web':[{'challenge_id':cid,'case_id':x} for x in ['own_a','foreign_direct','foreign_gateway']],
            'route':[{'challenge_id':cid,'case_id':x} for x in ['route_allowed','route_denied']],
            'service':[{'challenge_id':cid,'case_id':x} for x in ['service_allowed','service_denied']]}}]
    a=login(domain,user,access[mid][1])+[cmd('cat /desk/final-directive.log'),cmd('scp /desk/final-directive.log ~/archive'),action(cid,'inspect')]
    b=login(domain,user,access[mid][1])+[action(cid,'set_control',control_id='direct_open',value=False)]
    b+=login(mission['hosts'][gateway]['domain'],user,access[mid][1])+[cmd('scp /desk/final-directive.log ~/archive'),cmd('exit')]
    for case_id,case in definition['cases'].items():
        # The web's direct threat can be refused by either ownership or closed
        # original ingress. All legitimate work still needs an approved route.
        a.append(action(cid,'probe',case_id=case_id))
        route='gateway' if case['class']=='normal' and 'gateway' in case.get('routes',{}) else None
        b.append(action(cid,'probe',case_id=case_id,**({'route_id':route} if route else {})))
    expected={'completed':True,'sources_preserved':True,'facts':[],'archive_record_ids':[rid],'policies':{},
              'model_outcomes':{cid:{'kind':'current_boundaries','groups':['web','route','service']}}}
    return {'paths':[{'id':'web_relay','name':'Current web, relay and limited service checks','actions':a,'expected':copy.deepcopy(expected)},
                     {'id':'approved_delegation','name':'Approved delegation with the same current boundaries','actions':b,'expected':copy.deepcopy(expected)}],
            'negative_hints':['old_records_are_not_current_boundary_observations','break_one_boundary_does_not_complete']}


def configure_candidate_access(mission,identities,access):
    mid='M17';rid=mission['goal']['record_id'];primary=identities['auditvault'];alternate=identities['custodym17'];vault=identities['proofvault']
    canonical='Verification ledger 17\nReader scope: designated retention sheet only.\nOriginal retained.\n'
    mission['records'][rid]['content']=canonical
    mission['records'][rid]['allowed_sources']=[vault+':/desk/verification.txt',alternate+':/desk/verification.txt']
    for h,owner,group in [(vault,'reader','readers'),(alternate,access[mid][2],'auditors')]:
        mission['hosts'][h]['files']['/desk']=source_entry(kind='dir',owner=owner,group=group,mode='750')
        mission['hosts'][h]['files']['/desk/verification.txt']=source_entry(canonical,owner=owner,group=group,mode='640',record_id=rid,display_key='IN2_M17_AUDIT')
    candidates='APPROVED CANDIDATES\nlumen-71\nlumen-17\nlunar-17\nSHIFT REGISTER\nlabel=lumen\nshift=17\nphrase=label-shift\nVAULT=proofvault.packet.test\nACCOUNT=reader\nSCOPE=verification-sheet\n'
    mission['hosts'][primary]['files']['/desk/candidates.txt']=source_entry(candidates,owner=access[mid][0],display_key='IN2_M17_CONTEXT')
    mission['hosts'][primary]['files'].pop('/desk/audit-bytes.txt',None)
    mission['hosts'][primary]['files'].pop('/desk/target-handoff.note',None)
    mission['challenges']={}
    mission['goals']=[{'kind':'record_acquired','record_id':rid},{'kind':'sources_preserved'}]
    a=login(mission['hosts'][primary]['domain'],access[mid][0],access[mid][1])+[cmd('cat /desk/candidates.txt')]
    a+=login(mission['hosts'][vault]['domain'],'reader','lumen-17')+[cmd('cat /desk/verification.txt'),cmd('scp /desk/verification.txt ~/archive')]
    b=login(mission['hosts'][primary]['domain'],access[mid][0],access[mid][1])+login(mission['hosts'][alternate]['domain'],access[mid][2],access[mid][3])+[cmd('cat /desk/verification.txt'),cmd('scp /desk/verification.txt ~/archive')]
    TEXT['intruder']['ko']['IN2_M17_BRIEF']='승인된 허구 후보 목록과 위임된 감사 경로가 있습니다. 후보를 실제 제한 보관함 인증에서 확인하거나 이미 승인된 좁은 위임으로 같은 검증표를 읽으세요. XOR 단어 복원이나 실제 암호 해시 균열 성능을 보여 주는 사건이 아닙니다.'
    TEXT['intruder']['en']['IN2_M17_BRIEF']='An approved fictional candidate list and a delegated audit route are available. Verify a candidate through actual limited-vault authentication, or read the same sheet through approved narrow delegation. This is neither XOR word recovery nor a benchmark of real password-hash cracking.'
    auth='\n\n'+access[mid][0]+'@'+mission['hosts'][primary]['domain']+' / '+access[mid][1]+'\n'+access[mid][2]+'@'+mission['hosts'][alternate]['domain']+' / '+access[mid][3]+'\n'
    for lang in ['ko','en']:TEXT['intruder'][lang]['IN2_M17_BRIEF']+=auth
    TEXT['intruder']['ko']['IN2_M17_CONTEXT']='교대 인계의 이름·번호 규칙과 승인된 후보를 대조하세요. 후보는 실제 가상 계정 인증과 제한된 파일 권한으로 검증됩니다. 이는 오프라인 암호 해시 균열 알고리즘이 아닙니다.\n\n'+candidates
    TEXT['intruder']['en']['IN2_M17_CONTEXT']='Compare the shift handoff naming convention with the approved candidates. Verify through actual virtual-account authentication and limited file authority. This is not an offline password-hash cracking algorithm.\n\n'+candidates
    TEXT['intruder']['ko']['IN2_M17_AUDIT']='지정된 보존 검증표의 유효한 사본입니다. 실제로 사용한 보관함 또는 위임 경로의 출처를 함께 보존합니다.\n\n'+canonical
    TEXT['intruder']['en']['IN2_M17_AUDIT']='A valid copy of the designated retention sheet. Preserve the provenance of the vault or delegation route actually used.\n\n'+canonical
    for lang in ['ko','en']:
        ko=lang=='ko'
        TEXT['intruder'][lang]['IN2_M17_GOAL']='승인된 후보 인증 또는 좁은 감사 위임으로 지정 검증표만 확보한다.' if ko else 'Recover only the designated verification sheet through an approved candidate or narrow audit delegation.'
        TEXT['intruder'][lang]['IN2_M17_PRINCIPLE']='후보를 아는 것과 그 계정의 자료 범위는 다른 조건입니다. 실제 가상 인증과 파일 접근을 따로 확인합니다.' if ko else 'Knowing a candidate and having authority for its records are separate conditions. Verify actual virtual authentication and file access separately.'
        TEXT['intruder'][lang]['IN2_M17_EXPLAIN']=TEXT['intruder'][lang]['IN2_M17_PRINCIPLE']
        hints=['인계된 후보 규칙과 실제 보관함 계정 범위를 확인하세요.','/desk/candidates.txt의 label·shift 규칙과 보관함 주소를 읽거나 승인된 위임 경로를 사용하세요.','후보의 맞고 틀림은 실제 인증 결과로 확인됩니다. 검증표 외 자료는 필요 없고 XOR 단어는 정답이 아닙니다.'] if ko else ['Check the supplied candidate convention and the vault account scope.','Read the label/shift rule and vault address in /desk/candidates.txt, or use approved delegation.','Actual authentication determines candidate validity. Unrelated records are unnecessary; an XOR word is not the answer.']
        for i,value in enumerate(hints,1):TEXT['intruder'][lang][f'IN2_M17_HINT_{i}']=value
    expected={'completed':True,'sources_preserved':True,'facts':[],'archive_record_ids':[rid],'policies':{}}
    return {'paths':[{'id':'candidate_and_scope','name':'Verify a supplied candidate and actual vault scope','actions':a,'expected':copy.deepcopy(expected)},
                     {'id':'delegated_sheet','name':'Narrow delegated access to the same verification sheet','actions':b,'expected':copy.deepcopy(expected)}],
            'negative_hints':['wrong_candidate_does_not_authenticate','unrelated_sheet_does_not_complete']}


def configure_recovery_response(mission,mid,identities,constants):
    """Two genuinely different recovery states, not two wrappers of one bool."""
    pack='intruder';profile={'M06':'auth','M07':'session','M08':'csrf','M12':'upload','M23':'restoration'}[mid]
    row=next(row for row in constants['STORIES'] if row[0]==mid)
    primary=identities[row[9]];host=mission['hosts'][primary];domain=host['domain'];user,secret=constants['ACCESS'][mid][:2]
    # Old A-only flags no longer define either the condition or the world. This
    # pack's bindings, providers and real outcomes replace those old challenges.
    old_policies=set(mission['policies']);mission['policies']={};mission['challenges']={}
    for h in mission['hosts'].values():
        for service in h['services'].values():
            service['required_policies']={pid:value for pid,value in service.get('required_policies',{}).items() if pid not in old_policies}
    if mid=='M23':host['services'].pop('5050',None)
    for actor,password,groups in [('citizen_a','a-sample',['clients']),('citizen_b','b-sample',['clients']),('outsider','unused-sample',['visitors']),('notifier','ward-sample',['jobs'])]:
        host['accounts'][actor]=account(password,groups)
    cid,definition,policies,gateway=response_definition(pack,mission,primary,domain,user,profile)
    rid=mission['goal']['record_id'];report_source='response:'+cid
    summary={
        'M06':'Repeated invalid authentication is limited or isolated; legitimate client and notification sign-in succeeds.',
        'M07':'Retired authority is refused at exposed and approved providers; fresh legitimate sessions work.',
        'M08':'Authorized form saves succeed; forged origin/nonce and undelegated setting changes are refused.',
        'M12':'Legitimate JPEG intake works; disguised new files are refused and retained untrusted artifacts cannot execute.',
        'M23':'Registered authentication, session, photo and notification workflows work while their modeled threats are refused.',
    }[mid]
    mission['records'][rid]['content']='NIGHT DUTY RESPONSE\n'+summary+'\nOriginal sources retained.\n'
    mission['records'][rid]['allowed_sources']=[report_source]
    mission['records'][rid]['grants_facts']=[]
    definition.update({'record_id':rid,'source':report_source})
    mission['challenges']={cid:definition}
    mission['goals']=[{'kind':'response_matrix','challenge_id':cid,'case_ids':list(definition['cases'])},
                      {'kind':'record_acquired','record_id':rid},{'kind':'sources_preserved'}]
    for h in mission['hosts'].values():
        for file in h['files'].values():
            if file.get('record_id')==rid:file['content']=mission['records'][rid]['content']
    for page in mission['pages'].values():
        if page.get('challenge_id') not in mission['challenges']:
            if 'challenge_id' in page:page['challenge_id']=cid
    mission['pages']['https://'+domain+'/response']={'title':definition['name'],'body':'IN2_'+mid+'_CONTEXT','links':[],
        'host_id':primary,'challenge_id':cid,'requires_session':{'host_id':primary,'account_id':user}}
    mission['pages']['https://'+domain]['links'].append({'label':definition['name'],'url':'https://'+domain+'/response'})
    setup=login(domain,user,secret)+[action(cid,'inspect')];a=list(setup);b=list(setup)
    a_keys={
        'M06':[('retry_limit',True)],'M07':[('session_guard',True)],'M08':[('context_token',True)],
        'M12':[('photo_check',True),('no_execution',True)],
        'M23':[('retry_limit',True),('session_guard',True),('photo_check',True),('no_execution',True)]}[mid]
    for key,value in a_keys:a.append(action(cid,'set_control',control_id=key,value=value))
    if mid in {'M07','M23'}:a.append(action(cid,'revoke',token_ref='old_shift'))
    b.append(action(cid,'set_control',control_id='direct_open',value=False))
    if mid in {'M12','M23'}:b.append(action(cid,'set_control',control_id='no_execution',value=True))
    if mid=='M23':b += [action(cid,'revoke',token_ref='old_shift'),action(cid,'set_control',control_id='standby_open',value=True)]
    for case_id,case in definition['cases'].items():
        a.append(action(cid,'probe',case_id=case_id))
        route='gateway' if case['class']=='normal' and 'gateway' in case.get('routes',{}) else None
        b.append(action(cid,'probe',case_id=case_id,**({'route_id':route} if route else {})))
    exclusive={'M06':'retry_limit','M07':'session_guard','M08':'context_token','M12':'photo_check','M23':'photo_check'}[mid]
    expected={'completed':True,'sources_preserved':True,'facts':[],'archive_record_ids':[rid],
              'model_outcomes':{cid:{'kind':'response_matrix','case_ids':list(definition['cases'])}}}
    expected_a,expected_b=copy.deepcopy(expected),copy.deepcopy(expected)
    expected_a['policies']={policies[key]:value for key,value in a_keys};expected_a['policies'][policies['direct_open']]=True
    expected_b['policies']={policies[exclusive]:False,policies['direct_open']:False,policies['gateway_open']:True}
    if mid in {'M12','M23'}:expected_b['policies'][policies['no_execution']]=True
    if mid=='M23':expected_b['policies'].update({policies['retry_limit']:False,policies['session_guard']:False,policies['standby_open']:True})
    direct_break={'control_id':exclusive,'value':False}
    if mid=='M23':direct_break={'control_id':'photo_check','value':False}
    witness={'challenge_id':cid,'a_only_policy_id':policies[exclusive],'b_expected_a_only_value':False,
        'a_failure':direct_break,'b_failure':{'control_id':'direct_open','value':True},
        'direct_endpoint_domain':domain,'approved_endpoint_domain':mission['hosts'][gateway]['domain'],
        'normal_cases':[case_id for case_id,case in definition['cases'].items() if case['class']=='normal'],
        'threat_cases':[case_id for case_id,case in definition['cases'].items() if case['class']=='threat'],
        'direct_break_case':{'M06':'failed_3','M07':'retired','M08':'forged_direct','M12':'disguised','M23':'disguised'}[mid]}
    goals={
        'M06':('정상 인증 업무를 살리고 원래·승인 인증 경로의 반복 실패를 제한한다.','Preserve legitimate authentication while limiting repeated failures at original and approved providers.'),
        'M07':('옛 세션 권한을 거부하면서 새 세션과 정상 장기 작업을 유지한다.','Refuse retired session authority while preserving fresh sessions and legitimate long-running work.'),
        'M08':('사용자가 의도한 자기 설정 저장은 성공하고 유도·위임 밖 변경은 거부되게 한다.','Allow intentional saves of the user’s own settings while refusing induced and undelegated changes.'),
        'M12':('정상 JPEG 접수는 살리고 위장 새 파일과 보관된 비신뢰 파일의 실행 위험을 막는다.','Preserve legitimate JPEG intake while refusing disguised new files and containing execution risks in retained untrusted uploads.'),
        'M23':('선택한 경로에서 인증·세션·사진·알림 업무를 복구하고 각 위협을 계속 거부한다.','Restore authentication, sessions, photos and notifications on chosen routes while continuing to refuse their modeled threats.'),
    }
    strategies={
        'M06':('기존 인증 서비스의 계정별 제한을 수리하거나, 취약 입구를 닫고 별도 제한을 가진 승인 인증 서비스로 정상 업무를 옮길 수 있습니다. 설정 이름보다 정상 인증 업무와 반복 실패의 실제 응답을 확인하세요.',
               'Repair per-account limits at the existing service, or close its vulnerable entrance and move legitimate work to an independently limited approved provider. Check actual responses to legitimate sign-ins and repeated failures rather than a setting’s name.'),
        'M07':('기존 서비스가 폐기를 검사하도록 하고 노출 키만 폐기하거나, 원래 입구를 닫고 옛 키를 발급하지 않은 승인 인증 서비스로 옮길 수 있습니다. 새 세션·장기 작업이 계속되는지도 확인하세요.',
               'Enable revocation checking and revoke the exposed key, or close the original entrance and migrate to an approved provider that never issued it. Verify that fresh sessions and long-running work continue.'),
        'M08':('원래 폼의 계정별 nonce 검증을 적용하거나, 원래 변경 입구를 닫고 독립된 nonce와 자기 설정 범위를 가진 승인 게이트웨이를 사용할 수 있습니다. 정상 클라이언트의 Origin과 토큰은 처리 서비스마다 다릅니다.',
               'Apply per-account nonce validation at the original form, or close that change entrance and use an approved gateway with independent nonces and own-setting scope. Legitimate Origin and token context differs by provider.'),
        'M12':('원래 처리의 내용 검사·비실행 저장을 고치거나, 취약 입구를 닫고 이미 좁게 검증하는 승인 처리 서비스로 정상 사진을 이관할 수 있습니다. 이전에 보관된 위험 파일도 현재 실행할 수 없도록 해야 합니다.',
               'Repair validation and non-executable storage at the original processor, or close its vulnerable entrance and move legitimate photos to an approved bounded processor. Previously retained unsafe uploads must also be unable to execute now.'),
        'M23':('원래 인증·파일·세션 제어를 정밀 복원하거나, 취약 입구를 닫고 승인 게이트웨이와 대기 알림 경로로 업무를 옮길 수 있습니다. 새 서비스도 종료 권한·위장 파일·범위 밖 목적지를 별도로 거부해야 합니다.',
               'Precisely restore the original authentication, file and session controls, or isolate the vulnerable entrance and migrate work to an approved gateway and standby notifications. The new providers must also refuse retired authority, disguised files and out-of-scope targets.'),
    }
    for lang,index in [('ko',0),('en',1)]:
        source_prefix='IN2_'+mid+'_'
        TEXT[pack][lang][source_prefix+'GOAL']=goals[mid][index]
        TEXT[pack][lang][source_prefix+'CONTEXT']=strategies[mid][index]
        TEXT[pack][lang][source_prefix+'ROUTE']=strategies[mid][index]
        TEXT[pack][lang][source_prefix+'PRINCIPLE']=('누가 어떤 대상에 어떤 업무 권한으로 접근하는지가 중요합니다. 처리 경로를 바꾸면 정상 업무와 거부할 요청을 새 경로에서도 다시 확인하세요.' if lang=='ko' else 'Permission depends on who acts, the target and the work authority. If the processing route changes, verify legitimate work and refused requests on the new route as well.')
        TEXT[pack][lang][source_prefix+'EXPLAIN']=strategies[mid][index]
        TEXT[pack][lang][source_prefix+'AUDIT']=goals[mid][index]+('\n\n정상 업무의 성공과 거부해야 할 요청의 결과를 확인한 대응 인계입니다. 원본 자료도 함께 보존되었습니다.' if lang=='ko' else '\n\nA response handoff based on verified legitimate work and refused requests. Original records were also preserved.')
        TEXT[pack][lang][source_prefix+'ABSTRACTION']=('이 작업대는 허가된 클라이언트와 정해진 업무 요청만 재현합니다. 결과가 입증하는 범위는 보이는 계정·대상·출처·처리 경로에 한정됩니다.' if lang=='ko' else 'This workbench reproduces authorized clients and a defined set of work requests. Results establish only the shown account, target, origin and processing route.')
        TEXT[pack][lang][source_prefix+'LIMIT']=('이 시나리오 밖의 모든 공격을 막는다는 보증이 아닙니다. 각 provider의 현재 조건을 확인한 범위만 인계합니다.' if lang=='ko' else 'This does not establish prevention of every attack outside these scenarios. Hand off only the current provider conditions actually checked.')
        for i,hint in enumerate([goals[mid][index],strategies[mid][index],
            ('원래 입구에서 대응하려면 관련 제어를 고치고, 대안은 원래 입구를 제한한 뒤 정상 요청에 승인 경로를 고르세요. 모든 종료는 정상 업무를 실패시킵니다.' if lang=='ko' else 'For a direct response, repair the relevant control. For the alternative, constrain the original entrance and select the approved route for legitimate requests. Turning everything off fails legitimate work.')],1):
            TEXT[pack][lang][source_prefix+f'HINT_{i}']=hint
        # Keep the plot request, but add the scope of the now-live alternatives.
        TEXT[pack][lang][source_prefix+'BRIEF']+='\n\n'+strategies[mid][index]
    return {'paths':[{'id':'repair_direct_boundary','name':'Precisely repair the original live boundary','actions':a,'expected':expected_a},
                     {'id':'isolate_and_delegate','name':'Isolate the vulnerable ingress and use an approved scoped provider','actions':b,'expected':expected_b}],
            'alternative_witness':witness,'negative_hints':['all_off_fails_normal_work','b_does_not_require_a_exclusive_protection','reopen_vulnerable_direct_breaks_b']},cid


def build_intruder():
    result,constants,maps=copy_intruder_base();raw=read(DATA/'legacy_v1.json');old_fixtures=read(ROOT/'godot/tests/fixtures/campaign_solutions.json')['missions'];fixtures={}
    for mid,mission in result['missions'].items():
        identities=maps[mid]
        proof_hosts=set(constants['ACCESS'].get(mid,('','','','','',''))[4:6])
        paths=[]
        for old_path in old_fixtures[mid]['paths']:
            path=copy.deepcopy(old_path)
            path['actions']=remap(remove_ledger_visits(path['actions'],raw['missions'][mid],proof_hosts),identities)
            path['expected']=remap(path['expected'],identities)
            path['expected']['facts']=[x for x in path['expected'].get('facts',[]) if '_exhibit_' not in x]
            path['expected']['archive_record_ids']=[x for x in path['expected'].get('archive_record_ids',[]) if '_EXHIBIT_' not in x]
            paths.append(path)
        fixtures[mid]={'paths':paths,'negative_hints':['invalid_source_or_payload_does_not_complete','unrelated_state_is_not_a_required_exhibit']}
        if mid!='M01':
            role,secret,other,other_secret=constants['ACCESS'][mid][:4];primary=constants['STORIES'][next(i for i,r in enumerate(constants['STORIES']) if r[0]==mid)][9]
            p_host=mission['hosts'][identities[primary]];b_host=mission['hosts'][identities['custody'+mid.lower()]]
            auth=f'\n\n{role}@{p_host["domain"]} / {secret}\n{other}@{b_host["domain"]} / {other_secret}\n'
            for lang in ['ko','en']:TEXT['intruder'][lang]['IN2_'+mid+'_BRIEF']+=auth
            for i in range(1,4):
                TEXT['intruder']['ko']['IN2_'+mid+f'_HINT_{i}']=[constants['AUTHORED'][mid][2],
                    '현재 actor·대상·경로와 의뢰가 요구하는 결과를 비교하세요. 같은 원장을 다시 회수할 필요는 없습니다.',
                    '접근 경계 실험과 승인된 대안 중 필요한 길을 선택하세요. 힌트나 특정 도구 사용은 완료 조건이 아닙니다.'][i-1]
                TEXT['intruder']['en']['IN2_'+mid+f'_HINT_{i}']=[constants['AUTHORED'][mid][3],
                    'Compare the current actor, target, route and requested outcome. Do not recollect the same ledger.',
                    'Choose the boundary experiment or an approved alternative. Hints and particular tools are not completion requirements.'][i-1]
        if mid in {'M04','M05','M09','M11','M14','M16','M18','M21'}:
            actual=replace_access_alternative(mission,mid,identities,constants['ACCESS'])
            alt=identities[mid.lower()+'_alternate']
            for index,a in enumerate(fixtures[mid]['paths'][1]['actions']):
                if a['kind']=='tool' and a['tool_id']==alt:fixtures[mid]['paths'][1]['actions'][index]=actual
        if mid=='M17':fixtures[mid]=configure_candidate_access(mission,identities,constants['ACCESS'])
        if mid=='R01':
            mission['challenges']={};cid='in2_r01_verifier';a,b=configure_vm(mission,'intruder',cid,record_id=mission['goal']['record_id'])
            mission['challenges'][cid]['fact_id']='in2_r01_verified'
            mission['records'][mission['goal']['record_id']]['allowed_sources']=['vm:'+cid]
            expected={'completed':True,'sources_preserved':True,'facts':[],'archive_record_ids':[],'policies':{},'model_outcomes':{cid:{'kind':'vm_cases','requirements':['normal','counterexample']}}}
            fixtures[mid]={'paths':[{'id':'read_and_counterexample','name':'Inspect control flow and run normal plus counterexample','actions':a,'expected':copy.deepcopy(expected)},
                                   {'id':'differential_trace','name':'Use differential executions and call trace','actions':b,'expected':copy.deepcopy(expected)}],
                           'negative_hints':['case_name_does_not_determine_scope','XOR_word_is_not_a_branch_solution']}
            TEXT['intruder']['ko']['IN2_R01_BRIEF']='작은 배포 검증기의 형식·서명·범위 조건을 확인하세요. 의사코드와 호출 관계를 읽어도 되고 입력쌍과 실행 trace를 비교해도 됩니다. 정상 범위의 허용 예와 범위 밖인데 release되는 반례를 실제 실행으로 확보해야 합니다.'
            TEXT['intruder']['en']['IN2_R01_BRIEF']='Inspect the small verifier’s format, signature and scope conditions. Read its pseudocode and call graph, or compare input pairs and execution traces. Actually execute a permitted normal case and an out-of-scope case that is still released.'
            pseudo='main(document, permit):\n  if not format_ok(document): deny\n  signature = check_signature(document)\n  if signature: release(document)\n  else: deny\ncheck_signature(document):\n  return signature_ok(document)\n# retention_scope is provided but never checked before release\n'
            for host in mission['hosts'].values():
                host['files'].pop('/public/verifier.asm',None)
                for file in host['files'].values():
                    if file.get('display_content_key') in {'IN2_R01_CONTEXT','IN2_R01_ROUTE'}:file['content']=pseudo;file['display_content_key']='IN2_R01_CONTEXT'
            rhost=mission['hosts'][identities['verifier']]
            rhost['files']['/public/verifier.pseudo']=source_entry(pseudo,owner=constants['ACCESS'][mid][0],mode='644',display_key='IN2_R01_CONTEXT')
            for lang in ['ko','en']:
                display_pseudo=pseudo.replace('# retention_scope is provided but never checked before release','# retention_scope 입력은 있지만 release 전에 검사하지 않음') if lang=='ko' else pseudo
                TEXT['intruder'][lang]['IN2_R01_CONTEXT']=TEXT['intruder'][lang]['IN2_R01_BRIEF']+'\n\n'+display_pseudo
                TEXT['intruder'][lang]['IN2_R01_GOAL']=('정상 범위 허용과 범위 밖 release 반례를 실제 분기·호출 실행으로 확보한다.' if lang=='ko' else 'Execute the branches and calls to establish a normal permitted case and an out-of-scope release counterexample.')
                TEXT['intruder'][lang]['IN2_R01_PRINCIPLE']=('형식과 서명 검사 통과가 검사하지 않은 scope의 허가를 뜻하지 않습니다.' if lang=='ko' else 'Passing format and signature checks does not authorize a scope the program never checks.')
                TEXT['intruder'][lang]['IN2_R01_EXPLAIN']=TEXT['intruder'][lang]['IN2_R01_PRINCIPLE']
                hints=['프로그램이 실제 읽는 입력과 호출하는 검사를 따라가세요.','format_ok·signature_ok는 검사하지만 retention_scope가 어디에서 분기하는지 확인하세요.','형식·서명이 참인 상태에서 scope만 authorized/excluded로 바꿔 실행하고 release 출력과 call trace를 비교하세요.'] if lang=='ko' else ['Follow the inputs the program actually reads and the checks it calls.','Locate where retention_scope affects a branch alongside format_ok and signature_ok.','Hold format and signature true, vary authorized/excluded scope, and compare release outputs and the call trace.']
                for i,value in enumerate(hints,1):TEXT['intruder'][lang][f'IN2_R01_HINT_{i}']=value
        if mid=='M24':
            fixtures[mid]=configure_final_boundaries(mission,identities,constants['ACCESS'])
            for lang in ['ko','en']:
                TEXT['intruder'][lang]['IN2_M24_GOAL']=('최종 사본을 보존하고 현재 웹 요청·내부 경로·서비스 자격의 세 경계를 각각 검증한다.' if lang=='ko' else 'Retain the final copy and independently verify current web, internal-route and service-authority boundaries.')
                TEXT['intruder'][lang]['IN2_M24_CONTEXT']=('과거 완료와 원장은 지금의 접근 결과를 대신하지 않습니다. 시민의 자기 접수와 범위 밖 요청, 중계와 공용 노드의 내부 도달, 제한 자격과 다른 자격의 자료 읽기를 같은 현재 세계에서 확인하세요.' if lang=='ko' else 'Past completion and ledgers do not replace current access results. Check own and unrelated web access, internal reachability from relay and public nodes, and limited versus unrelated service credentials in the same current world.')
        if mid in {'M06','M07','M08','M12','M23'}:
            fixtures[mid],_=configure_recovery_response(mission,mid,identities,constants)
        for page in mission['pages'].values():
            if page.get('challenge_id') not in mission['challenges']:
                if mid=='R01':page['challenge_id']='in2_r01_verifier';page.pop('requires_session',None)
                else:page.pop('challenge_id',None)
        for goal in mission['goals']:
            if goal['kind']!='sources_preserved':goal['label_display']=mission['goal_text']
        mission['milestones']=[{'id':'in2_'+mid.lower()+'_brief','title':mission['title'],'text':mission['mail']['intro']['body']},
                               {'id':'in2_'+mid.lower()+'_work','title':mission['title'],'text':mission['goal_text']}]
    result['title']=text('intruder','PACK_TITLE','침투자 · 심야접속','Intruder · Midnight Access')
    for old in raw['endings']:
        ending=copy.deepcopy(old)
        ending['id']='in2_'+ending['id'];ending['title']='IN2_'+ending['title'];ending['text']='IN2_'+ending['text']
        ending['requires_facts']=['in2_'+x for x in old['requires_facts'] if '_exhibit_' not in x and x!='r01_evidence']
        if old['id']=='independent_review':ending['requires_facts'].append('in2_r01_verified')
        result['endings'].append(ending)
    result['contacts']={
        'C01':{'name_key':'IN2_C01_NAME','introduced_by':['M01'],'face_gate':{'when':'completed','mission_id':'M12','explicit':True}},
        'C02':{'name_key':'IN2_C02_NAME','introduced_by':['M02'],'face_gate':{'when':'introduced','mission_id':'M02','explicit':False}},
        'C03':{'name_key':'IN2_C03_NAME','introduced_by':['M09'],'face_gate':{'when':'completed','mission_id':'M16','explicit':True}},
        'C04':{'name_key':'IN2_C04_NAME','introduced_by':['M15'],'face_gate':{'when':'introduced','mission_id':'M15','explicit':False}}}
    return result,fixtures


def validate_packs(packs,fixtures):
    expected={'intruder':28,'defender':8,'tracker':8}
    used_ids=set();used_text=set();legacy_keys=set(read(DATA/'locales/en.json'))
    for pack,definition in packs.items():
        assert len(definition['missions'])==expected[pack]
        assert set(definition['missions'])==set(fixtures[pack]['missions'])
        assert set(TEXT[pack]['ko'])==set(TEXT[pack]['en'])
        assert not set(TEXT[pack]['en'])&legacy_keys
        assert not set(TEXT[pack]['en'])&used_text
        used_text.update(TEXT[pack]['en'])
        pack_ids=set()
        for mid,m in definition['missions'].items():
            for kind in ['hosts','records','policies','challenges']:
                identifiers=set(m[kind]);assert not identifiers&used_ids,(pack,mid,kind)
                pack_ids.update(identifiers)
            assert all(x in m['hosts'] or x=='local' for host in m['hosts'].values() for x in host.get('via',[])),(pack,mid,'route')
            for hid,host in m['hosts'].items():
                for user,details in host['accounts'].items():assert details['home'] in host['files'] and host['files'][details['home']]['kind']=='dir',(pack,mid,hid,user,'home')
            assert len(fixtures[pack]['missions'][mid]['paths'])==2,(pack,mid)
            for cid,ch in m['challenges'].items():
                if 'requires_session' in ch:
                    ref=ch['requires_session'];assert ref['account_id'] in m['hosts'][ref['host_id']]['accounts'],(pack,mid,cid,'actor')
                if ch['kind']=='response_lab':
                    assert ch['cases'],(pack,mid,'empty response matrix')
                    for case in ch['cases'].values():
                        ref=case['actor_ref'];assert ref['account_id'] in m['hosts'][ref['host_id']]['accounts'],(pack,mid,'probe actor')
                    for ep in ch['bindings']['endpoints'].values():assert ep['host_id'] in m['hosts'],(pack,mid,'endpoint')
                if ch['kind']=='observation_case':
                    for sid,sensor in ch['sensors'].items():
                        assert sensor['host_id'] in m['hosts'] and sensor['windows'],(pack,mid,sid)
                        if sensor['visibility']=='metadata':
                            assert not any(key in row['public'] for window in sensor['windows'] for row in window['rows'] for key in ['plaintext','payload','body','authorized_excerpt']),(pack,mid,sid,'metadata payload leak')
            for goal in m['goals']:
                assert '_exhibit_' not in str(goal.get('id','')).lower() and '_exhibit_' not in str(goal.get('record_id','')).lower(),(pack,mid,'repeated exhibit goal')
            for path in fixtures[pack]['missions'][mid]['paths']:
                assert path['actions'] and path['expected']['completed'] and path['expected']['sources_preserved'],(pack,mid,path['id'])
        used_ids.update(pack_ids)
    assert packs['intruder']['missions']['R01']['goals'][0]['kind']=='vm_cases'
    assert any(g['kind']=='current_boundaries' for g in packs['intruder']['missions']['M24']['goals'])


def build():
    preserved={str(p):digest(p) for p in PRESERVED}
    assert preserved[str(DATA/'legacy_v1.json')].startswith('51699e38'), 'Unexpected preserved legacy definition'
    packs,fixtures={},{}
    packs['intruder'],intruder=build_intruder()
    packs['defender'],defender=build_defender()
    packs['tracker'],tracker=build_tracker()
    fixtures={'intruder':{'missions':intruder},'defender':{'missions':defender},'tracker':{'missions':tracker}}
    for pack,definition in packs.items():
        for mission in definition['missions'].values():
            for goal in mission['goals']:
                if goal['kind']!='sources_preserved':
                    goal['label_display']=mission.get('goal_text',mission['title'])
                    goal['target_display']=mission['initial_web_url']
    validate_packs(packs,fixtures)
    stats={}
    for pack,definition in packs.items():
        keys=write_pack(pack,definition)
        stats[pack]={'missions':len(definition['missions']),'locale_keys':keys,
                     'solution_paths':sum(len(m['paths']) for m in fixtures[pack]['missions'].values()),
                     'challenge_kinds':sorted({c['kind'] for m in definition['missions'].values() for c in m['challenges'].values()})}
    write(ROOT/'godot/tests/fixtures/perspectives_solutions.json',{'schema_version':1,'packs':fixtures})
    assert preserved=={str(p):digest(p) for p in PRESERVED},'Preserved inputs changed'
    print(json.dumps({'generated':stats,'preserved_sha256':preserved,'scope':'authored structure; runtime and human acceptance remain separate'},ensure_ascii=False,indent=2))


if __name__=='__main__':
    build()
