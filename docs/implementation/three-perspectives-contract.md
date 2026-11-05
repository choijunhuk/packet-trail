# 세 관점 캠페인 구현 계약 v1

기준: `0565166`, `feat/three-perspectives`, `/Users/choi/Documents/packet-trail-expansion`.
이 문서는 [후속 방향](../FUTURE_CAMPAIGNS.md), [최근 감사](../reviews/CLAUDE_FULL_AUDIT_20261105.md), [재설계 브리프](campaign-redesign-brief.md)를 실제 파일·입력·상태·판정 계약으로 좁힌다. 구현/검증 완료 선언은 아니다.

## 1. 이번 결정

- 공개 캠페인은 `intruder` 메인24+선택4, `defender` D01~D08, `tracker` T01~T08이다. 각각 온보딩·전개·자기 결말을 가지며 타편 진도로 잠그지 않는다.
- 기존28사건은 `legacy_intruder`로 보존한다. 새 메뉴의 네 번째 신규편이 아니라 유효한 이전 저장이 있을 때 보이는 ‘이전판 계속’이다.
- 개선 침투에서는66개 공통 필수 exhibit를 제거/선택화한다. M24는 현재 웹·도달 경로·서비스 scope를 각각 검증하고 R01은 분기/호출 모형으로 바꾼다.
- 엔진·4터미널·가상 VFS/HTTP·기존 모형·TranslationServer·Store를 재사용한다. 새 런타임 의존성, 실제 OS/외부 네트워크, 범용 이벤트 엔진을 추가하지 않는다.
- UI는 역할별 구조화 조작면이다. terminal/request/tool/probe가 같은 dispatcher와 권위 세계를 사용하며 `completed/fact/reward`를 UI에서 쓰지 않는다.

## 2. Catalog와 생성자 — 먼저 고정하는 API

새 `godot/scripts/core/campaign_catalog.gd`는 고정 allowlist와 표시 metadata만 가진다. 사용자/저장 헤더가 리소스·파일 경로를 지정하지 않는다.

| pack_id | 데이터 경로(`res://data/campaign/` 아래) | campaign_id / content_version | 기본 쓰기 슬롯(`user://saves/` 아래) |
|---|---|---|---|
| legacy_intruder | `legacy_v1.json` | `midnight` / 1 | `legacy_continue_01.json` |
| intruder | `packs/intruder_v2.json` | `midnight` / 2 | `intruder_v2_01.json` |
| defender | `packs/defender_v1.json` | `midnight_defender` / 1 | `defender_01.json` |
| tracker | `packs/tracker_v1.json` | `midnight_tracker` / 1 | `tracker_01.json` |

`legacy_v1.json`은 부모가 원본과 SHA를 대조해 동결했다. 생성기가 다시 쓰지 않는다. 원래 `campaign.json`은 이전 단일팩 검사 호환 경로이며 새 침투 생성기는 별도 pack 파일을 쓴다.

```gdscript
CampaignCatalog.list_packs(include_legacy: bool = false) -> Array
CampaignCatalog.default_slot(pack_id: String) -> String
CampaignCatalog.test_slot(base_json: String, pack_id: String) -> String
CampaignLoader.load_campaign(pack_id: String = "legacy_intruder") -> Dictionary
CampaignLoader.validate(raw: Variant, expected_pack_id: String = "") -> Dictionary
CampaignGame.new(save_path: String = "", pack_id: String = "legacy_intruder")
```

Catalog 목록의 공개 row는 `{id,title,summary,role,start_mission,main_count,optional_count}`다. title/summary는 번역된 표시값이며 리소스 경로/현재 진도/해답은 포함하지 않는다. `include_legacy=true`는 metadata를 더할 뿐 저장 존재를 가정하지 않는다.
첫 생성자 인자에 명시한 테스트 JSON 경로는 그대로 사용한다. `test_slot`은 `user://tests/` JSON base에 알려진 pack ID 접미사를 붙이는 순수 함수이며 경로 guard를 먼저 적용한다.
제품 UI는 항상 선택 ID와 `default_slot(id)`를 명시한다. 테스트 UI는 `test_slot(base,id)`를 명시한다. 기본 인자 없는 생성자는 기존 단일팩 의미·v2 스냅샷 검사와 호환되지만 원본 저장에 쓰지 않는다.
새 UI 기본 선택은 intruder이며 세 편을 자유 선택한다. 선택은 새 Game 인스턴스를 만든다. 한 인스턴스의 pack을 바꿔 이전 WorldState/인증/저장을 섞지 않는다.

기존 execute/submit_password/cancel/get_view/autocomplete/request/use_tool/choose_mission/advance/choose_ending/save/load/recover/start_new API는 유지한다. request의 다섯 번째 terminal_id와 tool params.terminal_id는 계속0~3의 명시적 주체다.
읽기 view에 `campaign:{id,title,role}`, `campaign_progress:{completed,total,ending_chosen}`를 추가한다. 수치는 현재 팩만 뜻한다. `completion_recorded/current_goals_met`의 과거·현재 구분도 유지한다.

