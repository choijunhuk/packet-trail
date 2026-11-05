# 세 편 실제 렌더·입력 검증 — 2026-11-05

작성 모델: Codex `gpt-6.1-sol / high`. 작업 트리 `packet-trail-expansion`, 브랜치 `feat/three-perspectives`.

현재 상태: **최종 실제 native full 5390/0 GREEN — 44건·3결말 완료**. 최종 fixture의 28/8/8 사건과 각 첫 A 경로 347행동(침투 190, 방어 86, 추적 71)을 실제 UI로 실행했다. 초기 smoke 459/0과 첫 full 26/44 partial failure는 별도 원문 로그로 보존한다. 데이터가 없거나 계약이 맞지 않으면 실패하며, 준비 플래그나 완료 상태를 주입하지 않는다.

## 소유와 재사용

소유 소스는 `godot/tools/capture_perspectives.gd`와 이 문서다. 산출물은 `.omx/artifacts/expansion-native/**`만 사용한다. 오디오·다른 구현자 소스·기존 앱·설정·사용자 저장은 수정하지 않는다.

새 SceneTree는 기존 `capture_full_game.gd`를 상속한다. 실제 key/mouse/held/return-motion/release, terminal 제출, 앱 열기, 기본 UI selection, confirmation의 child Window Enter, PNG force-draw/readback, SHA·치수·밝기 metric을 그대로 재사용한다. 기본 28-case 소스는 수정하지 않는다.

기존 cleanup 함수는 옛 suite report와 결합되어 있어, stop→3 frames→stream release→scene queue_free→4 frames→0.2초 대기 순서만 새 report 함수에 동일하게 유지한다. 일반 입력 대기는 `process_frame`을 사용하고, 캡처 때만 `RenderingServer.force_draw(false)`로 실제 GPU frame을 만든다. 정적인 창/가려진 창의 `frame_post_draw`를 무조건 기다리지 않는다.

## 실행 계약

```sh
# root가 모든 데이터/구현 통합 준비 뒤 호출한다.
godot --path godot --audio-driver Dummy --script res://tools/capture_perspectives.gd

godot --path godot --audio-driver Dummy --script res://tools/capture_perspectives.gd -- --ci-render-smoke
```

| 프로필 | 기대 native 범위 | watchdog | 보고 |
|---|---|---|---|
| `full` | public intruder 28 + defender 8 + tracker 8의 각 A 경로, pack별 실제 ending 3개, 저장·재개·캐시 분리 | 600초 | actual case 44 / ending 3을 실제 결과에서 확인 |
| `ci-render-smoke` | intruder M01 실제 1건, 세 pack 메뉴 선택·실제 첫 desktop/노출된 기본 폼 view, 공통 입력·저장·방·6locale | 240초; 외부 300초 예상 | 1/44만 기록; 나머지 43·ending GUI·후반 branch_vm 실행은 NOT_RUN |

`--headless` 실행은 픽셀 근거가 되지 않으므로 이 suite가 실패한다. headless 44건/다중 해법·PCK 검증과 실제 OS mouse/IME/청취는 각각 별도 증거다.

## 저장·설정 보호

- root의 exported `save_slot_path`에 고유 `user://tests/perspectives_ui_<ticks>_<instance>.json` **base**를 scene 진입 전에 주입한다.
- `Catalog.test_slot(base, pack_id)`로 public 3개와 `legacy_intruder`까지 4개 test slot을 계산한다. 이미 있는 test slot/backup은 덮어쓰지 않는다.
- `room.campaign_slots` 전체와 각 desktop의 `pack_id/save_slot_path`, 실제 Campaign의 `_pack_id/_save_path`를 대조한 뒤에만 새 진행을 조작한다.
- `Catalog.default_slot` 4개 + 보존 원본 `campaign_01.json/slot_01.json` + `settings.json`의 총 7 source 파일, 각 `.bak/.tmp/.bak.tmp`, 실제 saves 폴더의 기존 파일들을 전후 fingerprint한다. 존재하지 않음/디렉터리/심볼릭 링크도 구분한다.
- 실제 `legacy` probe의 `get_save_status(false)`와 `legacy_sources_checked=false`를 확인한다. 원본 진행을 만들어 넣거나 가져오기를 호출하지 않는다. Classic 보존/이관의 심층 검증은 별도 backend suite다.
- 설정은 현재 room의 live `_apply_settings` preview만 사용한다. Apply/save/reset은 누르지 않는다.

