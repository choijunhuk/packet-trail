# Midnight OS 데스크톱 셸 구현

상태: 첫 소스 묶음 작성, 2026-11-06. `feat/desktop-experience` 전용이다. 실제 import·실행·렌더·패키지 검증 전이며 1.1 완성 상태와 혼동하지 않는다.

## 적용한 계약

- `DESIGN.md`와 `2026-11-06-desktop-experience.md`의 짙은 파랑·회색 Midnight OS를 구현한다.
- 기존 CampaignGame, 권한·쿠키·단말·풀이·저장 판정은 유지한다. UI 선호를 world snapshot에 추가하지 않는다.
- 앱과 네 터미널의 실제 Control, 공개 세션 API와 신호를 재사용한다. 별도 OS·실제 브라우저·웹뷰·셸·실인터넷을 도입하지 않는다.
- 공통 `desktop_theme.gd`의 create/panel/색 상수를 사용한다. 그 파일은 이 레인에서 수정하지 않았다.

## 셸과 창

- 직접 작성한 기하학 야간 벽지 SVG와 30개 UI 심벌 SVG를 사용한다. 격자 Backdrop 클래스는 제거했다.
- 바탕화면에는 메일·Nightfox·터미널·파일·도구·사건 보드 아이콘이 있다. 아이콘 버튼은 키보드 포커스·접근성 이름·툴팁을 가진다.
- 런처는 이름·설명·앱 식별자로 검색하며, 모든 앱·선택형 힌트·설정으로 이어진다. 검색 Enter는 첫 활성 결과를 연다. Esc는 런처를 닫는다.
- 작업표시줄에는 닫히지 않은 창만 표시한다. 활성 창의 아이콘을 다시 누르면 최소화하고, 최소화/비활성 아이콘은 복원·활성화한다.
- 바탕화면·런처의 앱 실행은 항상 열기/복원이다. 작업표시줄의 최소화 토글과 의미를 구분한다.
- 창의 이동·우하단 크기 조절·제목줄 더블클릭/최대화·복원·닫기를 보존했다. 제목줄에는 직접 작성한 앱/창 조작 아이콘을 쓴다.
- 닫기와 최소화는 Control이나 코어 세션을 파괴하지 않는다. 초안·터미널 객체·현재 세션·창 위치/크기가 메모리에서 유지된다.
- 새 게임은 창을 닫힌 데스크톱으로 초기화한다. 모든 창을 닫거나 최소화한 뒤 F10/E로 재개해도 과거의 메일/보드/터미널 세 창을 강제로 다시 열지 않는다.
- 실제 저장 불러오기·백업·구판·확인창 세대·정상 종료 경로는 기존 통합 계약을 그대로 사용한다.

## 지원 수준

`apply_settings(values)`가 현재 팩의 `support_intruder`, `support_defender`, `support_tracker`를 읽는다. 값은 `guided`, `standard`, `independent`이며 누락·구판은 standard다.

| 수준 | 자동 표시 | 수동 도움 |
|---|---|---|
| 가이드 | 새 시작/새 미완료 사건에서 메일 한 개와 공개 첫 방향을 한 번 표시 | 사건 보드/런처의 단계 힌트 |
| 표준 | 바탕화면 새 의뢰 알림·메일 배지, 자동 앱 개방 없음 | 요청형 단계 힌트 |
| 자율 | 최소 알림과 메일 배지, 자동 앱/힌트 없음 | 동일한 수동 힌트 접근 |

- 자동 안내는 UI 세대+사건 키로 중복을 막는다. 사용자가 행동을 시작한 뒤 지원 설정을 바꿔도 같은 사건의 창을 계속 전면화하지 않는다.
- 불러온 진행·기록된 사건·선택된 역사적 결말은 자동 안내 창의 근거가 아니다. 재개에서도 전경 창을 빼앗지 않는다.
- 자동 첫 힌트는 공개 view의 hints[0]을 표시한다. `get_hint`, 목표 완료, 경보, 권한 변경을 호출하지 않는다.
- 사용자가 명시적으로 요청한 힌트는 기존 사건 보드의 단계를 사용한다. 자율에서도 막지 않는다.
- 알림 본문은 스크롤하며 닫을 수 있다. 새 의뢰·지원 수준은 사람이 읽는 번역 문구로 표시한다.