## 3. 원본 보존과 이전판 계속

원본 고정 읽기 경로는 v1 M01 `user://saves/slot_01.json`, 기존 v2 `user://saves/campaign_01.json`이다. 어떤 새 팩도 이곳을 기본 쓰기/복구 대상에 넣지 않는다.
완벽한 v2→신내용 이식 대신 **이전판의 원래 규칙/내용으로 이어하기**를 제공한다. 이전 완료를 새로운 M24·분기 VM·D/T 능력의 증거로 승격하지 않는다. 새 침투/D/T는 새 진행이다.

```gdscript
get_save_status(include_legacy_sources: bool = false,
                legacy_source_override: String = "") -> Dictionary
load_continuation() -> Dictionary
continue_legacy_source(source_override: String = "") -> Dictionary
```

status는 `{exists,valid,backup_available,legacy_available,legacy_source_available,legacy_sources_checked,pack_id,reason_code}`다. legacy_available은 v1, legacy_source_available은 v2 원본의 실제 검증 결과다. 기본 검사는 실사용 이전 원본을 읽지 않으며 제품 메뉴가 명시적으로 true를 준다.
원본이 있으나 손상/불지원이면 legacy_source_exists=true와 legacy_source_reason을 별도로 제공한다. ‘발견됨’과 ‘이어갈 수 있음’을 구분하고 target reason_code를 원본 사유로 오인하지 않는다.
source override는 목적 슬롯도 `user://tests/`일 때만 같은 테스트 저장 범위의 JSON을 허용한다. 그 외에는 stat 전에 거절한다. 제품 UI에는 임의 경로 입력기를 만들지 않는다.

이전판 로드 우선순위:

1. continuation 파일이 있으면 그 파일을 검증/로드한다. 유효하면 가장 최근 진행으로 이어간다.
2. continuation이 손상됐으면 복구 후보만 보고한다. 원본으로 자동 되돌려 최신 진행을 숨기지 않는다.
3. continuation이 **없는 경우에만** 고정 원본 v2를 읽고 동결된 legacy 정의로 검증한다.
4. 유효한 원본은 새 continuation 슬롯에 tmp→재읽기→검증→rename으로 복사한다. 성공 뒤에만 후보 세계를 활성화한다. 원본/main/bak의 bytes는 그대로다.
5. 손상 원본의 `.bak`를 같은 이름의 ‘정상 원본’으로 자동 사용하지 않는다. 불지원·손상 원인은 구분해 알리고 원본을 유지한다.

v1의 기존 import_m01(raw)/import_legacy_save는 legacy 편의 M01만 명시적으로 가져온다. 새 intruder/D/T에 completed/fact/학습 성취를 넣지 않는다. UI는 가져온 범위와 별도 저장 위치를 표시한다.
기존 v2에서 새로운 내용으로 옮기는 API는 이번 필수가 아니다. 불지원 상태를 조용히 정리하거나 사본만 남기고 ‘완전 복원’이라 부르지 않는다. 이전판 검증과 R1의 경계가 맞지 않는 특수 상태는 명시적 사유/원본 보존으로 처리하고 검증 가능한 호환 범위를 기록한다.
저장은 기존 v2 9키를 유지한다: save_version/campaign_id/content_version/current_mission/current_world/completed/mission_states/decisions/ending. pack 결합은 catalog의 campaign_id+content_version과 활성 인스턴스로 검증한다.
잘못된 팩/내용 버전은 손상 JSON과 다르다. 다른 팩의 정상 파일을 `start_new`가 손상본으로 재분류해 치우지 않는다. 복구·새 시작은 선택한 팩의 슬롯에서만 실행한다. 구매 복구나 타편 진도 인증을 흉내내는 API/성취는 추가하지 않는다.

## 4. 공통 새 모형 인터페이스

기존 `Mission.challenges[id]`에 세 kind를 직접 정의한다. 별도 범용 scenario DSL을 추가하지 않는다. 상태는 기존 `world.model_states[id]`, 재생 가능한 행동은 `model_actions[id]`를 사용한다.
모든 동작은 `use_tool(id,{action:op,...fields,terminal_id})` 또는 같은 의미의 등록된 terminal/request/probe 호출로 들어온다. 기존 `params.input`도 호환하지만 새 UI 기본 입력은 form/selectors다.
모형 helper는 `definition + current world context + action → candidate state + typed effects + observations`를 계산한다. dispatcher가 권한·예산을 검증하고 일괄 적용한다. 실패는 정책 일부/사본 일부/완료 일부를 남기지 않는다.
effects는 등록된 set_policy/revoke_session/enqueue_business/collect_observation/vm_output뿐이다. 사용자 JSON의 임의 property 경로, set_fact, set_completed, 코드 경로는 없다.
실제 서비스 결과와 보상 조건은 분리한다. 관측/transport가 허용돼도 requires_facts·scope가 없는 자료/fact/성취 보상은 생기지 않는다. 이 구분을 재생 검사에도 보존한다.

