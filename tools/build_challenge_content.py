#!/usr/bin/env python3
"""Author the independent three-case challenge pack using existing bounded models."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESERVED_INPUTS = [ROOT / "godot/data/campaign/packs" / name for name in
                    ["intruder_v2.json", "defender_v1.json", "tracker_v1.json"]]
PRESERVED_INPUTS += [ROOT / "godot/data/campaign/locales" / (stem + "." + loc + ".json")
                     for stem in ["intruder_v2", "defender_v1", "tracker_v1"] for loc in ["ko", "en"]]
PRESERVED_INPUTS += [ROOT / "godot/tests/fixtures/perspectives_solutions.json", ROOT / "tools/build_expansion_content.py"]


def preserved_hashes():
    return {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in PRESERVED_INPUTS}


# Guard inputs before importing the existing authoring helpers as well as after generation.
PRESERVED_BEFORE_IMPORT = preserved_hashes()
import build_expansion_content as base
assert preserved_hashes() == PRESERVED_BEFORE_IMPORT, "Authoring helper import changed original content"

PACK = "challenge"
base.PREFIX[PACK] = "CH1_"
base.TEXT[PACK] = {"ko": {}, "en": {}}


def text(suffix, ko, en):
    return base.text(PACK, suffix, ko, en)


def scenario(mid, name, ko, en, host, account, request, statuses, *, business=None, value=True, routes=None):
    result = {"label": text(mid + "_CASE_" + name.upper(), ko, en), "class": "normal" if value else "threat",
              "actor_ref": {"host_id": host, "account_id": account}, "request": request,
              "expect": {"statuses": statuses}}
    if business:
        result["expect"].update({"business_key": business, "value": value})
    if routes:
        result["routes"] = routes
    return result


def request(domain, path, method="GET", body=None):
    return {"method": method, "url": "https://" + domain + path, "body": body or {}, "headers": {}}


def control(mid, name, policy_id, ko, en, group="security"):
    return {"policy_id": policy_id, "values": [False, True], "group": group,
            "label": text(mid + "_CONTROL_" + name.upper(), ko, en)}


def shell(mid, ko, en, brief_ko, brief_en, reply_ko, reply_en):
    return base.mission_shell(PACK, mid, ko, en, "야간 합동 대응실", "Joint Night Response Desk",
                              brief_ko, brief_en, reply_ko, reply_en)


def guidance(mission, goal, hints, principle):
    base.add_guidance(PACK, mission, *goal, hints, principle,
        ("등록된 계정·요청·파일·관측으로 작동하는 독립 도전입니다. 다른 유효한 해법과 수동 도움도 사용할 수 있습니다.",
         "This independent challenge uses registered accounts, requests, files and observations. Other valid solutions and manual help remain available."),
        ("실제 서버 침투나 모든 공격에 대한 안전 보증이 아닙니다. 읽는 시간에는 벌점이 없고 잘못된 설정은 다시 고칠 수 있습니다.",
         "This does not attack real servers or establish protection against every attack. Reading has no time penalty, and mistaken settings can be repaired."))


def response_paths(mission, cid, setup, a, b, policies_a, policies_b, *, remote_a=None, remote_b=None):
    definition = mission["challenges"][cid]
    expected = {"completed": True, "sources_preserved": True, "facts": [], "archive_record_ids": [], "policies": {},
                "model_outcomes": {cid: {"kind": "response_matrix", "case_ids": list(definition["cases"])}}}
    paths = []
    for pid, actions, policy, remote in [("precise_repair", a, policies_a, remote_a),
                                         ("approved_migration", b, policies_b, remote_b)]:
        checks = copy.deepcopy(expected)
        checks["policies"] = policy
        if remote:
            checks["remote_files"] = remote
        paths.append({"id": pid, "name": pid.replace("_", " "), "actions": setup + actions, "expected": checks})
    return {"paths": paths, "negative_hints": ["all_services_off_does_not_complete", "normal_and_threat_outcomes_both_required", "stale_receipts_do_not_complete"],
            "negative_controls": {"all_services_off": {"controls": [k for k in definition["controls"] if k.endswith("open")]},
                                  "current_basis": {"challenge_id": cid, "normal_case_ids": [k for k,c in definition["cases"].items() if c["class"] == "normal"]}}}


def build_x01():
    mid = "X01"
    mission, host, domain, user, secret = shell(mid, "열려 있어야 하는 문", "A Door That Must Stay Open",
        "합동 대응 훈련의 첫 의뢰입니다. 민원 접수 기록이 다른 계정에 노출됐고 같은 입구에서는 인증 실패도 반복됩니다. 입구 전체를 끄면 시민의 정상 접수도 사라집니다. 정상 접수와 실패 제한을 한 설정에서 함께 확인해 주세요.\n\n직접 경로는 소유자 검사와 계정별 제한을 따로 고쳐야 합니다. 승인 중계는 고정된 위임 범위와 자체 인증 제한을 갖고 있어 정상 업무를 옮길 수도 있습니다. 반복 실패 표본을 확인하고 최종 표본에서 제한 응답이 나오는지 보세요. 이미 조사한 계정은 앞선 표본부터 제한될 수도 있습니다. 다른 시민의 정상 인증은 계속 가능해야 합니다.",
        "This is the first joint-response exercise. Receipt records are exposed to unrelated accounts, while sign-in failures repeat at the same entrance. Closing every entrance also removes legitimate citizen work. Verify receipt access and failed-attempt limits together under one configuration.\n\nThe original route needs separate ownership and per-account retry controls. The approved gateway has fixed delegation scopes and its own retry limit, so legitimate work may be migrated there instead. Observe the repeated-failure samples and verify a limiting response on the final sample. An account already tested may be limited on an earlier sample too. Another citizen must still be able to sign in.",
        "정상 시민과 담당자의 접수는 유지되고 무관한 열람과 반복 인증은 거부됐습니다. 어떤 입구를 택했는지보다 실제 업무가 남았다는 점이 인계 기준입니다. 다음 현장은 배포 권한을 넓히자는 제안으로 시끄럽습니다.",
        "Legitimate citizen and staff work remains, while unrelated reads and repeated sign-ins are refused. The handoff records that real work survived, whichever entrance you chose. The next site proposes widening deployment permissions.")
    cid, model, p, gate = base.response_definition(PACK, mission, host, domain, user, "objects")
    gate_domain = mission["hosts"][gate]["domain"]
    model["controls"]["retry_limit"] = control(mid, "AUTH_RETRY", p["retry_limit"], "계정별 반복 인증 제한", "Limit Repeated Sign-ins per Account")
    safe = "ch1_x01_gateway_rate"
    mission["policies"][safe] = True
    for name, hid, policy in [("login", host, p["retry_limit"]), ("gateway_login", gate, safe)]:
        model["bindings"]["endpoints"][name] = {"host_id": hid, "method": "POST", "path_prefix": "/sign-in", "operation": "auth_login", "rate_policy": policy, "limit": 2, "cooldown": 2}
    for number in range(1, 4):
        for gateway in [False, True]:
            name = ("gateway_" if gateway else "") + "failed_" + str(number)
            actor = "outsider" if gateway else "citizen_a"
            url_domain = gate_domain if gateway else domain
            statuses = [401, 429] if number < 3 else [429]
            if not gateway:
                statuses += [503]
            model["cases"][name] = scenario(mid, name, ("승인 경로 " if gateway else "원래 입구 ") + f"반복 실패 {number}",
                ("Gateway " if gateway else "Original entrance ") + f"repeated failure {number}", host, actor,
                request(url_domain, "/sign-in", "POST", {"username": actor, "password": "incorrect"}), statuses,
                business="auth:" + actor + ":login", value=False)
    model["cases"]["legitimate"] = scenario(mid, "legitimate", "다른 시민의 정상 인증", "Another Citizen's Valid Sign-in", host, "citizen_b",
        request(domain, "/sign-in", "POST", {"username": "citizen_b", "password": "b-sample"}), [200],
        business="auth:citizen_b:login", routes={"gateway": request(gate_domain, "/sign-in", "POST", {"username": "citizen_b", "password": "b-sample"})})
    model["checkpoint_groups"]["security"].append("retry_limit")
    mission["challenges"][cid] = model
    mission["goals"].insert(0, {"kind": "response_matrix", "challenge_id": cid, "case_ids": list(model["cases"])})
    guidance(mission, ("정상 접수·담당자 열람·정상 인증을 유지하고 직접/중계의 비인가 열람과 반복 실패를 제한한다.",
        "Preserve legitimate receipt access, staff work and sign-in while limiting unauthorized reads and repeated failures on both routes."),
        [("직접 입구의 소유권 검사와 인증 제한은 다른 제어입니다. 하나만 고쳐서는 모든 결과가 맞지 않습니다.", "Ownership and retry limits are separate controls. Fixing only one cannot satisfy every outcome."),
         ("각 입구의 실패 표본은 모두 거부되고 최종 표본은 제한돼야 합니다. 앞선 조사로 이미 제한된 계정도 유효한 거부입니다. 정상 인증에는 다른 계정을 사용합니다.", "Failure samples at each entrance must be refused, with the final sample limited. Earlier limiting caused by your investigation is also a valid refusal. Legitimate sign-in uses a different account."),
         ("직접 입구를 수리하거나 그 입구만 닫고 정상 접수·인증을 승인 중계로 옮기세요. 중계는 열려 있어야 합니다.", "Repair the original entrance, or close only that entrance and migrate legitimate receipt/sign-in work to the approved gateway. Keep the gateway open.")],
        ("서비스 가용성과 권한 범위는 함께 검증해야 합니다. 실패 제한은 개별 인증 결과이며 전역 경보 수치와 다릅니다.", "Availability and authorization scope must be checked together. Retry limiting is an authentication outcome, distinct from the global alert indicator."))
    a = [base.action(cid, "set_control", control_id="owner_check", value=True), base.action(cid, "set_control", control_id="retry_limit", value=True)]
    b = [base.action(cid, "set_control", control_id="direct_open", value=False)]
    for name, case in model["cases"].items():
        a.append(base.action(cid, "probe", case_id=name))
        alt = {"route_id": "gateway"} if case["class"] == "normal" and "gateway" in case.get("routes", {}) else {}
        b.append(base.action(cid, "probe", case_id=name, **alt))
    return mission, response_paths(mission, cid, base.login(domain, user, secret), a, b,
        {p["owner_check"]: True, p["retry_limit"]: True}, {p["direct_open"]: False})


def build_x02():
    mid = "X02"
    mission, host, domain, user, secret = shell(mid, "살려야 할 배포", "Keep the Deployment Working",
        "배포 계정이 상태 파일을 갱신하지 못해 야간 안내가 멈췄습니다. 폴더와 파일을 모두에게 열자는 제안이 있지만 같은 입구에 비담당 계정도 있습니다. 정상 읽기·쓰기와 통지, 비담당 쓰기 거부를 모두 확인해 주세요.\n\n원래 폴더는 deploy 그룹만 탐색하고 파일은 해당 그룹만 쓸 수 있습니다. 배포 계정의 현재 그룹을 확인하거나, jobs 그룹이 이미 접근할 수 있는 승인 작업대를 사용하세요. 통지의 목적지는 ward뿐이며 직접 통지는 현재 꺼져 있고 승인 대기 통지는 별도로 켤 수 있습니다.",
        "The deployment account cannot update its status file, so the night notice has stopped. A proposal would open both folder and file to everyone, including unrelated accounts at the same entrance. Verify legitimate reads, writes and notification delivery alongside refusal of unrelated writes.\n\nOnly the deploy group can traverse the original folder and write its file. Check the worker's groups, or use the approved workbench already available to jobs. Notifications may target only ward. Primary notification delivery is currently off; the approved standby can be enabled separately.",
        "허용된 작업 결과가 실제 파일에 남고 ward 안내도 전달됐습니다. 비담당 쓰기와 내부 목적지 오용은 거부됐습니다. 마지막 인계에서는 같은 주소를 같은 세션으로 보았던 추정부터 확인해야 합니다.",
        "The permitted work result exists in a real virtual file and the ward notice was delivered. Unrelated writes and internal-target misuse were refused. The final handoff begins by checking an assumption that one address meant one session.")
    cid, model, p, gate = base.response_definition(PACK, mission, host, domain, user, "vfs")
    gate_domain = mission["hosts"][gate]["domain"]
    mission["policies"].update({p["notify_open"]: False, p["standby_open"]: False, p["target_scope"]: False})
    for name, ko, en, group in [("notify_open", "주 통지 경로 열기", "Enable Primary Notification", "availability"), ("standby_open", "승인 대기 통지 열기", "Enable Approved Standby Notification", "availability"), ("target_scope", "ward 통지 범위 제한", "Constrain Notifications to ward", "security")]:
        if name == "notify_open": ko = "주 통지 경로 열기"
        model["controls"][name] = control(mid, "NOTICE_" + name, p[name], ko, en, group)
    for name, hid, enabled in [("notify", host, p["notify_open"]), ("standby_notify", gate, p["standby_open"])]:
        model["bindings"]["endpoints"][name] = {"host_id": hid, "method": "POST", "path_prefix": "/notify", "operation": "notify_send", "enabled_policy": enabled, "allowed_targets": ["ward"], "allowlist_policy": p["target_scope"]}
    for endpoint in model["bindings"]["endpoints"].values():
        if endpoint["operation"] == "vfs_write":
            endpoint["current_content"] = True
    model["cases"]["notify"] = scenario(mid, "notify", "ward 정상 통지", "Legitimate ward Notification", host, "notifier",
        request(domain, "/notify", "POST", {"target": "ward"}), [200, 202], business="notify:ward:delivered",
        routes={"gateway": request(gate_domain, "/notify", "POST", {"target": "ward"})})
    for name, dom in [("internal_target", domain), ("standby_target", gate_domain)]:
        model["cases"][name] = scenario(mid, name, "범위 밖 통지 대상: " + dom, "Out-of-scope Notification Target: " + dom, host, "notifier",
            request(dom, "/notify", "POST", {"target": "internal-secrets"}), [403, 503], business="notify:internal-secrets:delivered", value=False)
    model["checkpoint_groups"].update({"availability": ["notify_open", "standby_open"], "security": ["target_scope"]})
    mission["challenges"][cid] = model
    mission["goals"].insert(0, {"kind": "response_matrix", "challenge_id": cid, "case_ids": list(model["cases"])})
    guidance(mission, ("정상 상태 읽기·쓰기와 ward 통지를 살리고 비담당 파일 변경 및 범위 밖 통지를 거부한다.", "Restore legitimate status reads/writes and ward delivery while refusing unrelated modifications and out-of-scope notifications."),
        [("폴더 탐색과 파일 쓰기는 다른 권한입니다. 모든 사용자에게 여는 대신 현재 서비스 계정의 그룹을 확인하세요.", "Folder traversal and file writing are separate permissions. Check the service account's groups instead of opening access to everyone."),
         ("원래 파일의 권한을 유지하고 deploy 그룹을 부여하거나 승인 작업대의 파일로 업무를 옮길 수 있습니다.", "Keep original permissions and assign deploy membership, or migrate the job to the approved workbench file."),
         ("허용된 ward 통지와 거부할 내부 목적지를 각각 관찰하세요. 사용한 통지 경로를 닫으면 과거 성공만으로는 완료되지 않습니다.", "Observe allowed ward delivery and refused internal targets separately. Closing the route you used invalidates an earlier success.")],
        ("최소 권한과 정상 업무의 지속을 함께 확인합니다. 승인된 대체 파일·통지 경로도 실제 동작하면 유효합니다.", "Least privilege and continued business work must hold together. Approved alternative file and delivery routes are valid when they actually work."))
    a = [base.action(cid, "set_control", control_id="job_groups", value=["jobs", "deploy"]), base.action(cid, "set_control", control_id="target_scope", value=True), base.action(cid, "set_control", control_id="notify_open", value=True)]
    b = [base.action(cid, "set_control", control_id="target_scope", value=True), base.action(cid, "set_control", control_id="standby_open", value=True)]
    for name, case in model["cases"].items():
        a.append(base.action(cid, "probe", case_id=name))
        alt = {"route_id": "gateway"} if case["class"] == "normal" and "gateway" in case.get("routes", {}) else {}
        b.append(base.action(cid, "probe", case_id=name, **alt))
    ra = {host: {"/deploy/status.txt": {"content": "DEPLOYMENT READY\n"}}}
    rb = {gate: {"/approved/status.txt": {"content": "DEPLOYMENT READY\n"}}}
    return mission, response_paths(mission, cid, base.login(domain, user, secret), a, b,
        {p["target_scope"]: True, p["notify_open"]: True}, {p["target_scope"]: True, p["standby_open"]: True}, remote_a=ra, remote_b=rb)


def build_x03():
    mid = "X03"
    mission, host, domain, user, secret = shell(mid, "같은 주소의 다른 세션", "Different Sessions at One Address",
        "같은 중계 주소와 같은 이름표가 두 기록에 나타나니 같은 세션이라는 선행 보고가 왔습니다. 그러나 이름표는 클라이언트가 붙였고 출처별 시계도 다릅니다. 세션을 사람의 신원으로 확대하지 말고, 다음 조사 지점을 정할 수 있는 연결과 반례를 인계해 주세요.\n\n현장 센서의 첫 창은 공유 주소와 클라이언트가 주장한 같은 night-worker 이름표만 보입니다. 최신 현장 창에는 회전 기록만, 수신 서버에는 출발과 다른 세션 기록만 있으므로 함께 조사하세요. 독립 감사 내보내기는 아래의 별도 감사 계정으로 접속하면 사용할 수 있습니다. 서버 발급 S1·S2, 시계 오차를 보정한 회전/출발 순서, N03의 vault 전달을 확인해야 합니다. vault 관측과 공유 주소 관측 중 실제 전달 경로를 따라 다음 지점을 고르세요.\n\n별도 감사 계정\n\nauditor@x03.challenge.packet.test\naudit-custody\n",
        "A preliminary report treats two records at one relay address with matching client labels as one session. Those labels were supplied by clients, and the source clocks differ. Do not turn a session inference into a person's identity: hand off a supported connection and counterevidence that identify the next observation point.\n\nThe first field window contains only a shared address and the same client-claimed night-worker label. The latest field window has only rotation; receiver records have departure and the other session, so investigate them together. The independent audit export requires the separate auditor account below. Check server-issued S1/S2, rotation-before-departure after clock correction, and N03 forwarding to vault. Choose between vault and shared-address observation by following the actual route.\n\nSeparate auditor account\n\nauditor@x03.challenge.packet.test\naudit-custody\n",
        "선행 동일 세션 추정은 서버 발급 기록으로 반박됐고, 시각 순서와 vault 전달이 출처 있는 관측으로 지원됐습니다. 사람의 신원을 단정하지 않은 채 다음 조사 범위를 좁혔습니다. 세 의뢰의 인계가 완료됐습니다.",
        "Server-issued records refuted the preliminary same-session claim. Sourced observations supported the time order and forwarding to vault. The next investigation is narrower without asserting a person's identity. The three-case handoff is complete.")
    mission["hosts"][host]["accounts"]["auditor"] = base.account("audit-custody", ["staff", "audit"])
    cid = "ch1_x03_observations"
    name = text(mid + "_TOOL_NAME", "합동 관측과 반례 인계", "Joint Observations and Counterevidence")
    def row(event, interval, public, source, *, offset=(0,0), authority="server_issued", vantage="edge"):
        return base.observed(event, interval, public, source, offset=offset, authority=authority, vantage=vantage)
    untrusted = [row("CLIENT_A", [100, 110], {"session_tag": "S1", "shared_address": "10.63.9.8", "claimed_account": "night-worker"}, "field-client", authority="client_supplied"),
                 row("CLIENT_B", [100, 110], {"session_tag": "S2", "shared_address": "10.63.9.8", "claimed_account": "night-worker"}, "field-client", authority="client_supplied")]
    def evidence(source, offset, vantage):
        shift = offset[0]
        return [row("ROTATE", [100+shift,102+shift], {"session_tag":"S1","shared_address":"10.63.9.8","event":"rotation"}, source+":rotation", offset=offset,vantage=vantage),
                row("DEPART", [110+shift,112+shift], {"session_tag":"S1","request_tag":"N03","from_node":"edge","to_node":"vault"}, source+":departure",offset=offset,vantage=vantage),
                row("OTHER", [110+shift,112+shift], {"session_tag":"S2","shared_address":"10.63.9.8"}, source+":other-session",offset=offset,vantage=vantage)]
    sensors = {}
    def sensor(suffix, ko, en, windows, *, sampling="complete"):
        sid = "ch1_x03_" + suffix
        sensors[sid] = {"label":text(mid+"_SENSOR_"+suffix.upper(),ko,en),"host_id":host,"visibility":"metadata","coverage":{"sampling":sampling,"window":[90,145]},"windows":[{"rows":r} for r in windows],"requires_session":{"host_id":host,"account_id":user}}
        return sid
    field = sensor("field","현장 기록의 관측 창","Field Record Windows",[untrusted,evidence("edge-custody",(30,30),"edge")[:1]])
    # The alternative is a separately acquired receiver-side export, not renamed copies of the same custody source.
    audit = sensor("audit","승인된 수신 감사 내보내기","Approved Receiver Audit Export",[evidence("receiver-authorized-export",(-5,-5),"vault")])
    receiver = sensor("receiver","수신 서버 인계 기록","Receiver Handoff Records",[evidence("receiver-live-custody",(-5,-5),"vault")[1:]])
    sensors[audit]["requires_session"] = {"host_id": host, "account_id": "auditor"}
    next_sensor = sensor("vault_watch","vault의 다음 관측","Next Observation at vault",[[]],sampling="sampled")
    wrong = sensor("address_watch","공유 주소의 다음 관측","Next Observation at Shared Address",[[]],sampling="sampled")
    base.TEXT[PACK]["ko"][sensors[field]["label"]] = "현장 기록의 관측 창"
    prior = text(mid+"_PRIOR","공유 주소가 같으니 같은 세션이라는 선행 추정","Preliminary Same-session Inference from a Shared Address")
    requirements = {"supported":[{"kind":"before","left":"event:ROTATE","right":"event:DEPART"},{"kind":"forwarded_to","request_tag":"N03","target_node":"vault"}],"refuted":["prior"],"next_vantage":[next_sensor],"allow_identity_unknown":True}
    mission["challenges"][cid] = {"kind":"observation_case","name":name,"sensors":sensors,"claim_types":["same_session","before","forwarded_to"],"initial_claims":{"prior":{"label":prior,"claim":{"kind":"same_session","left":"session:S1","right":"session:S2"},"source_id":"joint-preliminary-notes"}},"handoff_requirements":requirements}
    mission["goals"].insert(0,{"kind":"observation_handoff","challenge_id":cid})
    guidance(mission,("초기 동일 세션 추정을 반박하고 회전→출발 순서와 vault 전달을 입증해 다음 관측점을 인계한다.","Refute the preliminary same-session inference, support rotation-before-departure and forwarding to vault, and hand off the next observation point."),
        [("공유 주소와 클라이언트 표식은 서버가 발급한 세션 식별자와 다릅니다. 출처와 marker authority를 보세요.","A shared address and client label are not server-issued session identifiers. Check provenance and marker authority."),
         ("현장 회전 시각 130~132와 수신 출발 시각 105~107을 그대로 비교하면 순서를 거꾸로 읽게 됩니다. 각각의 시계 오차를 빼서 구간을 비교하세요.","Comparing field rotation at130–132 with receiver departure at105–107 directly reverses their order. Subtract each source clock offset before comparing the intervals."),
         ("현장 최신 창과 수신 기록을 함께 사용하거나, auditor 계정으로 접속해 독립 감사 내보내기를 이용할 수 있습니다. before와 forwarded_to를 지원하고 초기 same_session 반례를 모은 뒤 vault 관측으로 인계하세요.","Use the current field window together with receiver records, or connect as auditor for the independent audit export. Support before and forwarded_to, collect counterevidence to the initial same_session claim, and hand off to vault observation.")],
        ("관측 출처·시계 범위·서버 발급 표식으로 연결을 평가합니다. 공유 IP만으로 동일 세션이나 사람을 단정하지 않습니다.","Evaluate connections using custody sources, clock intervals and server-issued markers. A shared IP alone establishes neither one session nor one person."))
    setup = base.login(domain,user,secret)
    claims = [{"kind":"before","left":"event:ROTATE","right":"event:DEPART"},{"kind":"forwarded_to","left":"request:N03","right":"node:vault"}]
    a = [base.action(cid,"collect",sensor_id=field),base.action(cid,"advance_watch",sensor_id=field),base.action(cid,"collect",sensor_id=field),base.action(cid,"collect",sensor_id=receiver)]
    citations = [field+":1:ROTATE"]+[receiver+":0:"+id for id in ["DEPART","OTHER"]]
    for index,claim in enumerate(claims):
        a += [base.action(cid,"hypothesize",hypothesis_id="supported_"+str(index+1),claim=claim,observation_ids=citations),base.action(cid,"test",hypothesis_id="supported_"+str(index+1))]
    a.append(base.action(cid,"handoff",supported_hypothesis_ids=["supported_1","supported_2"],next_sensor_id=next_sensor))
    b = base.login(domain,"auditor","audit-custody") + [base.action(cid,"collect",sensor_id=audit),base.action(cid,"handoff",claims=[{**c,"observation_ids":[audit+":0:"+id for id in ["ROTATE","DEPART","OTHER"]]} for c in claims],supported_hypothesis_ids=[],next_sensor_id=next_sensor)]
    expected = {"completed":True,"sources_preserved":True,"facts":[],"archive_record_ids":[],"policies":{},"model_outcomes":{cid:{"kind":"observation_handoff","supported":requirements["supported"],"refuted_initial_claims":["prior"],"next_sensor_id":next_sensor}}}
    fixture = {"paths":[{"id":"field_corroboration","name":"Field windows and receiver custody","actions":setup+a,"expected":copy.deepcopy(expected)}, {"id":"independent_audit","name":"Independent receiver-side audit handoff","actions":setup+b,"expected":copy.deepcopy(expected)}],"negative_hints":["shared_address_is_not_identity","uncollected_observation_cannot_support_claim","unknown_only_cannot_complete"],"negative_controls":{"wrong_next_sensor":wrong,"client_only_sensor":field,"required_initial_refutation":"prior"}}
    return mission,fixture


def used_keys(value):
    result=set()
    if isinstance(value,dict):
        for item in value.values():result |= used_keys(item)
    elif isinstance(value,list):
        for item in value:result |= used_keys(item)
    elif isinstance(value,str) and value in base.TEXT[PACK]["en"]:
        result.add(value)
    return result


def build():
    base.TEXT[PACK] = {"ko":{},"en":{}}
    before = preserved_hashes()
    assert before == PRESERVED_BEFORE_IMPORT, "Original inputs changed since helper import"
    missions,fixtures={},{}
    for builder in [build_x01,build_x02,build_x03]:
        m,f=builder();missions[m['mission_id']]=m;fixtures[m['mission_id']]=f
    title=text('PACK_TITLE','종합 도전 · 세 갈래 인계','Joint Challenge · Three Handoffs')
    summary=text('PACK_SUMMARY','접근 통제·배포 복구·추적 반례를 복합 제약으로 해결하는 독립 3사건.','Three independent advanced cases combining access control, deployment recovery and counterevidence.')
    ending=text('ENDING_TITLE','검증된 합동 인계','Verified Joint Handoff')
    definition={'schema_version':1,'content_version':1,'campaign_id':'midnight_challenge','title':title,'summary':summary,'start_mission':'X01','mission_order':list(missions),'missions':missions,'endings':[{'id':'ch1_handoff','title':ending,'text':missions['X03']['mail']['complete']['body'],'requires_facts':[]}], 'contacts':{'C02':{'name_key':missions['X01']['mail']['intro']['sender'],'introduced_by':['X01'],'face_gate':{'when':'introduced','mission_id':'X01','explicit':False}}}}
    for mid,m in missions.items():
        for g in m['goals']:
            if g['kind']!='sources_preserved':g.update({'label_display':m['goal_text'],'target_display':m['initial_web_url']})
        m['pages'][m['initial_web_url']]['links']=[{'label':m['goal_text'],'url':m['initial_web_url']+'/scope'}]
        m['pages'][m['initial_web_url']+'/scope']={'title':m['title'],'body':m['principle'],'links':[]}
    keys=used_keys(definition);assert title in keys and summary in keys
    base.write(ROOT/'godot/data/campaign/packs/challenge_v1.json',definition)
    for loc in ['ko','en']:
        base.write(ROOT/f'godot/data/campaign/locales/challenge_v1.{loc}.json',{k:base.TEXT[PACK][loc][k] for k in sorted(keys)})
    base.write(ROOT/'godot/tests/fixtures/challenge_solutions.json',{'packs':{'challenge':{'missions':fixtures,'endings':{'ch1_handoff':{'requires_completed':['X01','X02','X03']}}}}})
    assert before == preserved_hashes(),'Existing campaign inputs changed'
    assert len(missions)==3 and sum(len(v['paths']) for v in fixtures.values())==6
    print(json.dumps({'pack':'challenge','cases':3,'routes':6,'locale_keys':len(keys),'preserved_files':len(before)}))


if __name__ == '__main__':
    build()