## Nightfox 탭과 요청 주체

- 실제 TabBar와 새 탭/닫기 동작이 있으며 상한은 8개다. 탭당 URL 이력은 64개로 제한한다.
- 각 탭은 편집 중 주소, 현재 페이지 URL, history/cursor, 폼 메서드·필드·값·사용자명, 펼침 상태, 최근 응답과 응답 단말·알림을 독립 보관한다.
- 탭을 바꾸는 동작 자체는 HTTP를 보내지 않는다. 뒤로/앞으로/새로고침/홈/주소 제출·링크는 기존 가상 코어 요청을 사용한다.
- 마지막 탭을 닫으면 Nightfox 창을 닫고 다음 실행용 빈 탭을 마련한다. 창을 일반 닫기/최소화한 경우 기존 탭은 유지된다.
- 탭 전환 때 로그인 비밀번호 입력을 지운다. 비밀번호는 탭 상태나 UI 저장에 보관하지 않는다.
- 새 GET은 `game.browse(url, active_term)`, 폼/로그인/로그아웃은 `game.request(..., active_term)`, 회수는 `game.collect_web(url, active_term)`을 사용한다.
- 현재 요청 터미널의 사용자/호스트와 보관된 응답의 터미널/서버 actor를 따로 표시한다. 단말 전환·세계 변화·인증 변화 후 다른 탭의 응답도 과거 응답으로 표시한다.
- stale 배너는 표시/사용성 정보다. UI가 별도 인가를 판정하거나 예전 응답의 actor를 현재 요청 주체로 강제하지 않는다. 실제 회수의 허용/거절은 명시한 단말의 코어 응답이 결정한다.
- 세계 교체 때 탭을 비우며 자동 HTTP로 새로고침하지 않는다. 사용자 명시 탐색에서만 새 응답을 얻는다.

## 키보드와 QA 참조

기존 Ctrl/Cmd+1..9 앱, Ctrl/Cmd+Shift+1..4 터미널, Ctrl+Tab/Shift 역순환, F1/F10/Pause·IME 가드를 유지한다. F6은 항상 존재하는 런처 버튼으로, Shift+F6은 글자 크기 축소 조작으로 이동한다. Nightfox 전경에서 Ctrl/Cmd+T/W/L은 새 탭/현재 탭 닫기/주소 입력이다.

| 참조 | 실제 제품 Control/metadata |
|---|---|
| `desktop_icons[id]` | 바탕화면 Button, app_id/launcher_action=launch |
| `launcher_button` | 런처 Button, launcher_action=toggle |
| `launcher_search` | 검색 LineEdit, launcher_action=search |
| `launcher_buttons[id]` | 앱 실행 Button, app_id/launcher_action=launch |
| `task_buttons[id]` | 실행 중 앱/term0..3 Button, app_id/launcher_action=restore_or_minimize |
| `term_task_buttons[0..3]` | 네 터미널의 실제 작업표시줄 버튼. terminal 키는 실제 버튼에 대한 호환 참조 |
| `wins[id].actions` | minimize/maximize/close Button, app_id/window_action |
| `new_terminal_buttons` | 제목줄의 다른 터미널 열기 Button, window_action=new_terminal. 최대 네 세션 |
| `font_down_btn`, `font_up_btn` | 실제 글자 크기 조작. 상단 A+ 글리프 검색 대신 사용 |
| `browser_tabs` | TabBar. 각 tab metadata는 id/url |
| `browser_new_tab_button` | Button, browser_action=new_tab |
| `br_addr` | LineEdit, browser_action=address |

