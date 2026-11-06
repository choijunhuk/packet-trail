# Midnight OS 실제 UI 검증 준비 — 2026-11-06

작성 모델: Codex gpt-6.1-sol / high. 작업 트리 `packet-trail-desktop`, `feat/desktop-experience`.

상태: **최종 커밋345eff6f native full5435/0·44사건/3결말·85.447초 GREEN**, 후속 preview824/0·45PNG GREEN. 앞선 native801/0·기능141/0은 이전 소스/검사 범위의 근거다. 아래 최신 full은 1.2 소스에서 직접 실행했으며 기존1.1의5390 근거를 재사용하지 않았다. 시각 수락·추출 패키지·실제OS 입력은 Root/독립 검토의 별도 판정이다.

## 변경 계획과 기존 근거

기존 pointer motion/down/held/return-motion/up, child Window confirmation Enter, process-frame 대기와 force-draw PNG readback을 재사용한다. 점 좌표 입력을 작은 공통 helper로 옮겨 TabBar/창 drag에도 같은 실제 InputEvent 경로를 사용한다. 기존 full44 fixture·목표·모형 판정은 바꾸지 않는다. 이전 native 회귀는 행동 보존 근거이고 새 시나리오/빈 desktop/launcher/실행 중 taskbar 계약은 이번 preview와 기능 suite로 새로 검증한다.

`capture_perspectives.gd`는 boot/test slot guard를 공유하며 실제 scenario card·support OptionButton·재귀 lobby_action/settings_action·새 window actions를 사용한다. 캠페인 4개 slot과 settings path를 scene 진입 전 주입한 뒤 실제 store 경로를 대조한다. 기본 28개 source/sidecar 경로와 saves/progress 폴더를 읽기 fingerprint한다.

`capture_desktop_preview.gd`는 로비/지원 확인·취소, standard 빈 desktop, 아이콘/검색 launcher, terminal 창 수명/최대화/drag, Nightfox 두 tab의 주소/이력/폼/응답, 네 settings tab, 1280 큰 글씨/6locale, 실제 M01 첫 A 해법과 세 role 선택을 캡처한다. Full44와 세 결말은 Root의 후속 실행 신호가 필요하며 preview에서 완료로 표시하지 않는다.

새 기능 suite는 실제 product Control/core를 고유 tests slot으로 구성하되 직접 public/UI 메서드를 호출하는 functional 근거다. 창 닫기/최소화와 재개, 3 support profile의 world/goal 불변, 설정 취소의 prefs 불변, tab별 address/history/form과 password 비저장, 새 세계의 modal/tab 폐기를 다룬다. 기존 actor160/support340/UIcontext37/종료8+6은 별도 보존한다.

## 주장 경계

값·metadata 선택은 setup API로 명시하고 실제 실행/새 진행/확인/Save/Apply는 engine InputEvent로 검증한다. 숨은 테스트 Button·BaseButton pressed.emit·domain 완료 주입·raw JSON 우회로 통과시키지 않는다. 실제 OS/CUA·물리 IME·사람 청취/디자인 수락은 별도이며 첫 look은 Root 육안과 독립 검토가 판정한다. 미준비 조건은 FAIL/NOT_RUN으로 남긴다.

## 실제 첫 preview와 원인 분리

`native-preview-first.log/.json`은 570 checks / 15 failures, 8.468초였다. 실제 빈 desktop·런처 검색 Enter·최대화/복원/drag·Nightfox 두 tab·설정 네 tab/Apply/Cancel·지원 세 확인/취소·M01 실제 A 경로·세 role 선택을 수행했다. 실패 중 12개는 옛 helper가 비저장 `_apply_settings`만 호출했으나 새 bootstrap은 실제 Store의 `presentation_settings()`를 읽는 계약 차이였다. 기본 settings를 쓰지 않는 guard를 확인한 고유 test Store 값 변경으로 검사 setup을 맞췄다. 두 empty-resume 실패는 등록 순서의 배경 창 close 좌표를 전경 창이 가린 입력 문제였다. 실제 전경 창부터 닫도록 바꿨고 제품 창 규칙은 변경하지 않았다.

