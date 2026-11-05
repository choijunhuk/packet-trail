# 전체판 UI 통합 독립 검토 — 2026-11-05

판정: **REVISE — 중요 소스 결함 3건. Critical 없음.**

검토자는 제품 코드를 수정하거나 Godot·export·설치·실사용 저장/설정 조작을 실행하지 않았다. 아래 세 건은 현행 호출 경로에서 확인한 소스 결함이며, 실제 GUI 재현 완료를 뜻하지 않는다. 리더가 수정 후 격리 슬롯으로 동작 회귀를 확인해야 한다.

## 범위와 증거

- 직접 읽음: `campaign_desktop.gd` 전체 앱/입력/수명 경로, `full_game.gd`, `room.gd`, `settings_panel.gd`, `settings_store.gd`, `localization.gd`, `capture_full_game.gd`.
- 필요한 교차 확인만 읽음: `campaign_game.gd`의 요청·도구·읽기 모델·저장 API, `campaign_runtime.gd`의 터미널·공개 도구 관찰 모델, `audio_director.gd`, UI 원문 문자열, `project.godot`.
- 리더 제공 자동 검증: 기존 336, 전체 캠페인 31,717 / 56 해법, 콘텐츠 81, presentation 275, portraits 36, Python 35, 경계 5 PASS. 이 검토에서 재실행하지 않았다.
- 직접 읽은 `.omx/artifacts/full-production/native-full-first.log`: 35 checks, 실패는 `new game enters the real campaign desktop` 1개. 메뉴/설정 PNG 메타데이터만 기록되어 있고 이후 캠페인 GUI 검증은 실행되지 않았다.

## 중요 소스 결함

### UI-01 — 인증 취소/세계 교체가 미제출 암호를 평문 명령으로 바꾼다