공개 Tool row는 기존 id/name/description/kind/data에 다음을 더한다:

```json
{
  "id": "desk_response",
  "kind": "response_lab",
  "actions": [{
    "id": "probe",
    "label": "DF1_PROBE_ACTION",
    "fields": [{"id": "case_id", "type": "enum", "options": [{"id": "own_a", "label": "DF1_OWN_A"}]}]
  }],
  "data": {"matrix": [{"case_id": "own_a", "label": "DF1_OWN_A", "intended": "allow", "observed": null}]}
}
```

actions/fields/options는 core가 현재 권한/관찰에서 파생해 제공한다. UI는 선택한 ID와 값만 보낸다. 숨은 answer/expected token/정답 행위자/전체 저작 JSON은 data에 노출하지 않는다.
field type은 bool/int/enum/string/array(multi_enum)/object다. object.fields는 자식 field 배열이고 claim/VM values는 이 중첩 form으로 전송한다. UI 내부 위젯 key는 claim.kind처럼 둘 수 있으나 user에게 저작 JSON 입력을 요구하지 않는다.
행동 결과는 `{ok,code,text,changed,status?,event,observations?,feedback?,checkpoint_id?}`다. 공개 feedback은 실제 관측 결과이며 세계에 다시 적용할 명령이 아니다. 내부 effects.policy_updates/revoke_tokens만 runtime이 권위 상태에 적용한다.

## 5. response_lab — 정상 업무와 위협을 같은 세계에서 재생

필수 정의는 host_id/requires_session/controls/cases/checkpoint_groups다. controls의 key가 조작 ID이며 policy_id는 기존 world.policies의 실제 권위 값이다. 경로·서비스도 그 정책을 공통 handler에서 읽는다.
다음은 Mission의 challenge 조각 예시다. actor/host/policy/record 참조는 같은 Mission의 기존 정의에 있어야 한다.

```json
{
  "kind": "response_lab",
  "host_id": "desk",
  "requires_session": {"host_id": "desk", "account_id": "operator"},
  "controls": {
    "owner_check": {"policy_id": "owner_check", "values": [false, true], "group": "ingress", "label": "DF1_OWNER_CHECK"},
    "gateway": {"policy_id": "gateway_enabled", "values": [false, true], "group": "ingress", "label": "DF1_GATEWAY"}
  },
  "bindings": {
    "objects": {"C731": {"owner": "citizen_a", "record_id": "ticket_731"}},
    "endpoints": {
      "direct": {"host_id": "desk", "method": "GET", "path_prefix": "/tickets/", "operation": "object_read", "owner_policy": "owner_check"},
      "gateway": {"host_id": "gateway", "method": "GET", "path_prefix": "/tickets/", "operation": "delegated_read", "enabled_policy": "gateway_enabled", "scopes": {"citizen_a": ["C731"]}}
    }
  },
  "cases": {
    "own_a": {
      "label": "DF1_OWN_A", "class": "normal", "actor_ref": {"host_id": "desk", "account_id": "citizen_a"},
      "request": {"method": "GET", "url": "https://desk.packet.test/tickets/C731", "body": {}, "headers": {}},
      "routes": {"gateway": {"method": "GET", "url": "https://gateway.packet.test/tickets/C731", "body": {}, "headers": {}}},
      "expect": {"statuses": [200], "business_key": "ticket:C731:read", "value": true}
    },
    "foreign": {
      "label": "DF1_FOREIGN", "class": "threat", "actor_ref": {"host_id": "desk", "account_id": "outsider"},
      "request": {"method": "GET", "url": "https://desk.packet.test/tickets/C731", "body": {}, "headers": {}},
      "expect": {"statuses": [401, 403], "business_key": "ticket:C731:read", "value": false}
    }
  },
  "checkpoint_groups": {"ingress": ["owner_check", "gateway"]}
}
```

request가 기본 direct이고 routes는 승인 대안이다. probe `{case_id:"own_a",route_id:"gateway"}`는 다른 경로로 같은 business outcome을 검증한다. expected는 goal 비교에만 쓰며 handler가 expected를 복사해 결과를 만들지 않는다.
응답은 기존 status/actor/route/trace에 `business:{"ticket:C731:read":true}` 같은 실제 operation 결과를 더한다. expect.business_key는 이 응답 business의 키이며 value는 비교 기준이다. 승인 gateway도 같은 업무 key를 만들되 실제 actor/object scope를 따로 검사한다.
등록 operation은 기존 object_read/auth_login/session_use/upload_create와 notify_send다. 객체 owner/위임 scope, 실제 정책·route·서비스·세션, 저장/실행 상태에서 status와 business 결과를 계산한다. 모든 종료로 threat만 막는 것은 normal case가 실패한다.
Probe의 actor_ref는 담당자가 허가받은 테스트 case의 서비스 인증 주체다. public request의 body.actor_ref로 임의 사칭하지 않는다. UI는 case label을 고르며 credentials 원문을 받지 않는다.
이 최소모형의 case.actor_ref는 등록된 승인 테스트 세션 `{host_id,account_id}`다. host_id는 그 case가 실행되는 실제 host/vantage이고 credential realm이나 인물의 영구 위치를 뜻하지 않는다. account_id는 그 host에 등록된 현지 계정이며, 같은 문자열이 다른 host의 권한이나 위치를 만들지 않는다. request/routes가 대상 URL을 바꿔도 승인 case의 실행 위치는 유지된다. probe는 이 위치에서 현재 via·포트·프로토콜·정책을 실제 검사하고 receipt.origin에 남긴다. public HTTP의 origin은 선택한 실제 SSH 위치 또는 browser의 local이고 body.actor_ref로 바꿀 수 없다. 별도 realm/독립 vantage 필드는 현재 구현하지 않는다.

