# 1.1 세 관점 · UI 구현 기록

작업 트리: `packet-trail-expansion` / `feat/three-perspectives`, 기준 `0565166`.
기준 계약은 DESIGN의 활성 절과 `.omx/plans/prd-three-perspectives-20261105.md` 및 test spec이다.

## 구현 순서와 경계

1. 역순환과 동적 Control 등록 누적을 먼저 고친다.
2. catalog의 공개 3팩·별도 슬롯·이전판 재개를 메뉴와 session API에 연결한다.
3. response/observation/branch 도구는 의미 있는 필드·관측표·조치/되돌리기·가설/trace를 제공한다.
4. 역할·장별 기존 7개 mood 매핑과 UI 키를 연결한다.
5. 큰 구현 묶음 뒤 root가 전체 gate/native/Cua/visual 검증한다. 편집마다 전체 build를 반복하지 않는다.

세계 상태·권한·판정·저장은 코어만 소유한다. UI는 사용자 저장 파일을 직접 읽거나 새 경로를 만들지 않는다.
암호 clear-before-unmask, pause/focus, 4터미널, 구판/설정 보존, 테스트 슬롯 주입은 유지한다.

## 먼저 확인한 회귀

- QA RED: 열린 4창에서 역순환 8회가 help/term0 두 창만 오갔다.
- QA RED: 40 refresh 뒤 sized 312→1512, 폐기 Control 1245개가 남았다.
- 근거: `.omx/artifacts/expansion-qa/mutation-first-red.log`; headless 기능 호출이며 native 입력 검증과 구분한다.
- 수정: 창 쌓임 대신 wins 등록 순서로 양방향 순환한다.
- 수정: 같은 Control의 `_size` 등록은 갱신하고, `_clear_children`이 detach 전에 sized/i18n 등록을 제거한다.
- QA GREEN: `mutation-ui-fixed.log`에서 UI 실패 0, 양방향 4창 도달, sized 267→267/dead 0, 기본 슬롯/설정 보존 PASS.
- 당시 전체 1148검사 중 남은 22실패는 별도 코어 회귀이며 UI GREEN을 전체 gate 통과로 표시하지 않는다.

## 캠페인 선택과 저장 경계

- `Room.campaign_picker`는 실제 OptionButton이며 각 item metadata가 `intruder/defender/tracker`다. 표시 언어와 무관하게 실제 InputEvent로 검증할 수 있다.
- 목록은 `Catalog.list_packs()`를 읽은 bootstrap이 제공한다. 선택 자체는 게임 시작·저장 쓰기를 하지 않는다.
- bootstrap `save_slot_path=""`는 고정 제품 슬롯을, 주입된 테스트 base는 `Catalog.test_slot(base,id)`로 파생한 팩별 테스트 슬롯만 사용한다.
- `Room.campaign_slots`의 경로와 `pack_id`는 desktop instantiate 뒤 add_child **전에** 주입한다. 빈/불허 테스트 경로는 기본 사용자 슬롯으로 fallback하지 않는다.
- 팩별 desktop 인스턴스를 보존해 메모리 진행·인증·4터미널 초안이 섞이지 않는다. 신호는 인스턴스당 한 번 연결하고 숨은 팩의 음악/일시정지 이벤트는 무시한다.
- 디스크 저장과 메모리 이어하기는 구분한다. 저장이 없지만 메모리 진행이 있으면 Continue만 가능하고 Load는 켜지지 않는다.
- 이전판은 공개 선택 목록에 넣지 않고 continuation/검증된 원본이 있을 때 별도 ‘이전판 계속’으로 제공한다. 원본을 발견했지만 검증할 수 없으면 코어의 발견/사유 projection으로 비활성 안내를 보여 주며 ‘저장 없음’으로 숨기지 않는다.
- continuation 로드가 손상이면 원본으로 되돌리지 않는다. SAVE_NOT_FOUND이며 백업도 없는 제품 legacy 경로에서만 코어의 명시적 원본 이어하기를 요청한다.
- 테스트 메뉴는 `get_save_status(false)`로 실제 이전 원본을 자동 probe하지 않는다. UI legacy fallback도 테스트 슬롯에서는 고정 사용자 원본을 읽지 않는다.
- v1 M01 가져오기는 legacy 팩으로만 보낸다. 새 세 캠페인의 완료/학습 성취로 승격하지 않는다.
- 새 진행/가져오기는 확인 후 진행한다. 취소·설정 닫기·선택 위젯 재생성 뒤 키보드 포커스를 복원한다.

## 구조화 도구 폼

세 kind는 `response_lab`, `observation_case`, `branch_vm`이다. 기본 입력은 core의 public `actions/fields/options`이며 고급 JSON 입력은 선택 기능으로 유지한다.