## 실제 입력과 setup API의 구분

다음은 실제 engine InputEvent 경로다: 메뉴 Settings/Cancel/New, 확인창 Enter, campaign picker 열기·Enter 선택, terminal 키 입력, Run, Save/Load, F10/Escape/Continue, font mouse, pause/resume. OS 포인터를 이동하거나 실제 OS를 자동 조작하지 않는다. BaseButton `pressed`/dialog `confirmed`를 직접 emit하지 않는다.

다음은 fixture를 넣기 위한 **setup API**이며 실제 타이핑/클릭을 했다고 주장하지 않는다: LineEdit/TextEdit 문자열, SpinBox 수치, CheckBox 상태, OptionButton canonical metadata 선택, ItemList 다중 선택, Tree/도구 ItemList 선택, picker의 metadata 기반 highlight. 실행·새 진행·저장·확인은 실제 InputEvent가 수행한다.

새 `response_lab/observation_case/branch_vm`는 raw JSON 실행 대신 기본 폼만 사용한다. `tool_inputs.action`의 public action metadata를 선택한 뒤 동기 rebuild가 끝날 때까지 기다리고 새 leaf control을 다시 조회한다. `claim.kind`, `values.format_ok` 같은 중첩 경로를 flatten하여 enum/bool/int/string/array widget에 채운다. 이전 action의 draft는 입력 setup 단계에서 초기화하고 제공된 canonical 값의 UI serialization을 대조한다. 배열은 실제 `ItemList.SELECT_MULTI`와 metadata ID를 사용한다. 기존 도구 종류는 기존 advanced JSON helper를 재사용할 수 있다.

## full 검증 흐름

1. 실제 public 기본 선택이 intruder인지 확인하고 메뉴·설정을 캡처한다.
2. 실제 picker에서 세 pack을 각각 선택하고 새 진행을 확인한다. pack마다 독립 desktop cache와 고정된 test slot을 확인한다.
3. intruder에서 4 terminal의 실제 `pwd`, 이력/초안, CJK committed InputEvent와 echo 거부, 앱 전환, font mouse와 F6, 닫기/재열기 보존을 검사한다. RequestLab의 잘못된 JSON 무실행, 실제 가상 응답·identity/origin/trace와 외부 도메인 거부도 실제 Enter로 검사한다. IME guard 존재는 source 검사이며 물리 composition 성공으로 기록하지 않는다.
4. 실제 A fixture 행동으로 각 사건을 진행한다. 실제 SSH password pending이 생긴 경로에서 Exit/포커스된 Escape 취소·마스킹·history 비노출을 검사하고 동일 SSH를 정상 재요청해 A 경로를 이어 간다.
5. 각 pack의 첫 실제 domain 변화에서 test autosave를 잠시 멈춰 dirty bytes를 만든다. 실제 Save를 누르고 같은 pack constructor로 디스크를 읽어 snapshot 동등·saving 재개를 확인한다. 이 조작은 presentation의 test autosave 상태이며 완료/fact/policy를 주입하지 않는다.
6. 보드 Next와 optional case 선택으로 실제 44개 사건을 완료한다. 실제 목표·목표 rows·메일/회수 상태와 ending을 읽는다.
7. 각 pack 첫 사건에서 같은 desktop의 F10→3D room→메뉴→Continue, 6 locale/1280×720/큰 글씨, canonical snapshot/초안 동일, 음소거·focus signal·pause를 검사한다.
8. 실제 ending 선택/확인·title/body/credits·one-shot soundtrack·저장 재개를 확인한다.
9. 다른 pack 진행 중 이미 끝낸 pack의 메모리/디스크 snapshot이 같고, 비활성 실제 `view_changed`가 전경 음향·desktop을 바꾸지 않는지 확인한다. 마지막에는 각 cache Continue와 실제 Load를 수행한다.

