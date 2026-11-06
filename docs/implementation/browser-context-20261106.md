# 브라우저 터미널 주체 API

작업트리 `packet-trail-desktop/feat/desktop-experience`. 최초 코어 변경은 campaign_game.gd의 browse/collect_web 두 메서드로 제한했다. 아래 C23 후속의 실제 RED 뒤 Root가 승인한 Runtime collect_page의 두 실패 반환에만 변경 전달 인수를 추가했다. 저장 형식, 모델, UI, 데이터, locale과 다른 담당자의 파일은 변경하지 않는다.

## 현행 경계와 최소 계약

변경 전 browse(url)는 request의 기본 terminal0을 항상 사용한다. collect_web(url)는 Runtime이 마지막으로 선택한 terminal을 암묵적으로 사용한다. 따라서 UI가 표시하는 active terminal만으로 호출의 명시적 주체를 보장할 수 없다. 실제 실행 RED와 API 지원 부족은 아래 실행 기록에서 구별한다.

- browse(url, terminal_id:int=0): 기존 browser context header를 유지하고 request의 terminal_id 인수로 전달한다.
- collect_web(url, terminal_id:int=-1): -1은 기존 마지막 선택 동작을 유지한다. 0..3은 checkpoint 뒤 해당 terminal을 선택한다. 나머지는 INVALID_TERMINAL로 거절하고 어떤 상태도 바꾸지 않는다.
- 일반 unchanged 실패는 기존 checkpoint/rollback 패턴으로 되돌리고, 성공·변경이 있는 결과는 기존 _finish_action의 snapshot 검증/예산 경로를 통과한다.
- 브라우저의 local 출발점, origin별 공유 웹 cookie, SSH 주체와 웹 주체의 구분, 실제 권한 검사와 v2 정확9키는 변경하지 않는다. terminal 인수는 웹 로그인이나 별도 cookie jar를 만들지 않는다.

UI 호출은 game.browse(url, active_term), game.collect_web(url, active_term)이다. 무인자 기본 호출은 기존 browse terminal0/collect 마지막 선택의 차이를 그대로 유지한다.

## 표적 회귀

새 godot/tests/headless/test_browser_context.gd는 기존 mutation 테스트의 실제 API/fixture·고유 tests 슬롯·기본28경로 지문/정리 도우미를 상속해 재사용한다. 실제 legacy M01/M06의 권한·쿠키 조건을 사용하며 완료/fact/session을 주입하지 않는다. loaded512 항목 및 validator가 허용하는 bounded inert observations의 near2MiB 입력만 호환/크기 경계에 사용하고 해법·성취·실제 관측으로 세지 않는다.

- 명시 인수를 받는 API 존재와 무인자 기존 호출 호환.
- maint0/guest1/local2/pending3·마지막 operation의 조합에서 명시 선택 및 다른 terminal stack/pending 인증 보존.
- M06의 terminal0 SSH 권한을 browser가 빌리지 않음, 실제 HTTP login의 cookie만 사용, local browser vantage 유지, 정상 저장/새 Game load 뒤 cookie 재사용.
- invalid terminal·외부/미등록 URL·NO_RECORD의 일반 실패에서 checkpoint 전체와 pending 인증 보존.
- 기존 loaded512의 archive 거절/삭제 후 정상 실제 회복, near2MiB snapshot 예산 거절과 전체 원복.
- v2 정확9키·실제 슬롯 저장 왕복·기본 settings/모든 campaign 슬롯 및 .bak/.tmp/.bak.tmp28경로 bytes 보존.

UI의 draft 문자열은 코어에 저장되는 상태가 아니므로 이 회귀는 코어 pending 인증을 검사한다. 실제 UI draft 보존, native 입력/렌더와 물리 IME는 다른 검증 범위다.

## 실행 기록

Root 초기 import 완료/조정 신호 뒤 할당된 표적 실행 슬롯에서 아래 순서로 실행했다. 새 import, whole gate, native, export와 commit은 수행하지 않았다.