| 항목 | 실제 UI API |
|---|---|
| 동작 | `tool_inputs["action"]` OptionButton, item metadata는 canonical action ID |
| scalar | field ID의 LineEdit/CheckBox/SpinBox/OptionButton |
| object | `claim.kind`, `claim.left`, `values.format_ok` 같은 leaf key의 Control; 전송은 중첩 Dictionary |
| array/multi_enum | ItemList.SELECT_MULTI, 각 item metadata의 canonical ID 배열 전송 |
| enum | 번역 label과 전송 ID를 분리. 문자열·정수·불리언 값을 metadata로 유지 |
| 동작 전환 | 선택 callback이 현재 초안을 저장하고 폼을 다시 만든다. 자동화는 이후 새 Control 참조를 다시 읽어야 함 |

폼은 `bool/int/enum/string/array/object`와 object의 재귀 fields, int min/max, secret 표시를 지원한다. 비밀 입력은 초안 저장에서 제외하고 실행 후 지운다.
대응은 controls/matrix/checkpoints/probe_receipts/business_objects/artifacts/artifact_events, 추적은 sensors/observations/hypotheses/history, 분기는 listing/call_graph/trace/outputs 표를 표시한다.
업로드 객체의 현재 execution_allowed와 과거 execution_allowed_at_upload를 다른 열로 표시한다. 격리·해제는 공개 artifact_id 선택과 quarantined 체크박스로만 코어에 전달하며, 체크박스는 공개 schema의 default를 존중한다. 정상 객체 보존·현재 정책·완료 판정은 코어 소유다. VM inspect.section도 공개 enum(listing/call_graph/trace)만 사용한다.
실제 projection의 entities/initial_claims/VM cases도 표시한다. 초기 전달 가설은 공개 id/label/claim/source_id만, VM은 입력 대기/실행 중/실행 종료와 실제 단계·예산을 보여 준다. 프로그램 종료를 사건 해결로 표시하지 않는다.
CALL은 owner_function의 현재 위치와 function의 실제 호출 대상을 구분하고 from/to 그래프를 그대로 보여 준다. 숨은 outcomes나 예상 정답을 추가로 가져오지 않는다.
표의 행을 키보드로 선택하면 줄바꿈 상세를 읽을 수 있다. 표·폼에 없는 저자용 hidden answer나 원본 definition을 UI에서 추가로 읽지 않는다.
상태 badge와 사람용 label만 번역하며, 같은 문자열이라도 ID/프로그램 label/주소/원자료 값은 canonical로 보존한다.
실행은 기존 `_act → game.use_tool(id, params)`만 사용한다. terminal_id는 선택한 터미널이며 성공·관측·정책·가설 판정은 코어가 소유한다.

## 음악 연결

기존 7개 mood를 유지한다. 실제 결말 선택·크레딧 전경 문맥에서 ending을 사용하고, 그 밖에는 경보→완료→사건 순서다. 역사적 ending 저장값만으로 피날레를 재생하지 않는다. 조사 단계도 flow/reveal을 역할·장별로 분산한다.
처음 M01/M02/D01/T01은 intro, 주요 전환·장말은 reveal, 진행력이 필요한 침투/대응·추적 구간은 flow, 나머지 해석은 investigate다.
작업실은 home이며 ending의 one-shot·같은 mood 반복 시 재시작 방지는 AudioDirector 계약을 따른다. UI에서 새 트랙·게임 규칙을 추가하지 않는다.

## 현재 표적 검증과 남은 확인