`native-preview-corrected.log/.json`은 **591 checks / 1 failure, exit 1, 8.561초**다. 현재 실제 글씨 1.6/1280×720의 6locale 검사는 통과했고, 창을 모두 닫은 빈 desktop 재개도 통과했다. 남은 RED는 term0 input을 포커스한 F10→메뉴 Continue 뒤 같은 desktop/world/draft/active_id=term0를 유지하면서 focus만 launcher_button으로 돌아가는 동작이다. `ROOM_FOCUS` 로그가 before/after/expected Control 경로를 남긴다. 제품 담당에게 인계했고 기대를 launcher로 낮추지 않았다.

제품 scripts·3pack·6PO·31SVG **65 SHA 전후 불변**, 기본 28 파일/sidecar와 saves/progress 존재 상태를 포함한 **30 보호 항목 불변**이다. 두 native 실행 모두 Script/Compile/engine ERROR/WARNING은 0이고 정상적으로 report/exit했다. 현재 PNG 29개는 `.omx/artifacts/desktop-native/desktop-preview/`에 있으며, 첫 실패 실행 PNG는 `preview-first-pngs/`에 별도 보존한다. `preview-first-source-before/after.json`, `preview-corrected-source-before/after.json`이 각 실행 소스 근거다.

대표 파일은 `lobby-1600.png`, `settings-0.png`부터 `settings-3.png`, `support-confirm-guided.png`, `intruder-empty-desktop.png`, `intruder-launcher-all.png`, `intruder-terminal.png`, `intruder-nightfox-two-tabs.png`, `intruder-full-locale-ko-1280-large.png`다. 초기 실행의 large 파일명은 실제 scale 검사를 통과하지 않았으므로 성공 근거가 아니며, 현재 corrected 파일을 구분해 사용한다.

새 `test_desktop_shell.gd`의 API는 `await Tests.new().run(scene_tree) -> {suite,checks,failures,profiles,protected_paths,limit}`다. 실제 support UI 정책 3×3, 창 수명과 정확한 focus 재개, tab address/history/form/response·비밀번호 비저장, 다른 terminal의 pending 인증 보존, 새 세계 modal/tab 폐기, settings Cancel Enter를 고유 tests namespace에서 검사한다. runtime 결과는 아직 없고 다음 직렬 실행 슬롯이 필요하다. 전체44/세결말·legacy GUI·다른 해법 GUI·실제 OS/IME/청취는 이번 preview의 성공 범위가 아니다.

## 수리 후 실제 재생 — 최신 검증

UI 담당의 focus/no-op launcher·전체폭 stale row·taskbar 위 닫기/scroll 가능한 toast·locale 전이 transient 정리 수리와 Root settings payload 교정 뒤, 동결된 소스로 기능→native를 직렬 실행했다. 제품 소스를 이 검증 레인에서 수정하지 않았다.