| 단계 | 실제 결과 | 의미 |
|---|---|---|
| 제품 변경 전 red.log | 13검사/2실패, 종료1, 0.455초, 엔진 오류0 | 실제 메서드 arity가 browse1/collect1이라 명시 terminal 인수가 없는 API 지원 부족. 기존 무인자 browse0/collect3·정상 M01 수집/저장은 통과 |
| 최소 패치 first-patch.log | 160검사/3실패, 종료1, 1.032초, 엔진 오류0 | actor/권한/쿠키/vantage/pending/invalid/512 회귀는 통과. near2MiB fixture의 임의 local 본문이 canonical source 검증에 거절된 QA 오류 |
| fixture 교정 green.log | **160검사/0실패, 종료0, 1.062초, 엔진 오류0** | 실제 API·권한·컨텍스트·저장·예산 기대값을 유지한 최종 GREEN |

임의 local 파일을 정상 자료로 취급하도록 validator를 완화하지 않았다. 크기 경계 fixture만 기존 validator가 허용하는 inert observations로 바꾸고, restore 성공을 확인한 뒤 실제 collect의 STATE_BUDGET 원복을 검사한다. 이 입력은 사람이 얻은 관측이나 게임 진행 증거가 아니다.

실행별 source 지문은 core15개+새 test+동결 fixture 총17파일이며 전후 모두 동일했다. RED와 GREEN 사이의 차이는 소유 campaign_game.gd 및 새 test뿐이다. UI/Settings 담당자는 동시에 파일을 편집할 수 있으므로 이 숫자를 전체 workspace 불변으로 확대하지 않는다. 기본28경로 지문 보존은 세 실행에서 모두 통과했다.

campaign_game.gd의 HEAD 대비 차이가 browse/collect_web 두 메서드 안에만 있음을 텍스트 구조 대조로 확인했고 diff --check도 통과했다. 최종 SHA256은 코어 302eabb9e3cd611a50e61cce402eca7ba469c649ff56b4c7ecf6ca479db9d762, test 60e081ad96c8555109ff3803d1fc2f0afd31c2819de624326c7d78c3d7dd5425이다. 로그와 전후 지문은 .omx/artifacts/browser-context-20261106/{red,first-patch,green}.{log,json}에 보존했다.

두 메서드의 코어 변경과 소유 회귀를 동결했다. 표적 Godot 프로세스 종료를 Root에게 알리고 Settings 실행 슬롯으로 넘겼으며 UI 담당자에게 확정 인수 계약을 전달했다. 나머지 전체 gate/UI/native/패키징 검증은 Root 통합 범위다.

표적 호출: godot --headless --path godot --script res://tests/headless/test_browser_context.gd. 고유 suite=browser_context, 양의 정수 checks, failures=[], protected_paths=28, 실제 종료0 및 Script ERROR/Parse Error/ERROR0을 모두 요구한다. Root의 외부 deadline runner와 결합하며 전체 gate/native/export를 이 레인에서 실행하지 않는다.

## C23 후속: 수집 실패가 실제 GET 관측을 지우는 회귀

C23 질문1은 소스 정적 가설에서 실제 회귀로 확인됐다. request_page는 등록된 response_lab endpoint를 먼저 실행한다. _response_request는 HTTP 실패도 _commit_model로 실제 모델 상태/행동 영수증을 기록한 뒤 changed=true를 반환한다. 그러나 collect_page는 HTTP 실패와 GET 성공 후 NO_RECORD에서 새 _result를 만들며 changed를 기본 false로 버렸다. 새 facade의 unchanged 실패 rollback이 그 실제 관측까지 지웠다.

수정은 collect_page의 두 반환에서 기존 네 번째 인수로 response.get("changed", false)를 전달하는 것뿐이다. HTTP/NO_RECORD 실패 자체와 결과 code는 유지한다. 정적 페이지 실패는 여전히 false이므로 호출 전 checkpoint로 돌아가고, 실제 GET 변경은 기존 _finish_action의 canonical-source/world 검증과 전체 v2 예산 검사를 통과한다. _archive 단계, ARCHIVE_LIMIT/STATE_BUDGET의 transaction 원복 정책과 저장 스키마는 수정하지 않았다.

