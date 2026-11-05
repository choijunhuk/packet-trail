# 전체판 독립 릴리스 소스 검토 — 2026-11-05

판정: **READY — 검토 범위에서 새 Important/Critical 소스 결함 0건.** 이 판정은 독립 정적 소스 검토의 결과다. 최신 전체 native 재실행에는 아래의 입력 검증 실패가 있어 **최종 실행 검증 완료를 뜻하지 않는다**. 리더가 원인을 분리하고 최종 산출물·실행 증거를 연결해야 한다.

검토 기준은 `feat/full-campaign`, `c0e56d48b94fcb68d7d206dd25b6df7aad631947`이다. 제품 구현은 `408cd6d`, 다음 커밋은 Windows 패키저 검사 fixture의 바이트 일관성 수정이다. 작업 트리의 작업실 숨김 최적화, 전체/부분 GUI harness 분기, CI smoke 변경도 읽었다. 검토자는 이 제품의 구현자가 아니며 제품 코드·테스트를 수정하거나 Godot·export·패키지 앱을 실행하지 않았다. 이 보고서만 작성했다.

## 중요 발견

| 분류 | 신규 확인 건수 |
|---|---:|
| Critical | 0 |
| Important | 0 |

실제 소스 결함으로 입증되지 않은 가설, 일반적인 공격 영역, 스타일·재설계 제안은 발견 목록에 넣지 않았다. 게임의 모든 명령·URL·계정·파일은 등록된 허구 세계의 자료다. 검토한 실행 경로에서 실제 셸·네트워크·외부 대상 실행으로 연결되는 호출은 발견하지 않았다.

## 직접 확인한 소스 연결

- **진행·완료·재방문:** [campaign_game.gd](../../godot/scripts/core/campaign_game.gd)의 `choose_mission`, `advance`, `choose_ending`, `_validate_snapshot`, `_sync`와 [campaign_runtime.gd](../../godot/scripts/core/campaign_runtime.gd)의 목표·fact 재계산을 대조했다. 완료 영수증은 이후 재실험과 분리되며 `completion_recorded`와 `current_goals_met`가 UI에서도 구별된다. 확장 결말의 추가 fact는 해당 선택 사건의 실제 목표에 포함되어 있다. 과거 완료의 전역 취소를 요구할 근거는 없다.
- **공통 요청·도구 의미:** `request_page`와 `use_challenge`가 같은 모델 결과를 사용한다. 직접 `/login`은 계정별 auth 모형을 공유하고, 관리형 웹 주체는 발급·철회·논리 만료를 확인한다. Browser와 터미널 요청의 actor/origin/route가 구분된다. 원격 파일은 원본 메타데이터까지 비교하고, 업로드 목표는 현재 저장 파일의 실행 가능 상태도 검사한다. 모델 입력·상태·영수증의 수치 정규화와 재계산이 연결되어 있다.
- **실패·읽기 불변성:** command/request/tool의 실패 rollback과 터미널별 인증 문맥을 확인했다. `get_view(0..3)`와 자동완성은 임시 읽기 문맥을 복구한다. 기존 보고서의 공통 인증·세션·원격 mode·업로드 네 항목을 최신 소스에 그대로 재인용하지 않았다.
- **저장·가져오기:** [save_store.gd](../../godot/scripts/core/save_store.gd)는 검증 후 tmp 재읽기·정상 bak·교체를 수행하며 손상 원본 보존 및 경로/symlink 거절을 가진다. v1 가져오기는 별도 검증 후 campaign 메모리에 적용되고 원본 v1에 쓰지 않는다. UI는 손상/불일치 저장을 정상 신규 상태로 자동 덮어쓰지 않고 자동저장을 중지한다. 주입 저장 경로는 `add_child`/`_ready` 전에 full root → room → desktop → Campaign으로 전달된다.
- **UI 수정:** [campaign_desktop.gd](../../godot/scripts/apps/campaign_desktop.gd) 1839줄에서 secret→일반 전환 전에 입력·draft·history 위치를 지운다. 1278줄에서 활성 터미널 전환 시 도구 문맥을 갱신하고, 2803줄에서 공개 도구 data가 달라지면 관찰 부분만 다시 그린다. UI-01/02/03의 기존 원인은 현재 경로에서 제거되어 있다. 도구/Browser/RequestLab/Board/ending의 행동은 코어 공개 API를 통하고 화면 갱신 뒤 변경 시 자동저장한다.
- **방·설정·음향·언어·자산:** [room.gd](../../godot/scripts/room/room.gd) 299줄의 숨김은 불투명 desktop 뒤 studio에 적용되고, 309/321줄에서 방·메뉴 진입 시 복원된다. desktop 인스턴스와 세션은 유지된다. 설정 모달·포커스·Escape, 별도 preferences 저장, locale 전환, mono/CJK fallback, 오디오 버스/음량/배경/일시정지 연결을 읽었다. 초상은 제품에서 `ResourceLoader`/Texture2D로 읽으며 검사 도구의 `Image.load_from_file` 경고를 제품 export 결함으로 판단하지 않았다.
- **배포·검사:** [export_presets.cfg](../../godot/export_presets.cfg)는 실제 campaign·6 PO·폰트·음악·초상·고지를 포함하고 해법/tests/tools는 제외한다. [package_game.py](../../tools/package_game.py)는 ZIP 경로·중복·symlink·CRC·SHA와 실패 시 이전 ZIP 보존을 검사한다. caller가 준 commit/tree 라벨이 export 출처의 독립 증명은 아니라는 한계도 명시한다. [gate.sh](../../tools/gate.sh)는 suite 결과와 엔진 오류를 모두 검사한다. [CI workflow](../../.github/workflows/game-checks.yml)는 3OS 전체 headless를 유지하고 Linux smoke를 명시적 1/28 부분 GUI 검사로 보고한다. smoke의 나머지 27사건·결말 GUI를 PASS로 확대하지 않는다.