`show_notice(message: String)`는 설정 저장 실패 같은 표시 메시지를 기존 알림에 전달하는 공개 API다. 코어 행동은 호출하지 않는다.

기존 `terms`, `tool_inputs`, 브라우저·사건 보드·저장 위젯 참조와 실제 앱 ID는 유지한다. 새 helper는 이 의미 참조로 대상을 찾되 활성화는 실제 engine InputEvent로 검증해야 한다. 숨은 테스트 전용 컨트롤·직접 신호 emit으로 native 성공을 대체하지 않는다.

## 문구·자산·검증 상태

- 새 KO/EN 원문은 `.omx/artifacts/desktop-copy/desktop.json`에 모았다. 제품 strings/PO는 locale 담당 소유다.
- 목표에 display_name이 없을 때 저자용 id/kind를 기본 설명으로 덤프하지 않고 필요한 결과라는 사람용 문구를 쓴다. 경로·계정·표시 대상 같은 기술 자료는 보존한다.
- 공개 표의 근거 fingerprint·판정 사용 가능 여부 등에는 사람용 필드 이름을 연결한다. 코어가 숨긴 정답/definition은 추가 조회하지 않는다.
- SVG 출처와 직접 작성 범위는 `godot/assets/ui/desktop/SOURCE.md`에 기록했다. 외부 로고·벽지·아이콘 팩·폰트·의존성을 추가하지 않았다.
- 현재 순수 정적 검사: SVG XML 31개, 새 KO/EN 48키와 보간/참조, 중복 함수 없음, diff whitespace 검사 PASS. 해당 Desktop 스크립트의 Godot check-only 최종 PASS, 엔진 오류 0. 최초 enum/Variant 추론 오류는 수정 후 재검사했다. 공통 Root 씬의 실행 검증은 아니다.
- 실제 UI 기능·1280/1600/큰 글씨/6언어·탭별 권한/로그인·실제 native 렌더·시각 판정·전체 gate/패키지/3OS는 통합 직렬 검증 전이다. 소스 작성만으로 완료라 주장하지 않는다.

## 첫 native 리뷰 후 제한 수리

첫 실제 리뷰는 방향 일치/84점·수리 필요였다. 실제 캡처에서 과거 응답 경고의 한 글자 열, 제목줄을 덮는 상단 알림, 언어 전환 후 남은 KO 일시 알림을 확인했다. 기능 helper의 정확한 입력 포커스 기대는 유지했다.

- 닫힌 런처의 닫기 호출은 포커스를 바꾸지 않는다. 실제로 열린 런처를 닫을 때만 런처 버튼으로 돌아간다. F10/숨기기 전의 실제 소유 포커스를 보관하며 숨김 중 런처 닫기는 포커스를 이동하지 않는다.
- Nightfox의 과거 응답 경고를 응답 주체 바로 아래 독립 전폭 행으로 옮겼다. 경고 자체와 페이지 영역은 스크롤할 수 있고 탭/탐색 행은 밖에 남는다. HTTP 상태/회수는 별도 footer를 유지한다. 코어 요청/권한 의미는 바꾸지 않았다.
- 알림은 작업표시줄 위의 크기가 제한된 영역에 표시한다. 현재 전경 제목줄과 겹치지 않는 위치를 선택하며, 지원 카드가 동시에 있으면 우선 위로 쌓고 가용 공간에서 분리한다. 전체 지원 내용과 알림은 스크롤·닫기가 가능하다. 만료된 알림도 상태 표시줄의 알림 버튼에서 다시 읽을 수 있다.
- Desktop의 마지막 표시 locale을 기억하여 비교한다. Room이 전역 locale을 먼저 바꾼 경우도 감지해 toast/상태와 탭의 일시 notice를 비운다. 실제 터미널/페이지 이력·응답·코어 snapshot은 유지한다. 새 번역 키는 없다.
- 수정 전 headless 실제 경로 14검사/5실패로 네 문제를 재현했다. 실제 Room._apply_settings 경로의 locale 선행 변경도 별도 RED 1건으로 확인했다.
- 최종 동일 표적 14/0, exit 0, 엔진 경고/오류 0. 정확 포커스·동일 인스턴스/world/draft, 경고 폭, 알림/제목줄·작업표시줄·지원 카드 경계, 실제 Room locale 전환과 이력 보존을 확인했다. 소스 9 SHA·기본 저장/설정 28경로는 전후 동일했고 고유 tests 파일은 정리했다.
- 로그: `/private/tmp/packet-trail-desktop-first-fix-red.log`, `/private/tmp/packet-trail-desktop-locale-root-red.log`, `/private/tmp/packet-trail-desktop-first-fix-green.log`. Desktop check-only PASS. 이는 headless 기능/geometry 증거이며, 수정 후 실제 픽셀의 시각 합격은 같은 preview 재캡처와 독립 fix review가 결정한다.