- 기능 `shell-functional-first.log/.json`: **141/0, exit 0**, 공개 세 role×guided/standard/independent **9조합**의 UI 자동창 정책과 canonical snapshot/goal 동등성을 확인했다. 닫기/최소화/최대화/재개·정확한 terminal input focus, tab별 address/history/form/response·password 비저장, 다른 terminal의 pending 인증, 새 세계의 modal/tab/secret 폐기, 실제 settings Cancel Enter를 포함한다. 이 검사는 product scene 메서드/고유 test IO의 functional 근거이며 픽셀·OS 입력을 주장하지 않는다. UI 담당의 별도 14/0 focus/표시 probe와 구분한다.
- Native `native-preview-repair-batch.log/.json`: **801/0, exit 0, 11.109초**. M01 A 경로 **1/44**만 실제 완료했고 세 role 선택, 지원 3확인/취소, 창 수명·최대화·drag·빈 desktop 재개, Nightfox 두 tab/current-vs-past, settings 네 tab·Apply/Cancel, 6locale/1280/글씨1.6을 수행했다. 실제 F10→Continue의 input Control before/after/expected 경로가 같았다.
- 누락 viewport를 추가했다. 실제 **1280×720/font1.6**의 로비 세 card·support·Continue/New, 열린 launcher의 검색/활성 앱, settings 네 tab과 모든 설정/Apply/Cancel을 정상 focus/ScrollContainer.follow_focus 및 실제 키 입력으로 도달했다. **43개 geometry 도달 관찰**(로비6, 설정26, 런처11)이 모두 통과했다. 각 Control의 rect·viewport·클리핑 ancestor·실제 intersection·disabled/focus를 report `ui_observations`에 남긴다. disabled Continue는 빈 진행 정책대로 비활성임을 명시했고 enabled 조작은 실제 focus를 요구했다. 제품 폭/높이/min/max를 테스트에서 바꾸지 않았다.
- **43 PNG**의 실제 header·치수·SHA·밝기 표본 범위를 재검사했다. `lobby-1280-large-{intruder,defender,tracker}.png`, `support-confirm-1280-large.png`, `1280-large-settings-{0..3}.png`와 각 `-reached`, `intruder-launcher-1280-large.png`/`-reached`가 추가되었다. 기존 reviewer 비교용 terminal/maximized, Nightfox current-and-past, large locale mail 파일명은 유지한다.
- 실제 `intruder-terminal-maximized.png`에는 활성 toast가 있고, `intruder-nightfox-current-and-past.png`에는 현재 요청 terminal2와 보관 응답 terminal1·별도 전체폭 stale 문구가 렌더된다. 이는 표시 관찰이며 디자인 수락 점수를 대신하지 않는다.

기능과 native 모두 **제품65 SHA 전후 불변**, **기본30 보호 항목 불변**, Script/engine ERROR/WARNING/누수0으로 종료했다. 원본 settings/saves/staging/설치 앱 쓰기는 없다. 로그와 hash manifest는 `.omx/artifacts/desktop-native/`의 `shell-functional-source-before/after.json`, `preview-repair-source-before/after.json`, `preview-repair-summary.json`에 있다. 첫 RED와 수정 전 PNG/로그는 그대로 보존한다.

추가된 viewport helper의 최초 Variant 타입 추론 parse 오류는 `viewport-preview-parse.log`로 보존하고 명시 bool annotation 뒤 `viewport-preview-parse-fixed.log` exit0을 확인했다. 이후 native 실행의 Script/CompileError는0이다. Full44/세결말·다른 해법/legacy GUI·실제 OS/CUA·물리IME·청취·사용자 디자인 수락은 여전히 별도이며, 이 preview를 전체판 완주로 표시하지 않는다. 현재 source Godot 프로세스는 모두 종료됐고 다음 full/Gate 실행은 Root의 별도 신호를 기다린다.

## 알림 입력 보호 후속 — 수리 전 RED 이력

Root의 Room/SettingsPanel 선호·키보드 접근 수리와 core GET 응답 전달 수리 뒤 소스를 동결하고, 실제 포인터·문자·Enter 입력을 추가한 preview를 한 번 실행했다. `native-preview-toast-input-first.log/.json`은 **824 checks/2 failures, exit1, 12.528초**다. M01 실제 완료1/44·세 role 선택·결말0, 원래43장과 explicit notification read/typing resume 두 장을 합친 **45 PNG**를 남겼다. PNG header/치수/SHA/밝기 범위, 제품 **74파일 전후 SHA 불변**, 기본 **30 보호 항목 불변**, Script/engine error/warning/누수0이다. 기존43장은 `preview-before-toast-input-fix-pngs/`, 이번45장은 `preview-toast-input-first-pngs/`에 각각 보존했다.

확인된 제품 RED는 `actual taskbar notification click explicitly opens the saved message`다. 실제 Save 버튼으로 생성된 알림은 최대화 terminal에서는 정상으로 접히고 입력은 유지된다. 그러나 실제 bell 포인터 클릭의 제품 pressed callback 직후에는 toast=true/focus=bell이었다가, deferred 입력 처리가 끝나면 toast=false/focus=terminal LineEdit가 된다. 수동 메서드 호출을 쓰던 headless13/0과 구분되며, `NOTIFICATION_POINTER`와 report의 `notification_pointer_trace`가 세 시점의 정확한 Control 경로를 남긴다. 테스트에서 focus를 강제 복구하거나 신호를 emit하지 않았다. 포인터로 입력을 다시 선택한 뒤 실제 `pwd` 세 글자와 Enter의 core 결과/history 검사는 통과했다.