| action | 입력 | 실제 변화/관측 |
|---|---|---|
| inspect | 없음 | 현재 control·허용 조작·matrix를 읽음 |
| set_control | control_id,value | 선언된 policy만 변경, 다른 UI/HTTP에도 즉시 반영 |
| probe | case_id,route_id? | 실제 요청 handler 결과·business effect·관련 상태 표식 기록 |
| checkpoint | group | 해당 정책 group만 bounded checkpoint로 보존 |
| rollback | checkpoint_id,group | 그 group의 정책만 원복, 다른 조치/사본/폐기 자격은 유지 |
| revoke | token_ref | 실제 세션 폐기 handler 호출, rollback으로 부활하지 않음 |
| advance | ticks:1..32 | 공통 논리 tick/cooldown만 진행, 실제 대기는 아님 |

state는 `{checkpoints,probe_receipts,business_objects,revocation_refs,last_feedback}`다. 현재 policy 값을 복제해 권위 상태로 두지 않고 checkpoint 안에만 과거 값을 둔다. checkpoint는8개, case당 최근 관찰과 필요한 과거 비교는 합계128개 행동 예산 안에서 시작한다.
첫 사용자 checkpoint ID는 model별 checkpoint_1이다. 성공 결과의 checkpoint_id와 view.data.checkpoints로 제공한다. initial_checkpoints는 선언된 group/control/value만 가진 실제 이전 정책 이력으로 허용하며, 사용자에게 일부러 잘못된 설정을 한 번 만들도록 강제하지 않는다.
추가 endpoint 필드는 auth_login(rate_policy/limit/cooldown), session_use(revocation_policy/initial_tokens), upload_create(validation_policy/nonexecuting_policy), notify_send(enabled_policy/allowed_targets/target_policy?)다. body는 각각 username/password, token_ref/object_id?, filename/mime/signature, target/message다.
vfs_read/vfs_write는 고정 file_path와 실제 actor/groups로 기존 VFS를 사용한다. vfs_write는 bindings.write_scope(필요한 endpoint의 더 좁은 write_scope 선택 지원)로 선언된 범위 안의 업무 파일만 바꾼다. control kind vfs_mode(host_id/file_path/values)와 actor_groups(host_id/account_id/values)를 통해 승인된 메타데이터를 바꾸며 legacy에는 선언이 없으므로 원격 mode 위조는 계속 거절한다.
Goal은 `{kind:"response_matrix",challenge_id,case_ids:[...]}`다. 모든 명시 normal/threat case의 현재 업무/차단 결과와 자료 보존을 검사한다. 과거 관찰을 쓰려면 해당 좁은 관련 상태/현재 결과가 여전히 같아야 한다. 무관한 읽기로 무효화하지 않는다.
D07 rollback은 revoke·수집 이력·다른 group을 복원하지 않는다. 전체 WorldState 되감기를 rollback 버튼으로 제공하지 않는다. 다른 정밀 정책/승인 경로로 같은 정상·위협 행렬을 만족하면 통과한다.

## 6. observation_case — 출처·관측 선택·가설과 반증

정의는 sensors/claim_types/handoff_requirements다. sensor가 공개하는 행과 숨은 세계 원인을 구분하며 가설 평가는 **수집된 공개 행만** 읽는다.

```json
{
  "kind": "observation_case",
  "sensors": {
    "session_registry": {
      "label": "TR1_SESSION_REGISTRY", "host_id": "relay", "visibility": "metadata",
      "coverage": {"sampling": "complete", "window": [100, 130]},
      "requires_session": {"host_id": "relay", "account_id": "investigator"},
      "windows": [{"rows": [{
        "event_id": "login_41", "observed_at": [110, 112], "clock_offset": [-1, 1],
        "public": {"session_tag": "S1", "request_tag": "N47", "from_node": "edge", "to_node": "relay", "shared_address": "10.42.4.8"},
        "provenance": {"source_id": "relay:session_registry", "collector": "approved-export", "vantage": "relay", "acquisition": "registry-read", "marker_authority": "server_issued"}
      }]}]
    }
  },
  "claim_types": ["same_session", "forwarded_to", "before"],
  "handoff_requirements": {"supported": [{"kind": "forwarded_to", "request_tag": "N47", "target_node": "relay"}], "refuted": [], "next_vantage": ["session_registry"], "allow_identity_unknown": true}
}
```