## 필수 명령 입력 보호와 C23 제목줄 포커스

후속 실제 픽셀 리뷰는 89점·수리 필요였다. 제목줄/언어 문제는 해결됐지만 최대화 터미널의 알림 Rect `(1144,722,440,108)`가 명령 입력 Rect `(287,778,1302,53)`와 교차했다.

- 입력 중 알림을 위로 옮겨 마지막 출력을 가리는 방식을 사용하지 않는다. Desktop 소유 LineEdit/TextEdit가 포커스를 가졌거나 터미널이 최대화된 경우 자동 알림은 기존 작업표시줄 상태·전체 tooltip·알림 버튼으로 축약한다.
- 사용자가 알림 버튼을 명시적으로 활성화하면 전체 내용을 스크롤·닫기 가능한 카드로 읽을 수 있다. 실제 텍스트 입력으로 다시 포커스를 옮기면 카드를 축약한다. Viewport의 실제 `gui_focus_changed` 신호를 사용하며 입력/세션/판정을 바꾸지 않는다.
- C23 M2는 실제 engine mouse press/release로 최대화 후 Button 포커스가 남고 문자/Space/Enter가 입력칸에 전달되지 않는 것을 재현했다. 새 터미널의 입력 복귀는 이미 정상이었다.
- 제목줄에 대한 마우스 동작일 때만 기존 입력 Control을 기억하고 조작 뒤 현재 전경 창의 원래 입력 또는 새 전경 입력으로 복귀한다. 버튼의 FOCUS_ALL을 제거하지 않는다. 명시적인 키보드 Space/Enter 제목줄 조작은 Button 포커스와 동작을 유지한다.
- 입력 보호 표적 RED13/5 → GREEN13/0. 실제 교차는 자동 카드가 축약되어 false가 됐고, 명시적 알림 버튼 키보드 활성화·재집중·긴 초안/오른쪽 caret·TextEdit·언어 clear·세계 보존을 확인했다.
- 제목줄 표적 RED12/4 → GREEN12/0. 실제 마우스 최대화, 이후 문자·Space·읽기 명령 pwd의 Enter, 새 세션 입력·기존 초안, 명시적 키보드 제목줄 접근을 확인했다. 두 표적 모두 actual exit 0, 엔진 경고/오류 0, 소스9 SHA·기본28경로 불변이다.
- 로그는 `/private/tmp/packet-trail-toast-input-red.log`, `/private/tmp/packet-trail-toast-input-green.log`, `/private/tmp/packet-trail-title-focus-red.log`, `/private/tmp/packet-trail-title-focus-green.log`다. 수정 후 native의 자동 축약/명시적 읽기/입력 재개 세 시점과 같은 리뷰어의 최종 픽셀 판정은 별도 후속이다. 새 UI 원문·Core·하네스·설정/로비 파일은 수정하지 않았다.