다른 RED는 최대화 직후 typed x의 기대값을 무조건 draft 끝으로 가정한 검사다. Text assignment는 caret 위치를 보장하지 않으므로 사전 caret 위치에 삽입된 정확한 문자열과 input focus를 함께 검사하도록 보완했다. 후속 GREEN에서 caret0·expected/actual `xdesktop-unsent-draft`·input focus=true를 확인했다. 기대 수준을 낮추거나 focus를 주입하지 않았다.

1280 결과의 표현을 정정한다. 프로젝트의 공식 `canvas_items` stretch로 **native window/PNG1280×720, logical canvas1600×900**가 사용되며 font_scale1.6은 실제 적용된다. 43 geometry 관찰은 logical1600 viewport와 각 clipping ancestor에서 정상 focus/scroll 도달을 검사한다. 이는 native1280 출력 검증이지 logical1280 재배치 검증이라는 뜻이 아니다. 현재 full44/세결말과 추출 앱의 실제 OS 마우스/키보드 검증은 별도 후속 범위다.

## 알림 실제 포인터 수리 후 — 최신 GREEN

Root는 `_focus_after_click`에서 실제 focus가 열린 알림 버튼/알림 자식에 있을 때 명시적 읽기를 존중하는 작은 제품 수리를 했다. 기존 LineEdit 재선택 시 축약은 그대로 둔다. 소스 재동결 후 **`native-preview-toast-input-green.log/.json`:824/0, exit0,11.430초**를 확인했다. bell callback 직후와 settled InputEvent 뒤 모두 toast=true/focus=bell이다. 실제 입력칸 포인터 재선택으로 toast가 접힌 뒤 `pwd` 문자와 Enter가 정상 core 결과·terminal history를 만들고 같은 input focus를 유지했다. 최대화 직후 다음 문자 입력도 사전 caret 위치에 정확히 들어갔다.

새 **45PNG**의 header·실제1280/1600 치수·SHA·밝기 범위가 통과했고, 기존 **43 focus/scroll geometry 관찰**도 전부 통과했다. 제품74 SHA·기본30 보호 항목은 전후 불변이며 engine error/warning/누수0·남은 source Godot 프로세스0이다. `preview-toast-input-green-source-before/after.json`과 `preview-toast-input-green-summary.json`이 이를 남긴다. 최대화 입력·명시적 알림 읽기·다시 `pwd`를 실행한 화면, Nightfox 현재/과거 응답, native1280 큰 글씨 Mail을 실제 이미지로 열어 확인했다. 자동 알림이 입력을 가리지 않으며 명시적 읽기 카드는 사용자가 요청한 동안 표시되고, 입력으로 돌아가면 다시 접힌다.

검토용 대표 파일은 `intruder-terminal-maximized.png`, `intruder-terminal-maximized-notification-read.png`, `intruder-terminal-maximized-input-resumed.png`, `intruder-nightfox-current-and-past.png`, `intruder-full-locale-ko-1280-large.png`와 lobby/settings/launcher1280 PNG다. `review-packet-toast-input-green.json`은 비교 원본과 현재 파일·SHA를 연결한다. 독립 디자인 판정은 Root가 별도로 수신하며, source engine 입력 검증을 추출 앱 실제 OS 입력·물리IME·청취로 확대하지 않는다. 이 preview 시점의 Full44/세결말 NOT_RUN은 아래 별도 full 실행으로 갱신한다.

## 최종 동결 소스 실제 전체44 — 최신 full

Root의 독점 실행 슬롯에서 다음 기본 full을 새 이름으로 한 번 실행했다. 다른 Godot/import/export를 동시에 실행하지 않았고 preview45 PNG는 그대로 보존했다.

```text
/Applications/Godot.app/Contents/MacOS/Godot --path godot --audio-driver Dummy --script res://tools/capture_perspectives.gd
```