실제 비교는 public intruder의 기존 perspectives_solutions.json A경로 행동으로 M23까지 필수 선행 사건을 재생한 뒤 M24를 선택한다. 그 얻어진 정상 스냅샷을 검증된 restore_snapshot으로 분기한다. 완료·자료·권한·정책·모델 상태를 주입하지 않는다.

- 익명 GET https://control.packet.test/tickets/C731: 실제 object_read endpoint의 HTTP401.
- 실제 examiner/final-map HTTP login으로 얻은 origin cookie 뒤 GET https://control.packet.test/tickets/SECRET: 실제 HTTP200이나 collectible page 정의가 없어 수집은 NO_RECORD.
- 각 조건에서 legacy collect_web(url)와 explicit terminal2를 request(GET, browser)와 비교한다. 모두 실제 pending terminal3 인증을 만들고 정상 home browse로 선택 terminal의 lazy authentication cache를 같은 상태로 정착시킨다.
- GET 영수증 정확1개, 전체 checkpoint(world/selection/pending/authentication) strict equality, 원본/로컬 파일·미완료 상태 보존, v2 정확9키, 실제 고유 슬롯 save/load를 확인한다. 첫160검사의 actor/cookie/권한/ordinary failure/512/near2MiB 경계는 그대로 포함한다.

| 단계 | 실제 결과 | 판정 |
|---|---|---|
| red | 366검사/4실패, 종료1, 1.743초, 엔진 오류0 | HTTP401: request는 receipt1/changed=true, 두 collect 경로는 receipt0/changed=false |
| first-patch | 366검사/1실패, 종료1, 1.834초, 엔진 오류0 | HTTP 실패 전달로 receipt1 회복. legacy 비교의 lazy authentication cache 초기조건 차이라는 QA 오류 발견 |
| no-record-red | 414검사/4실패, 종료1, 2.840초, 엔진 오류0 | 정상 home browse로 QA 초기조건을 맞춘 뒤 HTTP401 양 경로 strict equality 통과. HTTP200→NO_RECORD 두 경로만 receipt0/changed=false로 실패 |
| green | **414검사/0실패, 종료0, 2.680초, 엔진 오류0** | 두 approved 반환 수정 뒤 네 비교 모두 receipt1/changed=true와 전체 checkpoint strict equality 통과 |

QA 교정은 비교를 world 일부로 축소하거나 authentication 검사를 제거하지 않았다. 실제 공개 browse 행동을 양쪽에 동일하게 추가했으며, 마지막 GREEN도 전체 checkpoint를 비교한다. 모든 실행에서 기본 settings/실제 campaign 슬롯/sidecar28경로 지문이 유지됐고 표적 프로세스는 종료됐다.

M06 public response endpoint는 direct/gateway 모두 POST /sign-in이다. collect_page의 고정 GET은 해당 endpoint와 일치하지 않으므로 이 재현으로 M06 login counter/cooldown 소거를 입증했다고 주장하지 않는다. 이번 실제 증거는 M24 response 관측/행동 영수증 보존이다. 새 canonical record, goal policy 또는 약화한 권한 조건은 없다.

로그/전후18파일 SHA는 .omx/artifacts/browser-context-followup/{red,first-patch,no-record-red,green}.{log,json}에 있다. 각 실행 중 core15파일+test+기존 fixture2파일 지문은 동일했다. 마지막 no-record-red→green은 Runtime만 달라졌고, HEAD 대비 Runtime diff는 승인한 collect_page 두 줄뿐이며 diff --check를 통과했다.

최종 SHA256: campaign_game.gd `302eabb9e3cd611a50e61cce402eca7ba469c649ff56b4c7ecf6ca479db9d762`, campaign_runtime.gd `7fac7ec950516060adda94f9b3edcf31305a00a69936e165be27a6ebd0c7362f`, test_browser_context.gd `64af1ea1079de8d4806ca0e26a8c5d883820783159e54f56e7d9cbb69f2857d8`.

이 후속은 source/표적 headless API·disk 검증이다. 새 이야기 완주나88개 전체 경로, native/UI 입력, 물리 IME, 전체 gate/import/export/패키징은 실행하지 않았으며 Root 통합 검증 범위다. 코어/회귀 소스는 이 GREEN에서 동결했다.