sensor별 windows는 유한한 저작 관측 구간이다. collect는 현재 허가/위치/구간에서 실제 보이는 행만 얻는다. advance_watch는 다음 구간으로 이동해 새 관측을 열며 실시간 대기/죽음 타이머가 아니다. 다른 관점의 실제 save는 읽지 않는다.
시각 보정 구간은 `[observed_min-offset_max, observed_max-offset_min]`이다. session_tag/request_tag/from_node/to_node/shared_address는 공개 열이며 marker_authority가 client_supplied면 동일 tag를 곧바로 동일 세션 증명으로 삼지 않는다.
암호화된 중간 구간은 metadata만 보인다. plaintext는 허가된 endpoint/plaintext sensor일 때만 가능하다. 단순 ‘복호화’ 버튼은 없다.

| action | 입력 | 결과/기록 |
|---|---|---|
| inspect | sensor_id? | 공개 sensor,가용성,coverage·권한을 읽음 |
| collect | sensor_id,filter:{field,value}? | canonical 관측 사본·SHA256·provenance·수집 위치/구간을 append-only로 보존 |
| advance_watch | sensor_id | 다음 bounded window로 이동, 같은 읽기를 반복해 새 근거를 만들지 않음 |
| hypothesize | hypothesis_id,claim:{kind,left,right},observation_ids | 주장을 저장할 뿐 사실·보상은 만들지 않음 |
| test | hypothesis_id | 수집된 관측에 따른 supported/refuted/underdetermined와 사용 근거 |
| revise | hypothesis_id,replacement_claim,reason_observation_ids | 이전 주장을 지우지 않고 정정 이력 연결 |
| handoff | supported_hypothesis_ids,next_sensor_id | 요구된 연결/반증/다음 관측과 한계가 갖춰졌는지 검사 |

left/right는 이미 관측된 entity ref(session:S1/node:relay/event:login_41 등)만 사용한다. same_session은 신뢰 가능한 세션 tag와 양립 가능한 시간 구간, forwarded_to는 신뢰된 직접 전달 행의 request tag와 from/to node, before는 분리된 보정 구간을 검사한다.
forwarded_to의 left는 request:N47, right는 node:relay다. copy ID는 sensor_id:window_index:event_id(index0)이고 state.observations는 그 ID의 Dictionary다. public collect.observations는 공개 row Array이며 observation_ids는 명시적으로 그 사본을 인용한다. 빈 인용을 all collected로 몰래 보완하지 않는다.
IP 하나만 같거나 sampled 구간에 행이 없으면 보통 underdetermined다. 완전한 해당 구간 관측이 반례를 제공할 때만 refuted를 낸다. 내부 culprit ID나 숨은 정답률은 평가 입력이 아니다.
state는 `{sensor_cursors,observations,hypotheses,hypothesis_history,handoff}`다. 수집본은 원본 변화로 덮지 않고 정정·새 수집을 연결한다. Goal `{kind:"observation_handoff",challenge_id}`는 요구된 관측/지지·반증·후속 인계를 확인한다. ‘모름’만 고르는 것은 요구 연결을 충족하지 않는다.
handoff.claims:[{kind,left,right,observation_ids}] 직접 제출도 허용한다. initial_claims:{id:{label,claim,source_id}}는 저작된 기존 주장으로, handoff_requirements.refuted:['prior']는 그 주장에 대한 현재 반증을 뜻한다. 유저가 고의로 틀린 가설을 제출한 횟수/이력을 통과 조건으로 쓰지 않는다. 지지는 명시 인용으로 계산하되 이미 수집한 관련 반대 관측은 모두 고려한다.
UI data는 sensor 목록/관찰 표/출처·시각 구간/가설 상태/지원·반박 근거/다음 선택지다. 아직 수집 안 한 rows, hidden_actor/expected_claim은 공개하지 않는다.
공개 관측을 고정하고 hidden actor만 바꿔도 피드백이 같아야 한다. T07에서 새 반증이 들어오면 관련 edge만 바뀌고 예전 수집/틀린 가설 기록은 남아야 한다.

## 7. branch_vm — bounded 분기·호출 퍼즐

R01은 XOR 한 단어 일치 대신 실제 input→조건→분기→함수 호출→output을 실행한다. 실제 바이너리/CPU/스크립트 평가기가 아니다. 아래 프로그램은 서명은 확인하지만 보존 범위를 확인하지 않는 예시다.