- 소유 desktop/room/bootstrap `--check-only` 3개 PASS, 엔진 문법 오류 없음.
- 세 구조화 폼의 실제 product serializer로 enum/bool/int/object/array를 확인한 headless 위젯 fixture 3개 PASS. 게임 판정·native 입력 증거는 아님.
- 실제 bootstrap/메뉴의 3편 metadata·4개 고유 tests 슬롯·선택 변경·자동 시작 없음·기본 파일 SHA 보존 10개 PASS.
- 위 bootstrap 표적은 AudioStreamPlayer 정지/stream 해제·프레임 정리 후 누수/엔진 ERROR 없이 끝났다. 최초 너무 빠른 probe 종료에서 보인 오디오 정리 경고와 구분한다.
- 최초 조회의 `Campaign content unavailable` 상태는 작성 중 이력이었다. 이후 세 공개 팩의 실제 `ready=true`와 Core 모델 projection을 확인했다.
- 실제 공개 모형 3개/동작 19개의 표·폼·직렬화와 canonical ID 보존을 headless 22검사로 확인했다. 게임 행동이나 저장을 실행한 검사는 아니다.
- 테스트 슬롯에서 실제 UI 메서드로 세 편 새 시작·저장, 팩별 Node/초안 보존, 디스크에 없는 가상 메모리 상태를 Continue가 재로드하지 않는 것, 기본 사용자 파일 SHA 보존을 7검사로 확인했다. 테스트 파일은 정리했다.
- D04 공개 객체 표/격리 폼 보완은 generic 위젯 6검사 PASS: schema bool 기본 true, 명시 선택한 객체 ID와 true/false 전송, false 초안 보존, event 번역과 canonical ID 보존. 임시 probe는 삭제했고 이 위젯 검사는 게임 행동·저장을 호출하지 않았다.
- 실제 D04/R01 Core/public projection과 기본 폼의 후속 headless 기능 검사 35/0 PASS, exit 0, 엔진 오류 없음. D04 취약 업로드를 메모리에서 관측한 뒤 두 공개 표의 현재/수락 당시 허용 일치, 정책 수리 후 현재 false·과거 true 분리, 격리 true/false의 실제 코어 수신과 false 초안 보존, 과거 이벤트 불변을 확인했다. R01 세 inspect enum은 실제 코어의 해당 section/rows로 응답했다. 소스 8개 SHA·기본 저장/백업/설정 28경로 불변, 테스트 슬롯 미작성, 임시 probe 삭제. 로그는 `/private/tmp/packet-trail-ui-actual-public-target.log`; native 입력 증거가 아니며 전체 native 재검증은 통합 담당의 별도 실행이다.
- 44사건 전체 플레이·legacy 이동·복구의 세부 도메인 판정과 실제 폼 입력 이벤트는 root의 통합 검증이다. 위 표적 검사 수를 그 증거로 확대하지 않는다.
- 큰 글씨/6언어/작은 화면/native/Cua/시각 판정·전체 gate/export·실제 3OS는 root의 다음 묶음이다. 이 문서는 그 검증을 PASS로 선언하지 않는다.

## C22 세션·음악 문맥 회귀 수리

- 작업실 E는 마지막 **성공한** 세션의 실제 팩·슬롯·캐시 인스턴스를 명시해 재개한다. 공개 캠페인 선택값은 그대로 유지되며 메뉴의 계속/새 게임/불러오기는 그 선택을 따른다. 이전판 또는 가져온 이전판 세션을 공개 침투자 세션으로 바꾸지 않는다.
- 활성 메모리 세션의 메뉴 불러오기는 기존 `UI_CONFIRM_LOAD` 확인을 재사용한다. 자동저장 중단 후 만든 가상 디렉터리·현재 위치도 승인 전에는 유지된다. 확인은 당시 팩을 캡처하며 취소하면 실행 목적을 지운다.
- 성공한 세계 설치 때 UI `session_generation`이 바뀌고 이전 확인 callable을 비운다. 방에서 보관한 Window는 같은 세대일 때만 다시 보인다. 같은 세계의 F10/E에서는 정상 확인창과 초안이 유지되며, 새 게임/불러오기 후 이전 복구·확인 동작이 실행되지 않는다. 이 세대 값은 UI 수명 정보로 저장 상태나 코어 판정에 넣지 않는다.
- 데스크톱 `presentation_context_changed(app_id)`는 실제 전경 앱 활성화·전경 닫힘을 알린다. 결말 선택과 명시적 크레딧 열기는 ending을 한 번 재생하며 같은 문맥의 반복 view는 재시작하지 않는다. 사건 보드·새 사건·새 경보·작업실 왕복은 문맥을 끝내고 정상 mood로 돌아간다. 배경 앱 닫힘은 전경 크레딧을 새로 연 것으로 취급하지 않는다. AudioDirector의 7개 mood와 one-shot 구현은 바꾸지 않았다.
- 회귀 모듈은 `res://tests/headless/test_ui_context.gd`의 `await Tests.new().run(scene_tree)`이며 `{checks, failures, protected_paths, limit}`를 반환한다. runner/gate 연결은 통합 담당 소유다.
- 수정 전 실제 headless RED는 33검사 중 16실패로 네 지적을 확인했다. 수정 과정의 배경 앱 닫힘 RED도 별도로 확인한 뒤 최종 37검사/0실패, exit 0, 엔진 경고·오류 0으로 검증했다. 소스 8개 SHA와 기본 저장/백업/설정 28경로는 전후 동일하고 테스트 파일은 고유 `user://tests/ui_context_*`에서 정리했다.
- 기존 `test_mutation_limits.gd`도 표적 재실행하여 1,217검사/0실패, UI registry 267→267/dead 0을 확인했다. 새 수리가 기존 양방향 창 순환·반복 새로고침 보호를 깨지 않았다.
- 증거 로그: `/private/tmp/packet-trail-ui-context-red.log`, `/private/tmp/packet-trail-ui-context-background-red.log`, `/private/tmp/packet-trail-ui-context-green.log`, `/private/tmp/packet-trail-ui-context-mutation-regression.log`. 실제 장치·native 입력·렌더링·청취 검증은 아니며 전체 native 재실행은 통합 담당의 후속이다.
