# C23 로비 선호 저장 독립 회귀

상태: 실제 RED 재현과 Root 수리 뒤 **103검사/실패0**. 서버 재시작 뒤 저장된 source와 결과부터 확인해 미실행 회귀만 이어갔다.
소유는 새 `test_lobby_preferences.gd`와 이 문서뿐이다. 기존 Store/Room/FullGame/Panel·기존 회귀는 수정하지 않는다.

## 소스 검토와 판정 기준

C23는 읽기 전용 소스 추정이며 실행 재현이 아니었다. M1은 Room이 load_settings 실패를 버리고 자동 support patch를 쓰는 실제 경로가 있다. Store의 명시적 Apply와 로비의 자동 쓰기는 의도가 다르므로, 자동 쓰기가 손상/새 버전 원본과 직전 정상 backup을 바꾸는지를 직접 검사한다.
M3는 세션에 적용된 guidance와 영속 values의 차이가 Panel 초기값과 Room의 session map clear에 걸리는 경로다. 유효한 preferences를 실제로 읽은 다음 쓰기 실패를 유도해야 한다. `.bak.tmp` 디렉터리를 Room._ready 이전에 만들면 Store의 읽기 guard까지 막혀 M1과 혼동되므로, 정상 load가 끝난 뒤에만 만든다.

## Fixture와 기능 검증의 경계

- Root가 제공할 `run_lobby_preferences.gd`는 RefCounted의 async `run(SceneTree)`를 호출한다.
- 모든 쓰기·삭제는 고유 `user://tests/lobby_preferences_<pid>_<time>/` 안에서만 한다. 기존 지원 설정 회귀의 fingerprint·제한 cleanup helper를 재사용해 기본 settings와 여섯 슬롯의 28 경로를 보호한다.
- 실제 RoomScene과 DesktopScene을 사용한다. Room의 settings_path와 네 campaign slot을 트리에 넣기 전에 테스트 namespace로 주입한다.
- Fixture의 settings_changed relay는 실제 FullGame._on_settings와 같은 `desktop.apply_settings(room.presentation_settings(values))`를 호출한다. 이 연결을 생략해 데스크톱 mode가 우연히 유지되는 false pass를 만들지 않는다. 오디오/타이틀 통합 검증은 이 회귀의 범위가 아니다.
- 역할/지원의 실제 metadata 선택 메서드와 `open_desktop` 세션 API를 사용한다. Panel은 실제 controls의 선택 metadata를 읽고 music slider만 바꾼 뒤 실제 `_apply` handler를 실행한다. 물리 버튼 클릭·OS 입력·native 렌더 수락으로 주장하지 않는다.
- Canonical record를 만들거나 완료 flag·core 진행을 주입하지 않는다. 새 세션은 제품의 정상 save flow로 시작하며 snapshot은 실제 export 결과를 비교한다.

## 사례

1. M1 malformed JSON / newer version main 각각에 정상 custom backup(en/music0.27/font1.25)을 붙인다. guided 새 세션은 적용되되 원본·backup bytes와 정상 custom 값이 유지되어야 한다. 로비가 자동 교체 temp를 남기지 않아야 한다.
2. M3 유효 standard prefs를 실제 load한 뒤 `.bak.tmp` 빈 디렉터리로 자동 쓰기 실패를 만든다. guided가 세션에만 적용된 것을 확인하고 blocker를 제거한다. 실제 Panel은 guided를 초기 표시해야 하고, 음악만 0.19로 바꿔 Apply해도 guided를 유지·저장하며 전체 world는 같아야 한다.
3. 별도 fresh Room에서 A의 unsaved guided 뒤 B의 independent 자동 저장을 성공시킨다. A의 effective guidance와 cached session/world가 유지되어야 한다.

## 실행 근거

실제 첫 실행은101검사/10실패였다. 손상/새 버전 설정의 원본과 정상 backup이 교체됐고, Panel이 ephemeral guided 대신 standard를 표시하며 음악만 저장해도 지원이 바뀌는 현상을 확인했다. 테스트가 손상된 backup을 `JSON.parse_string`으로 읽어 engine error를 더하던 부분은 `JSON.new().parse`로 바꿔 **같은101/10을 engine error0으로 다시 재현**했다. 제품 validator나 기대값을 완화하지 않았다.

Root는 Room의 첫 settings load 성공 여부를 보관하고 실패 시 자동 선호 쓰기를 건너뛴다. 원하는 지원은 이번 세션에 적용하고 기존 원본/정상 backup은 유지한다. 명시적 Settings Apply 성공은 별도 commit signal로 인식한다. Panel은 실제 presentation_settings를 초기값으로 받으며, 다른 편의 자동 지원 저장은 기존 session-only 선호도 함께 보존한다. Store·core·snapshot 스키마는 바꾸지 않았다.

동일 회귀는101/0, 실제 종료0·engine error0으로 통과했다. 이어 C23의 keyboard 질문을 실제 Tab 입력으로 검증하니 카테고리 header를 건너뛰는102/1 RED가 재현됐다. TabContainer의 실제 internal TabBar를 명시적 focus chain에 넣고 방향키 전환을 확인한 최종 실행은 **103/0·1.608초·종료0·engine error0·기본28경로 보존**이다.

`.omx/artifacts/lobby-preferences-20261106/`에 `red.log`, `red-clean.log`, `green.log`, `tab-red.log`, `final-green.log/.json`을 보존했다. 원문 수정·임의 canonical record·완료 flag 주입 없이 실제 functional controls와 저장/바이트를 비교했다. 실제 native 마우스·시각 수락은 별도다.