**`native-full-desktop-final.log/.json`:5435/0, exit0,86.371초**. 실제 침투28·방어8·추적8 = **44/44 A해법**, 사실에서 선택 가능한 실제 결말 **3/3**(`in2_sealed_audit`, `df1_handoff`, `tr1_handoff`)을 완료했다. 이는 기존 fixture의 도구/actor/목표를 바꾸지 않고 실제 새 UI의 metadata 탐색→입력→Run/확인/저장 경로로 수행했다. 도메인 완료 주입·Button.pressed.emit은 사용하지 않았다.

실제 fixture 입력347회·password 입력47회, 기본 구조화 form Run **195회**(response_lab134·branch_vm6·observation_case55)를 기록했다. M24 response10회, R01 VM6회, D01/D08 response, T01/T08 observation을 포함한다. 필드 값·자료형·OptionButton 상태 지정은 report의 setup 범위이며 실제 Run은 포인터 press/held/return-motion/release다. 최종 실제 목표·제약·자료·세 role 진행 격리, 새 사건, 세 결말 선택/저장/Load 재진입, 각 role의 F10→3D room→동일 input focus 복귀를 검증했다.

세 role 각각6locale의 실제 font1.6/native1280 출력 **18장**을 포함해 full 전용 **41 PNG**를 생성했다. live volume0·독립 event levels·실제 AudioStream playback/paused 상태·Pause/resume·mood 우선순위·결말 one-shot edit 검사를 통과했다. focus loss/return은 Window 신호 주입이며 실제 OS 전환/사람 청취를 주장하지 않는다. Dummy 오디오 드라이버이므로 청취 수락은 NOT_RUN이다.

**제품74 SHA 전후 불변·기본30 보호 항목 불변·preview45 PNG SHA 불변**, full41 PNG header/치수/SHA/밝기 범위 PASS, engine error/warning/누수0·남은 source Godot 프로세스0이다. `native-full-desktop-final-summary.json`, `-source-before/after.json`, `-preview-before/after.json`을 함께 보존한다. full 출력은 `.omx/artifacts/desktop-native/full/`로 preview와 분리했다.

남은 한계는 다른 GUI 해법·legacy GUI·실제OS/물리IME·청취·사람 재미/시간·추출 PCK/서명/패키지·3OS CI다. 이 레인은 source native 검증을 마쳤으며 helper·preview/full 산출물을 동결한다. Whole Gate·추출 앱 실제 입력·배포 검증은 Root 소유다.

## 출시 직전 한 줄 수리 반영 — exact HEAD 최종 재생

Root의 실제OS 수락 중 발견된 legacy import 버튼의 늦은 availability 표시 수리 뒤, **HEAD `345eff6f92a768f9380d85f3c09c278fbdae54c6`**에서 동일 full 명령을 마지막 한 번 재생했다. 이 레인은 helper/fixture/actor/목표/검사 조건을 바꾸지 않았다. `native-full-desktop-release-final.log/.json`은 **5435/0·exit0·85.447초**, 실제 **44/44 A해법(28/8/8)·3/3결말**, fixture 입력347회·password47회·실제 구조화 form Run195회(response134/VM6/observation55)다. M24 response10회·R01 VM6회·D01/D08·T01/T08의 실제 form 실행을 다시 확인했다.

새 full41 PNG(6locale×3role의18장 포함)의 header/실제 치수/SHA/밝기 범위 PASS, **제품74 SHA·기본30 보호 항목·preview45 PNG 전후 불변**, engine error/warning/누수0·잔여 source Godot 프로세스0이다. 이전86.371초 실행의 로그/JSON과41 PNG는 `full-before-release-final-pngs/` 및 SHA manifest로 보존했고 모두 원본 report SHA와 일치한다. 새 summary와 source/preview before-after는 `native-full-desktop-release-final-*`에 있다.

최종 소스 실행 슬롯은 Root에 반환했다. preview45는 독립 시각 검토용 그대로 보존했고, QA helper/생산 소스 추가 편집이나 커밋은 하지 않았다. 이 결과는 source engine 입력/렌더 범위이며 Root의 최종 ZIP/서명/실제OS 재검사·3OS CI와 별도 근거다. 다른 GUI 해법·legacy GUI·물리IME·사람 청취는 이 재생에서 NOT_RUN이다.
