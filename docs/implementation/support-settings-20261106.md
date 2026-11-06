# 플레이지원 선호와 격리 설정 저장

상태: 설정 레인 구현·독립 표적 검증 완료. Root의 전체 UI/통합 검증은 후속이며 이 결과와 구분한다.
기준은 `feat/desktop-experience`의 DESIGN.md와 [1.2 실행 기록](2026-11-06-desktop-experience.md)이다.
소유 범위는 settings_store.gd, RefCounted test_support_settings.gd, 이 문서 세 파일이다.

## 계약

- `support_intruder`, `support_defender`, `support_tracker`는 `guided|standard|independent`의 scalar enum이다. 누락 값은 standard이며 이전판은 별도 지원 키를 만들지 않고 표준을 사용한다.
- 도움 표시 선호만 저장한다. WorldState·목표·경보·행동 재생·평가·힌트 사용 성취를 바꾸지 않는다. 기존 엄격 v2 9키 캠페인 저장은 변경하지 않는다.
- preferences는 기존 `{version:1,values:{...}}` JSON을 유지한다. 기존 음향·화면·입력·언어 필드와 기본값은 보존한다.
- 기존 `changed(values)`, `get_values`, `validate_values`, `load_settings`, `update_settings`, `reset_controls` 이름과 반환 계약을 유지한다.
- 생성자의 기본 경로는 `user://settings.json`이다. 명시 경로는 그 기본값 또는 정규화된 `user://tests/` 하위 `.json`만 허용하며 잘못된 입력을 기본 경로로 대체하지 않는다.
- 쓰기 전 main/tmp/bak/bak.tmp와 각 부모의 심볼릭 링크·잘못된 디렉터리 위치를 검사한다. 안전한 테스트 부모가 없으면 쓰기 때만 생성하며 읽기는 생성하지 않는다.
- tmp 쓰기·flush·close·재읽기 검증 후 이전 본문을 보존하고 교체한다. 실패 시 활성 값과 changed 신호를 갱신하지 않는다.
- 동시에 여러 게임 프로세스가 같은 preferences 파일을 쓰는 잠금 계약은 추가하지 않는다.

## 검증 범위

Root가 제공한 작은 `run_support_settings.gd`만 실행한다. 전체 gate·native·import·export는 Root 소유다.
첫 실행은 기존 저장기의 `support_*:guided` 거절을 확인하는 enum RED로 제한하고 제품 파일을 바꾸기 전에 기록한다.
이후 표적 suite는 기존 v1 읽기·누락 기본값·비기본 표시/음향 값·지원 영구화·실제 IO 실패·링크/경로 경계·캠페인 snapshot/힌트/목표/경보 불변을 확인한다.
모든 쓰기·삭제는 고유한 `user://tests/support_settings_<pid>_<time>_<instance>/` 안에서만 한다.
허용되지 않는 실제 namespace는 무해한 guard 검사로 거절을 확인하고, 실제 잘못된 경로 IO는 물리적으로도 고유 테스트 트리 안의 경로만 사용한다. 기본 preferences와 여섯 캠페인/이전판 슬롯의 main/tmp/bak/bak.tmp 총 28경로를 전후 SHA/형태로 보호한다.

플랫폼 한계: [Godot DirAccess 공식 문서](https://docs.godotengine.org/en/stable/classes/class_diraccess.html#class-diraccess-method-create-link)에 따르면 Windows 링크 생성은 Developer Mode 또는 상승 권한이 필요하다. [FileAccess 공식 문서](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html#class-fileaccess-method-set-unix-permissions)의 Unix 권한 기반 실패 시험은 Windows에서 지원되지 않는다. 지원되지 않는 fixture는 별도 skipped로 보고하며 통과했다고 세지 않는다.

## 현재 결과

- 제품 수정 전 enum RED: 실제 exit 1, 4검사 중 세 support_* guided 거절 3실패, 엔진 오류 0. 당시 settings_store.gd SHA256은 `505b85b02f897d8366b19776c3d9a2774e8a05fe1c38ccf228011550ef49a8de`다.
- 최종 동일 표적 GREEN: 실제 exit 0, 340검사·실패 0·skipped 0·엔진 오류/경고/누수 0. macOS에서 실제 권한 기반 FileAccess 쓰기 실패, main/tmp/bak/bak.tmp 파일 위치 및 부모 링크 방어까지 수행했다.
- 기존 v1의 실제 비기본 locale/font/fullscreen/music 값과 raw backup bytes를 보존했다. 지원값 저장·다시 읽기, 오류 시 memory/changed 신호 보존, 고유 테스트 트리 정리를 확인했다.
- 기본 28경로의 파일 SHA/경로 형태가 전후 동일했다. 세 공개 캠페인+이전판에서 profile 변경/선택적 get_hint/pwd가 엄격 v2 snapshot·목표·경보를 바꾸지 않았고, 새 지원 필드를 캠페인 저장에 넣으면 계속 거절했다. 같은 실제 잘못된 SSH 인증 행동도 세 profile에서 동일한 core state를 만들었다.
- 범위 한정 diff 검사 통과. whole gate·native·실OS UI·export·import·commit은 이 레인이 실행하지 않았다. Root의 선행 asset import와 이 저장기 검증을 혼동하지 않는다.
- 실행기: Root 소유 `godot/tools/run_support_settings.gd`가 이 레인의 RefCounted.run()을 호출하고 실패 시 quit(1)한다. 로그는 `/private/tmp/packet-support-settings-red.log`, `/private/tmp/packet-support-settings-green.log`다.
- 최종 제품 SHA256: `ff37916556d46eb763997debf7f11745c878ecf82ea38f098a2efd9eb32060ce`. 최종 test SHA256: `70c1f7842c266f8dcf9d336e7dc0b721912f1365721d5f7fa0705d56f9944868`.

### 연결 API

`SettingsStore.new()`는 기존 기본 경로를 유지한다. Root가 시험할 때만 `SettingsStore.new("user://tests/<고유경로>/preferences.json")`으로 주입한다. 생성자는 IO를 하지 않는다. `load_settings()`와 `update_settings(patch)`가 주입 경로를 검증하며 잘못된 경로를 기본 파일로 돌리지 않는다.
`get_values()`는 지원값을 포함한 사본을 반환하고, `validate_values()`는 저장·적용 없이 누락 기본값을 보충한다. `update_settings()` 성공 뒤에만 메모리와 `changed(values)`가 갱신된다. `reset_controls()`는 감도·편안한 이동만 초기화하며 지원값을 보존한다. 기존 반환 `{ok,values? ,error?}`와 signal 이름을 바꾸지 않았다.
실제 Stage는 새 `.tmp`의 정규화된 값 검증 → 기존 본문의 raw bytes를 `.bak.tmp`로 복사·검증 → `.bak` 교체 → 새 main 교체 순서다. 게임용 SaveStore나 WorldState를 의존성으로 추가하지 않았다.

## 버전 호환 한계

새 앱은 기존 v1 선호의 누락 지원 필드를 기본값으로 보충해 읽을 수 있다. 구 앱의 엄격한 필드 검사는 새 support 키를 거절하므로, 새 preferences를 구 바이너리가 읽는 역방향 호환까지 주장하지 않는다. 읽기 실패로 원본을 자동 덮어쓰지 않는다.