```json
{
  "kind": "branch_vm",
  "inputs": {"format_ok": {"type": "bool"}, "signature_ok": {"type": "bool"}, "retention_scope": {"type": "enum", "choices": ["authorized", "excluded"]}},
  "limits": {"steps": 256, "stack": 16, "memory": 64},
  "program": {"entry": "main", "functions": {
    "main": [
      {"label": "entry", "op": "LOAD", "dst": "fmt", "input": "format_ok"},
      {"op": "BRANCH", "reg": "fmt", "then": "signed", "else": "deny"},
      {"label": "signed", "op": "CALL", "function": "check_signature", "dst": "sig"},
      {"op": "BRANCH", "reg": "sig", "then": "grant", "else": "deny"},
      {"label": "grant", "op": "SET_OUTPUT", "key": "release", "value": true},
      {"op": "HALT"},
      {"label": "deny", "op": "SET_OUTPUT", "key": "release", "value": false},
      {"op": "HALT"}
    ],
    "check_signature": [{"op": "LOAD", "dst": "ok", "input": "signature_ok"}, {"op": "RET", "reg": "ok"}]
  }},
  "outcomes": {"normal": {"input_scope": "authorized", "output": {"release": true}}, "counterexample": {"input_scope": "excluded", "output": {"release": true}}}
}
```

고정 op는 CONST/LOAD/CMP/BRANCH/JUMP/CALL/RET/SET_OUTPUT/HALT다. CONST는 dst/value, LOAD는 dst/input, CMP는 dst/left/right/relation(eq/ne/lt/le)이고 operand는 `{reg:"r"}` 또는 `{value:literal}`다. BRANCH는 reg/then/else의 같은 함수 label, JUMP는 target label, CALL은 function/dst, RET은 reg, SET_OUTPUT은 key/value literal이다. CALL은 현재 frame을 보존하고 callee의 빈 registers에서 시작하며 RET이 caller의 dst에 값을 돌려준다. 없는 label/함수/입력·타입 오류·예산 초과는 효과 없이 실패한다.
limits.memory는 실제 CPU RAM이 아니라 살아 있는 frame/register의 모형 값 슬롯 합계다. input_scope는 예제의 inputs.retention_scope에서 유도한다. count와 case_id 이름으로 성공을 만들지 않는다.
set_input `{case_id,values}`는 inputs schema만 허용한다. step `{count:1..32}`, run `{case_id?}`, reset `{case_id?}`, inspect `{section:listing/call_graph/trace}`를 제공한다. 프로그램/레지스터/PC를 사용자 JSON으로 교체하지 않는다.
state는 `{cases,active_case,registers,pc,call_stack,outputs,trace,status,steps_used}`다. trace는 실행한 instruction·실제 branch/call·관측 output만 담는다. 정답 입력이나 숨은 expected를 UI에 덤프하지 않는다.
Goal `{kind:"vm_cases",challenge_id,requirements:["normal","counterexample"]}`는 입력에서 유도한 scope와 실제 output을 비교한다. case_id 이름을 normal이라 붙인 것으로 분류하지 않는다. CLI/서비스 요청도 같은 VM을 호출할 수 있어 step 버튼 횟수·특정 도구는 필수가 아니다.
R01은 정상 허용과 권한 범위 밖 반례를 함께 보여 주고 실제 호출된 검사/빠진 검사의 의미를 해석하게 한다. M17은 XOR를 암호 감사로 포장하지 않고 기존 auth+제한 후보 검증/좁은 자료 접근을 재사용한다.

## 8. M24의 현재 세 경계

새 goal `{kind:"current_boundaries",cases:{web:[{challenge_id,case_id}],route:[{challenge_id,case_id}],service:[{challenge_id,case_id}]}}`는 실제 공통 handler 관측을 사용한다. 무자격 case 문자열은 거절한다. 같은 qualified pair를 여러 group에 쓸 수 있으나 그 관측이 실제 해당 경계를 확인해야 하며 다른 lab의 동명 case로 대체하지 않는다. 과거 사건 fact나 compare 문자열로 대체하지 않는다.
web은 actor/object/위임의 허용·거부, route는 현재 vantage→최종 목적지의 실제 도달, service는 해당 자격/scope의 허용·범위 밖 거부다. 세 취약점을 모두 공격/패치해야 한다는 뜻은 아니다.
관측 영수증은 대상 actor·요청·위치·결과와 좁은 관련 상태를 갖는다. 현재 관련 정책/경로/세션이 달라지면 그 경계만 새 결과를 요구한다. 다른 파일 읽기·창 전환으로 전체를 무효화하지 않는다.
이 기능은 세 개의 닫힌 상태 표식/현재 결과 비교로 시작한다. 임의 dependency DSL·전체 세계 이벤트 소싱·보이지 않는 신뢰도 점수를 만들지 않는다.
새 모형의 goal/view 재평가는 순수 읽기다. notify/probe/collect 등 사업 효과를 다시 발생시키지 않는다.

팩별 contacts metadata는 `{Cxx:{name_key,introduced_by:[samePackMissionID],face_gate:{when:introduced|completed,mission_id?,explicit:bool}}}`다. 신규 D/T의 소개·얼굴 gate는 그 편의 사건만 본다. C01은 각 편의 gate 후 명시적 공개 선택을 유지한다. metadata 없는 이전판은 기존 CONTACTS 의미를 보존한다.