- 위치: [`campaign_desktop.gd:1813`](../../godot/scripts/apps/campaign_desktop.gd#L1813), [`:1821`](../../godot/scripts/apps/campaign_desktop.gd#L1821), [`:1829`](../../godot/scripts/apps/campaign_desktop.gd#L1829), [`:4258`](../../godot/scripts/apps/campaign_desktop.gd#L4258).
- 분류/확신: **Important, 소스 결함 확인, high**. 가상의 게임 암호 문제이며 실제 자격 증명 유출 주장과는 구분한다.
- 재현 조건: 터미널에서 SSH 암호 입력 상태가 된 뒤 미제출 문자열을 입력하고 상단 `연결 종료` 버튼을 누른다. 버튼 설명도 인증 대기 취소를 약속한다. 또는 암호 입력을 남긴 채 F10 → 메뉴 → 확인된 새 게임/명시적 불러오기를 수행한다.
- 원인: `Escape` 경로는 `input.clear()` 후 취소하지만, `_term_exit()` → `_term_cancel_auth()`는 입력을 지우지 않고 `_refresh_all()`만 호출한다. `_refresh_terminal()`은 코어의 `password_pending=false`를 읽어 `input.secret=false`로 바꾸면서 같은 문자열을 남긴다. `_install_game()`의 캐시 초기화도 터미널 입력을 비우지 않는다.
- 효과: 미제출 암호가 화면에 보이는 일반 명령 초안이 된다. 다음 Enter는 그 문자열을 일반 명령 히스토리에 추가할 수 있다.
- 최소 수정: 공통 `_refresh_terminal()`에서 암호 모드가 켜진 입력을 비암호 모드로 전환할 때 입력을 먼저 지운다. 필요한 `hist_idx`/`draft`만 함께 초기화한다. 같은 세계의 Continue, 창 닫기/다시 열기, 정상 명령 초안은 그대로 보존한다.
- 검증: (1) 암호 초안 → 연결 종료, (2) 암호 초안 → 새 게임, (3) 암호 초안 → 저장 불러오기를 각각 검사하여 입력 비움·비암호 모드·히스토리에 초안 없음 확인. 기존 Escape 취소 및 방 왕복 시 일반 초안 보존 회귀도 유지한다.

### UI-02 — 도구가 표시한 기본 요청 주체와 실제 실행 터미널이 달라진다

- 위치: [`campaign_desktop.gd:1259`](../../godot/scripts/apps/campaign_desktop.gd#L1259), [`:1228`](../../godot/scripts/apps/campaign_desktop.gd#L1228), [`:2840`](../../godot/scripts/apps/campaign_desktop.gd#L2840), [`:3241`](../../godot/scripts/apps/campaign_desktop.gd#L3241).
- 분류/확신: **Important, 소스 결함 확인, high**.
- 재현 조건: 서로 다른 주체의 T1/T2 세션을 만든다. T1이 활성일 때 permission/idor/session/auth/csrf 도구를 열어 주체 라벨을 만든다. T2를 활성화하고 도구 창으로 돌아온 뒤 일반 실행을 누른다.
- 원인: `_activate()`가 `active_term`과 `last_view`를 T2로 바꾸면서 `_refresh_top()`만 호출한다. `_open_app("tools")`도 문맥을 다시 그리지 않는다. 주체 라벨을 갱신하는 `_tool_update_context()`는 이 경로에서 호출되지 않지만, `_tool_run()`은 실행 시점의 `active_term`을 사용한다.
- 효과: 화면은 T1의 `user@host`를 기본 주체라고 안내하면서 실제로는 T2로 실행한다. 권한/세션 추론이 핵심인 게임에서 관찰과 결과를 잘못 연결하게 한다. 다음 행동의 전체 갱신 뒤에는 라벨이 바뀌므로 첫 실행 전 불일치가 핵심이다.
- 최소 수정: 활성 터미널이 바뀌는 지점에서 현재 읽기 모델로 선택 도구의 문맥도 갱신한다. 기존 `_refresh_tools()`/`_tool_update_context()`를 재사용하며 입력 초안과 포커스를 재생성하지 않는다.
- 검증: 서로 다른 T1/T2 주체로 전환하고 아무 도메인 행동도 실행하기 전에 도구 라벨이 T2와 일치하는지 검사한다. 그 다음 실행의 실제 주체/결과도 T2와 일치하는지 확인한다.

### UI-03 — FileLens/LogLens와 호스트 후보가 처음 선택한 관찰에 고정된다

- 위치: [`campaign_desktop.gd:2768`](../../godot/scripts/apps/campaign_desktop.gd#L2768), [`:2811`](../../godot/scripts/apps/campaign_desktop.gd#L2811), [`:2864`](../../godot/scripts/apps/campaign_desktop.gd#L2864), [`campaign_runtime.gd:1089`](../../godot/scripts/core/campaign_runtime.gd#L1089).
- 분류/확신: **Important, 소스 결함 확인, high**.
- 재현 조건: FileLens/LogLens를 선택하여 현재 파일 후보 목록을 만든다. 같은 사건·같은 선택 도구를 유지한 채 터미널의 cwd/주체를 바꾸거나 현재 디렉터리에 가상 파일을 추가/삭제한다. 또는 NetProbe/TraceRoute 선택 상태에서 새 호스트를 발견한다.
- 원인: 코어의 일반 도구 `data.files`는 현재 읽을 수 있는 cwd 목록이며 `data.targets`는 현재 발견 호스트 목록이다. UI는 `_tool_show()` → `_tool_build_obs()`에서만 이를 그린다. `_refresh_tools()`는 미션/도구 ID/언어만 식별하고 기존 선택 도구에는 `_tool_update_context()`만 실행한다. 데이터가 달라져도 관찰 목록을 다시 만들지 않는다. 창을 닫고 같은 도구를 다시 여는 경로도 이를 갱신하지 않는다.
- 효과: `현재 위치에서 보이는 항목`으로 표시된 후보가 이전 cwd/계정의 파일을 계속 보여 주거나 새로 발견한 호스트를 누락한다. 입력을 클릭해 채우는 경로도 오래된 항목에 묶인다. 다른 도구를 선택했다 돌아오면 갱신되어 일시적 캐시 결함임을 확인할 수 있다.
- 최소 수정: 선택 도구의 공개 `data`가 달라졌을 때 관찰 부분만 기존 `_tool_build_obs()`로 다시 그린다. 터미널 전환도 현재 읽기 모델을 사용해야 한다. 입력/결과 전체를 매 행동마다 재생성할 필요는 없다.
- 검증: FileLens 선택 → cwd 변경, 가상 파일 추가/삭제, 다른 계정 터미널로 전환 후 파일 후보를 `get_view(active_term).tools`와 대조한다. NetProbe/TraceRoute는 실제 발견 행동 전후 후보를 대조한다. 입력 초안 보존·선택 도구 유지·실행 결과 유지도 검사한다.

## 결함으로 판정하지 않은 사항

- **확인창 클릭 실패 — harness/API 가설:** 첫 로그가 데스크톱 생성 전 중단됐다는 사실만 확인된다. 제품의 `confirmed` → `open_desktop(_pending_action)` 연결은 존재한다. 합성 입력의 자식 Window 마우스 진입/좌표/hover/모달 처리는 harness 담당자가 수정 중이다. 버튼 신호를 직접 호출해 통과시키거나 제품 성공으로 해석하면 안 된다.
- **종료 자원 경고 — 미확정:** 같은 즉시 종료 로그에 ObjectDB 12 / resource 4 경고가 있다. 실제 제품 객체의 반복 수명 누수인지, 실패한 harness의 대기 타이머/참조/종료 정리인지 분리되지 않았다. 제품 오디오는 scene 자식 노드로 생성되고, 검토 범위에서 명백한 영구 signal/resource cycle은 찾지 못했다. 이 검토는 실행하지 않았으므로 누수 없음도 주장하지 않는다.
- **저장 경로 주입 — 소스 연결 확인:** full root가 `room.desktop_save_slot_path`를 room의 `add_child()` 전에 설정하며, room은 `instance.save_slot_path`를 desktop의 `add_child()` 전에 설정한다. desktop `_ready()`의 Campaign 생성보다 먼저 경로가 전달된다. 메뉴 부팅은 세션을 암묵적으로 시작하지 않는다.
- **네 터미널 — 소스 분리 확인:** `_build_terminal(t)`마다 별도 입력·history·hist_idx·draft·last_frame·pw 딕셔너리가 생성된다. 제출/인증/완성은 해당 `t`로 전달된다. 같은 세계의 방 왕복과 창 닫기는 인스턴스를 유지한다. UI-01은 이 분리 자체의 결함이 아니라 암호 모드 종료 처리의 결함이다.
- **설정/일시정지 — 검토 범위에서 추가 중요 소스 결함 없음:** 데스크톱 입력은 상위 설정창이 있으면 반환하고, 설정창 내부 Tab 순환과 Escape 종료 경로가 있다. 일시정지는 도메인 행동을 막고 오디오 pause 신호를 전달한다. 실제 native 포커스·IME·모달 상호작용까지 검증한 것은 아니다.
- **현지화 — 소스 갱신 연결 확인:** 설정 변경은 shared locale → UI 등록 문자열 → 새 코어 읽기 모델 → 메일/보드/보관함/결말로 이어진다. 기존 브라우저 응답은 stale 안내를 띄운다. 번역 품질·모든 크기에서의 잘림·물리 IME는 이 소스 검토로 판정하지 않는다.
- **합법적 제한:** 핀/비교/메모는 UI 보조이며 저장·완료 조건으로 쓰이지 않고 메모는 session-local로 표시된다. 물리 IME, 사람 플레이 시간·읽기 속도·균형, 장시간 청취, Windows/Linux GUI는 별도 검증이다.
- **관찰된 추가 낮은 위험:** RequestLab 응답/최근 요청과 Files 본문은 세계 교체 때 명시적으로 비워지지 않는다. 역사적 응답을 유지할 수 있는 UI이므로 이 검토에서는 이를 새 Important 결함으로 올리지 않았다. 향후 현재 자료처럼 안내하는 문제가 실제 플레이에서 재현되면 초기화 또는 historical 표기를 검토할 수 있다.

## 소스 고정성 / SHA-256

아래 제품 6파일은 시작/종료 해시가 동일하다. 마지막 확인: `2026-11-05T02:28:19Z`.

| 파일 | 시작 = 종료 SHA-256 |
|---|---|
| `godot/scripts/apps/campaign_desktop.gd` | `b4fce72504546c147b997d5895ddac686a719cbd69ae69992ab3e7ba042ef853` |
| `godot/scripts/full_game.gd` | `068c4e22c75aa4cd208c758d1eea788bac0aa5e1f25c5368b4bf8995e6538a66` |
| `godot/scripts/room/room.gd` | `c502657baba851a16f4fdfd8efa8215ba823eb8a1f385ef5c2d31213a5da1a3a` |
| `godot/scripts/presentation/settings_panel.gd` | `354cdd86789c8d15b337465603af240e07cbaaba51c84e02f7bf7f5dc6291bf5` |
| `godot/scripts/presentation/settings_store.gd` | `505b85b02f897d8366b19776c3d9a2774e8a05fe1c38ccf228011550ef49a8de` |
| `godot/scripts/presentation/localization.gd` | `491398b80550f727a3bd518d1f1c74b6037edf21265143ed00eca71decc10b4d` |

`godot/tools/capture_full_game.gd`는 담당자의 병행 수정으로 검토 중 바뀌었다: 시작 `96e4a6dad57fbeb1fce569c35ac33dfeecdb02f89b44d9d0a7166fa5e0ddf270`, 마지막 확인 `86ab5740bdafdf07340f57c5effa47d6a6b406c563e65ab0edc91d35dd0e8f62`. 이 보고서의 harness 평가는 위 첫 로그와 읽은 시점의 소스 범위로 한정한다. harness 최신본의 PASS를 뜻하지 않는다.

교차 확인 파일의 읽은 시점 해시: `campaign_game.gd` `00baeaec1facff560cea6540952769cc1b8b8fb953f947b57c1ed6cbbd225a5d`, `campaign_runtime.gd` `72f05cf1181b9cb65ef3f18c122c6a5c2899a27e2625643bd6e00d4d95858571`, `audio_director.gd` `727667cd1363e5448cb814824d50a2a1ef1188c7c1d082f323ec2c6c3867ddda`. 검토 시작 전 해시를 수집하지 않은 교차 확인 파일은 전체 검토 시간 동안 불변이었다고 주장하지 않는다.

## 인계

리더가 세 결함을 수정하고 위 좁은 회귀를 추가한 뒤 native 캡처를 재실행한다. 본 보고서 외 제품 파일 수정은 0개다. 구현 단순화는 수행하지 않았으며, 최소 수정 제안은 기존 갱신 함수 재사용과 암호 모드 종료 처리에 한정한다.