음악 우선순위는 **실제 ending 선택/명시적 credits 진입 문맥** → alert → completed(flow) → 장/역할별 기본 cue를 검사한다. 저장된 historical ending 값만으로 finale를 기대하지 않는다. helper의 기대 문맥은 실제 테스트 행동에서 정하며 제품의 private cue flag를 oracle로 읽지 않는다. 메뉴·방은 home이고, cached Continue/Load 뒤 역사적 ending 값이 있어도 일반 사건 cue가 복구되는지 검사한다. 가짜 completed/ending view를 만들지 않는다.

## report와 검증 한계

JSON suite는 `rendered_perspectives`다. `status/profile/expected_scope/actual_case_count/actual_ending_count/campaign_cases/pack_endings/typed_basic_runs/first_case_form_views/native_fixture_actions/password_actions`와 `capture_metrics`를 기록한다. PNG별 path·width/height·밝기 표본 min/max·SHA256, test slot base/pack별 slot, source legacy probe, 보호 파일 수와 불변 여부를 남긴다. 실패/timeout은 실제 수행한 부분만 기록하고 `partial_failure`와 남은 GUI NOT_RUN 범위를 명시한다.

### 최종 full 근거

최종 whole Gate 통과와 제품 동결 신호 뒤 fresh parser exit 0을 확인하고 같은 macOS M3 Max/Godot 4.7/OpenGL 4.1 Metal compatibility/Dummy audio에서 실행했다. `native-full-final.log`는 **exit 0, status pass, 5390 checks / 0 failures / 85.728초**다.

| 실제 결과 | 수량 |
|---|---:|
| 침투/방어/추적 A 경로 완료 | 28 / 8 / 8, 총 44 |
| Fixture 실제 행동 / password 제출 | 347 / 47 |
| response_lab 기본 폼 Run | 134 |
| branch_vm 기본 폼 Run | 6 |
| observation_case 기본 폼 Run | 55 |
| 실제 결말 선택·확인·credits / pack별 save/load 재개 | 3 / 3 |
| PNG readback·치수·밝기 표본·SHA | 41 |
| 기본 저장·설정 및 sidecar 보호 경로 | 28, 전후 불변 |
| 제품 scripts·3pack·6PO source SHA | 33, 전후 불변 |
| 엔진 ERROR/WARNING/ObjectDB/Resource 잔류 | 0 |

실제 선택한 결말은 `in2_sealed_audit`, `df1_handoff`, `tr1_handoff`다. 세 결말 PNG에서 title/outcome/credits가 실제 렌더된 것도 확인했다. 기본 폼 값을 widget setup으로 채우고 Run을 실제 mouse 입력으로 실행했으며 raw JSON fallback은 사용하지 않았다. 각 pack에서 실제 6locale/1280 큰 글씨·pause·방 왕복·같은 desktop/cache·저장 재개를 검사했다. 최종 캐시 재진입/Load에서는 historical ending이 one-shot을 다시 고정하지 않는 현재 문맥 계약도 통과했다.

원문/JSON/요약은 `.omx/artifacts/expansion-native/native-full-final.log`, `native-full-final.json`, `full-final-summary.json`이다. `full-final-source-before.json/after.json`이 제품 33SHA 불변 근거이며, 실행된 helper SHA256은 `4b66bcb9e7256410f497c18e138b02ae902ea142e13a8273f171a41e794180c8`이다. Godot 프로세스는 exit 0으로 정상 종료했고 helper·제품 소스는 동결했다. 원본 project/staging/사용자 앱에 쓰기는 하지 않았다.

### 실제 smoke 근거

초기 smoke 환경은 macOS Apple M3 Max, Godot 4.7 stable, OpenGL 4.1 Metal compatibility, audio driver Dummy다. `native-smoke-final.log` 실행은 exit 0, **459 checks / 0 failures / 8.076초**, 실제 intruder M01 A 경로 1건·9 fixture 행동·password 2회다. 세 public pack 선택, D01 `set_control`의 control/value enum과 T01 `collect`의 sensor enum 기본 폼 표시, 6locale 1280×720 큰 글씨, RequestLab, 실제 font mouse, pause/room/save/continue를 수행했다. 기본 폼은 setup으로 선택·표시했고, smoke에서 새 모형의 Run은 실행하지 않았다. 15개 PNG는 각 치수·밝기 표본·SHA를 report에 남겼다. 이 smoke는 후속 core/C22/locale 교정 이전 소스의 기록이며, 최종 full이 같은 공통 입력·화면 검사를 다시 포함한다.