## 9. R1/I2와 도달 가능→저장 가능

R1과 감사 R4/I2는 기준 코드에서 미해결이므로 확장보다 먼저 공통 경계에서 고친다. 새 모형도 이를 우회할 수 없다.

- Campaign local 항목 상한은 디렉터리 포함512로 통일한다. 기본 v1 Game은 기존128 가상 한도를 유지하고 Campaign의 override가512를 사용해 기존336 의미를 보존한다.
- 모든 최종 정규 경로는1024자를 넘지 않는다. 인자만 짧다고 cwd 결합 뒤 긴 경로를 허용하지 않는다.
- mkdir/cp/mv/archive/rmdir와 보상/관측 추가는 동일한 크기·참조·계층 검증을 적용한다. rmdir는 local home의 빈 디렉터리만, protected base/remote는 불가다.
- 새 비목표 항목 생성은 아직 없는 필수 record 사본의 공간을 남긴다. 이미 유효했던 이전판 포화 상태는 읽기·삭제·비성장·저장을 허용하고 사본/원본을 조용히 삭제하지 않는다.
- 후보 전체 스냅샷(현재+sealed receipts)이2MiB를 넘으면 적용 전에 원복 거절한다. 251개 관측을 받고 나서야 디스크 저장이 실패하는 상태를 만들지 않는다. 예산 거절은 실제 인증 거부/공격 탐지로 표시하지 않는다.
- 모델/정책/가설의 실패·예산 초과는 apply/sync/완료 영수증 교체 전에 걸러진다. 정상 파일 보존·tmp/bak 검증·손상 원본 보존은 기존 Store를 유지한다.
- /login의 실제 인증·cookie·counter/cooldown은 요구한 서비스 의미대로 움직인다. 퍼즐 선행 fact가 없다고 실제 로그인을 실패시키거나 기존 세션 전제를 통째로 붙이지 않는다.
- 보상은 별도 eligibility(scope/facts/current conditions)를 거친다. eligibility가 false인 transport 관측은 남아도 자료/fact/완료는 생기지 않는다. 그 분리를 action 재생·복원도 같은 규칙으로 검증한다.

## 10. 파일 책임과 검증 묶음

| 파일 | 책임 |
|---|---|
| campaign_catalog.gd | 고정팩/리소스/슬롯·순수표시목록·테스트슬롯 |
| campaign_loader.gd | pack별정의·kind/참조/localekey/boundedprogram검증 |
| campaign_game.gd | pack고정Facade·독립진도/결말·legacy우선순위·후보전체예산 |
| campaign_runtime.gd | 한권위세계·dispatch·actor/route/service·currentgoals·typed effects |
| response_lab.gd / observation_case.gd / branch_vm.gd | 새세모형의닫힌계산/공개projection/재생검증 |
| virtual_fs.gd / game.gd / save_store.gd | R1에필요한공유최종경로/가상한도/안전Store경계만수정 |

새 fixture는 `godot/tests/fixtures/perspectives_solutions.json`의 `{schema_version:1,packs:{packID:{missions:{ID:{paths:[...]}}}}}`다. 기존 legacy fixture와 분리한다. action kind는 기존 command/password/browse/collect_web/request/tool을 유지하고 tool params에 위 typed action을 넣는다.
새 locale 원고는 `data/campaign/locales/intruder_v2.{ko,en}.json`, `defender_v1.{ko,en}.json`, `tracker_v1.{ko,en}.json`이다. 새 key namespace는 IN2_/DF1_/TR1_로 분리하고 기존 legacy key·canonical 본문은 보존한다. 같은 의미의 COMMON/Cxx/runtime key만 공유한다.
새팩44사건의 실제 두 경로, legacy28/기존31717, 기존336, 상태변경/인증 RED, 이전원본SHA보존·continuation우선/손상비fallback, pack분리·저장왕복을 큰 묶음으로 검증한다.
방어는 전체 종료 실패·두정밀해법·부분rollback·폐기자격불부활, 추적은 hiddenActor메타모픽·반증·불확실구간·새관측, VM은 분기/call·예산/잘못된입력·실제두출력, M24는 세현재경계 중하나를깨면그조건실패를 검증한다.
R1의 긴상대경로/UI512내명령·cap/space회수·128/512일관성·2MiB와 I2의 HTTP정상인증/보상누락/재생일치는 별도 실제 회귀로 유지한다. UI원어민·재미/시간·청취·native/export 수락은 자동 fixture 수와 구분한다.


구현 보완: `get_save_status(true)`는 `legacy_source_exists`와 `legacy_source_reason`도 반환한다. 발견과 복원 가능성을 구분하며, 기본 false는 실제 구 슬롯을 조회하지 않는다. 다른 campaign/content_version의 JSON을 현재 편의 손상 저장으로 재분류해 교체하지 않으며 `SAVE_DIFFERENT_CAMPAIGN`으로 원본과 백업을 보존한다.
`handoff`의 예전 `refuted_hypothesis_ids`/`unknown_edges` 입력은 주석 호환만 허용한다. 필수 기존 주장 반증은 수집 근거에서 직접 계산하고, UI는 지지할 가설과 다음 관측 위치를 선택한다.