기반 Game/FS/Parser와 필요한 호출부, campaign loader/model/runtime/facade, UI 행동·저장·수명·입력·언어 갱신, presentation/room, data의 대표 목표·요청·서비스·결말 참조, locale/콘텐츠/경계 검사기, QA·계약·기존 코어/UI 검토 보고서를 교차 확인했다. 모든 번역 문장의 의미나 모든 화면의 시각 품질을 정적 소스 검토로 확인했다는 주장은 하지 않는다.

## 실행 증거와 현재 미해결 검증

다음은 리더/기존 실행이 만든 로컬 로그를 직접 읽은 결과다. 검토자가 재실행한 결과와 구분한다.

| 로컬 증거 | 확인한 결과·범위 |
|---|---|
| `.omx/artifacts/full-production/final-gate-perf.log` | 최종 `gate: PASS`; content 3, legacy 336, campaign content 81, campaign 31,717, presentation 275, portraits 36 모두 failures `[]`. portrait 검사 도구의 원본 PNG 읽기 WARNING 16개가 있어 warning 0이라고 쓰지 않는다. |
| `native-full-ui-fixed-green.log` 및 대응 summary | 이전 native 전체 실행 3,761검사/0실패, 28사건, 실제 fixture action 498, PNG 18/6locale. 최신 숨김 최적화·harness 편집 이후의 성공으로 전용하지 않는다. |
| `native-full-perf-final.log` | **FAIL: 752검사/2실패**, `actual mouse press/release activates font button`, `font button pair restores initial size`. 실제 완료는 M01–M04 4사건이며 이후·결말은 미실행. 엔진 ERROR/WARNING은 이 로그에서 발견되지 않았다. |
| `native-ci-render-smoke-summary.json` | 별도 로컬 M3 smoke 451검사/0실패, M01 1사건·6locale·PNG13. 기본 full profile이나 Linux CI 실제 실행의 대체 증거가 아니다. |
| `pck-macos.log`, `pck-windows.log`, `pck-linux.log` | 각 `packed_full_game` 47검사/0실패. PCK 내부 검사는 해당 OS의 제품 GUI 실행과 구분한다. |