`native-smoke-final.json`, `smoke-final-summary.json`, `smoke-final-source-before.json/after.json`을 `.omx/artifacts/expansion-native/`에 보존했다. 보호 대상 28개 경로의 bytes/존재 상태가 같고 엔진 ERROR/WARNING/ObjectDB 잔류는 0이다. 제품 scripts·3pack·6PO 총 33개 SHA가 최종 실행 전후 모두 같았다. 이 실행의 harness SHA256은 `edbe1da9fa87becadd986ea60c6a37e077560402764825bdea777f1739bbbc10`이다. 직전 `native-smoke-clean.log`도 459/0이지만 실행 중 `intruder_v2.json`이 변경되어 최종 불변 실행과 분리한다.

첫 실행 `native-smoke-first.log`는 342 checks / 1 failure로 보존한다. M01 후 defender picker Enter가 선택을 바꾸지 못했다. 진단에서 popup의 focused item·embedded/window focus는 정확했지만 `PopupMenu.push_input` 직접 주입은 `id_pressed`를 발생시키지 않았다. root embedder `push_input`으로 키를 보내면 실제 `id_pressed` 0/1/2와 popup 닫힘·팩 선택이 발생했다. 이는 [Window의 입력 진입](https://github.com/godotengine/godot/blob/master/scene/main/window.cpp)에서 [PopupMenu의 기본 입력 처리](https://github.com/godotengine/godot/blob/master/scene/gui/popup_menu.cpp)를 호출하는 경로와 일치한다. 최종 helper는 metadata 기반 highlight를 명시적 setup으로 유지하고 실제 Enter가 정확히 한 번 menu activation을 일으켰는지 관찰한다. 제품 callback·source 변경, 신호 직접 emit, OS warp는 없다.

### 첫 full의 실제 실패

이전 동결 확인 뒤 `native-full-first.log`는 1906 checks / 2 failures, exit 1, 35.391초였다. M01–M24와 S01/S02의 실제 A 경로 26건을 완료했고, M24 response_lab의 기본 폼 Run 10회도 실제 실행했다. R01의 첫 `inspect(section=listing)`에서 public `actions.inspect.fields=[]`라 `section` 위젯이 없어 `STRUCTURED_FORM_UNAVAILABLE`로 멈췄다. backend `branch_vm.gd`는 section을 소비하지만 public projection `campaign_model_view.gd`는 노출하지 않는 계약 차이였다. 제품 담당이 section enum 3개를 실제 공개 schema에 추가했고, 콘텐츠 담당은 tracker handoff의 미소비 빈 필드 두 개를 fixture/generator에서 함께 제거했다. raw JSON 우회나 helper의 값 생략으로 통과시키지 않았다.

`native-full-first.json`, `full-first-summary.json`, `full-source-before.json/after.json`을 보존했다. 이 첫 실행의 기본 28경로와 제품 33SHA는 전후 불변, 엔진 ERROR/WARNING/leak는 0이다. 당시 남은 18사건과 전체 3결말은 NOT_RUN으로 보존하며, 이후 최종 full에서 별도로 완료했다. 실제 legacy GUI·다른 유효 해법 GUI와 backend 전체 경로 검증은 각각 별도 증거다.

물리 IME composition, 실제 OS focus·오디오 장치, 사람 청취/피로도/재미, legacy GUI와 다른 유효 해법의 GUI 재생은 NOT_RUN이다. Menu Load unsaved/stale-modal의 심층 회귀는 별도 functional UIcontext suite이고, 이 native suite의 desktop Load와 혼동하지 않는다. 이번 실제 OS 입력 CUA는 host unavailable/native pipe startup 실패로 NOT_RUN이며, 85.728초의 엔진 입력·실제 렌더 완료와 분리한다.