`model_states.*.solved`는 적격한 관측으로 얻은 과거 분석 성취다. 현재 정책/업무 안전성은 이 bool을 완료 기준으로 쓰지 않고 response_matrix/current_boundaries 등 순수 현재 판정으로 재평가한다. response 관측마다 적격 여부를 기록하며, 선행 근거 없는 HTTP의 실제 응답을 나중 inspect만으로 새 완료 근거로 승격하지 않는다. 과거의 유효 관측을 다른 관측 때문에 삭제하지 않는다.

## 11. 독립 리뷰 후 수리 계약

- 인증의 실패 1/2/3 응답은 당시의 rate-limit 동작을 보이는 역사적 관측이다. 정상 200 인증 case는 같은 사용자에게 지금도 정상 로그인이 가능한지 순수 재평가한다. 현재 cooldown이 양수이고 해당 rate 정책이 켜져 있으면 현재 목표는 false이며, 다른 사용자의 카운터는 그 정상 case를 무효화하지 않는다. 이 재평가는 로그인·토큰 발급·카운터 변경을 실행하지 않는다.
- 업로드 저장 객체에는 `execution_allowed_at_upload`, `execution_policy_id`, `signature_valid`, `quarantined`를 기록한다. 현재 실행 가능성은 당시 위험성과 현재 저장소 실행 정책·격리 상태로 계산한다. 과거 수락은 실제 코드 실행을 뜻하지 않으며 이력을 지우지 않는다.
- `response_lab`의 `quarantine` 입력은 `{artifact_id,quarantined:bool}`이고 기본값은 true다. 단일 공개 저장 객체만 바꾸고 목록 전체를 지우지 않는다. 정상 사진을 격리하면 정상 업무 목표가 실패하며, 잘못된 격리는 같은 조작의 false로 해제할 수 있다.
- 공개 `data.artifacts`는 `[{artifact_id,filename,stored_as,endpoint_id,signature_valid,quarantined,execution_allowed,execution_allowed_at_upload,accepted_tick}]`다. `business_objects`의 업로드 공개 행도 같은 현재/과거 의미를 사용한다. `artifact_events`는 `{event:'accepted'|'quarantine_changed',tick,artifact_id,endpoint_id,execution_allowed_at_upload?,quarantined?}`를 뒤에 덧붙이며 이전 이벤트를 덮지 않는다.
- facade의 모든 슬롯 쓰기는 main/bak/tmp/bak.tmp의 campaign/content 식별자를 먼저 검사한다. 어느 경로에서든 다른 편·내용 버전이 확인되면 저장·새 시작·복구를 거절하며, 기존 파일과 활성 메모리를 유지한다. Store는 게임 내용에 의존하지 않는 원자 IO를 담당한다.
- VM `inspect.section`은 listing/call_graph/trace의 공개 enum이다. 알려지지 않은 section은 원자 거절한다. 성공 feedback은 고른 공개 영역의 현재 rows를 돌려주며 숨은 outcomes를 노출하지 않는다. UI는 기존 구조화 form을 사용한다.

M08의 선택적 닫힌 binding은 `csrf_change` 하나다. endpoint에는 origin, token_policy, 선택 origin_policy(생략 시 token_policy 사용), tokens(account→nonce), scopes(account→setting ID 목록), 선택 own_setting을 둔다. request는 headers.Origin과 body의 setting_id(생략 시 own_setting)/token/value를 사용한다. endpoint의 정책·nonce·scope를 caller body가 바꿀 수 없다.
실제 인증 actor가 없으면 401, scope 밖 대상이나 켜진 nonce/origin 검사를 통과하지 못하면 403이다. 성공한 값만 `business_objects['setting:'+account+':'+setting_id]`에 보존하고, business의 `setting:<account>:updated`와 `setting:<account>:value`는 실제 저장 결과에서 만든다. value는 bool/string/int의 제한된 자료값이다. 정상 case는 현재 저장된 값도 그 정상 요청의 값과 같아야 하며, expect/class를 handler 입력으로 쓰지 않는다.

추적 모형의 일반화 한계: 현재 same_session은 같은 사건 안에서 서버 발급 tag 공간이 공유된다는 저작 가정 아래 판정하며, forwarded_to는 승인된 관측점의 직접 전달 행을 근거로 한다. 서로 다른 issuer가 같은 tag를 재사용하는 경우나 두 센서 사이의 일반적인 시간·경로 상관분석을 구현했다고 주장하지 않는다. 실제 인물의 동일성은 판정하지 않는다. 이 한계는 미확정 리뷰 가정으로 분리하며 현재 수리 묶음에서 새 추론 엔진을 만들지 않는다.