최신 native 실패는 [capture_full_game.gd](../../godot/tools/capture_full_game.gd) 479–487줄의 font 버튼 마우스 입력/크기 기대값이다. 제품 `_font_nudge` 연결은 존재하지만 소스만으로 실제 마우스 dispatch·레이아웃/타이밍·환경과 제품 결함을 구별하지 못했다. **단순 harness 문제라고 확정하거나 이전 full PASS로 덮지 않는다.** 입력 실패 원인 분리 및 최신 full 재실행은 리더의 남은 검증이다. 이 실패 자체를 재현된 Important 제품 소스 결함으로 승격하지 않았다.

로그 SHA256:

- `final-gate-perf.log`: `03a67854345ae6165a685126bcfde4bbd5b178d016159f5c09e5ad4b759bfbe7`
- 이전 `native-full-ui-fixed-green.log`: 대응 summary의 `8d37289b7be2d497c6833e7986fa73f7b8536ff34e5d966ff00e3c7b517e51da`
- 최신 실패 `native-full-perf-final.log`: `0e26e4e5e67fbf0840fb4e1ce3acbc97682bbc36253e668b3d435b1ab8e1b2cf`

검토 중 `README.md`, `docs/HANDOFF.md`에 리더의 병행 문서 변경이 나타났다. 제품·검사기·campaign data 등 fingerprint 38개는 수집 전후 동일했다. 2026-11-05T04:28Z 기준 주요 소스 해시는 다음과 같다. 해시 이후 변경은 이 검토의 동작 증거에 포함하지 않는다.

| 파일 | SHA256 |
|---|---|
| `campaign_game.gd` | `00baeaec1facff560cea6540952769cc1b8b8fb953f947b57c1ed6cbbd225a5d` |
| `campaign_runtime.gd` | `72f05cf1181b9cb65ef3f18c122c6a5c2899a27e2625643bd6e00d4d95858571` |
| `campaign_loader.gd` | `3704e932741e6e9da203287301ddd93b3054da70cc1832278643f933836561f9` |
| `tool_runtime.gd` | `5c0538a3c58417283e50df5464a3b28a704804326d34fe1742cd8de60d334a60` |
| `save_store.gd` | `250389ad1e113aca259429bedbba75dde0eb2106bf31d40405a67c25ef058430` |
| `campaign_desktop.gd` | `28c70ec413fd3bc8322bb128bcdee1d9ee57e8628a4a0aad223f27cd8e16050c` |
| `room.gd` | `c6a1ce26248550f8e000c8d139eb754dbb96eec479507ebb5a313b2aa485a774` |
| `capture_full_game.gd` | `46ad3ddd43878ff507cc60e9662b15aa0300a44e0dfdfc65a626c02866315167` |
| `export_presets.cfg` | `bd690c4ffe8a6e2d6679d804dcfdad211da38caee7f287677694a478d75b2711` |
| `package_game.py` | `fbf3ce259b21e10f081a5acbbaf980b385cbb7bd42ad9e4a986a164835d28f58` |
| `.github/workflows/game-checks.yml` | `798a9b4ecf4ebbf06ab6c26ebb47f9341a02120f1dae495c33ce5344d23453ed` |

## 분리해서 남기는 수용 한계

사람의 8–12시간 페이싱·재미·학습 경험, 물리 IME/장치 전환, 원어민 번역 검수, 장시간 청취, Windows 실제 GUI, macOS Intel 실제 실행·Apple 공증은 이 검토에서 미검증이다. 자동 문자 입력·headless·Dummy audio·타 OS 패키지 생성으로 대신 증명하지 않는다. 방어자/추적자 독립 후속 캠페인은 현재 제품의 누락으로 세지 않는다. Claude 최종 독립 검토는 확보되지 않았으며 이 native 검토를 Claude READY로 표기하지 않는다.

변경 파일은 이 보고서 1개다. 제품 단순화·수정은 수행하지 않았다. 남은 위험은 최신 GUI 입력 실패의 미분리 원인과 아직 실행되지 않은 위 수용 환경이며, 새 중요 소스 수정 요구는 없다.
