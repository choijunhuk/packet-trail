# 전체판 1.0.0-rc1 · 네이티브 패키지와 CI 준비

작성일: 2026-11-05 · 작업 트리: `packet-trail-full`, 브랜치: `feat/full-campaign`.
1~7절은 담당자의 **프리셋·패키저·CI 설정 준비와 자체 검사** 당시 기록이다. 이후 root의 실제 export·CI·배포 결과는 8절과 [최종 전체판 기록](2026-11-05-full-production.md)에 있다.
게임 본편과 사용자 진행을 바꾸지 않으며, 자동 publish·새 런타임 의존성·서명 자격 증명을 추가하지 않는다.

## 1. 버전과 export 대상

| 프리셋 | 출력 경로 · 프로젝트 루트 `godot/` 기준 | 메타데이터·서명 |
|---|---|---|
| macOS | `../builds/1.0.0-rc1/macos/MidnightAccess.app` | Universal 2, bundle ID `com.choijunhuk.midnightaccess`, short/build version `1.0.0`, native codesign identity `-` |
| Windows | `../builds/1.0.0-rc1/windows/MidnightAccess.exe` | x86_64, file/product version `1.0.0.0`, Authenticode 꺼짐, 외부 PCK |
| Linux | `../builds/1.0.0-rc1/linux/MidnightAccess.x86_64` | x86_64, 외부 PCK |

프로젝트 버전과 ZIP의 `PACKAGE.json` 버전은 `1.0.0-rc1`이다. OS의 숫자형 버전 필드는 `1.0.0`/`1.0.0.0`으로 표현한다.
`MidnightAccess`는 파일·실행 파일의 ASCII 이름이고 제품 UI의 한국어 표시는 심야접속이다.
macOS는 기존에 선택한 native ad-hoc 설정을 유지한다. Developer ID·공증·스토어 배포 완료를 주장하지 않는다.
공식 템플릿의 Universal 2와 ad-hoc/공증 구분은 [Godot macOS export 문서](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)를 따른다.

## 2. 실제 제품에 필요한 자산과 제외할 작성 자료

`export_filter="all_resources"`로 장면·스크립트·셰이더·인식된 이미지/폰트/음향 리소스를 내보내고, 비리소스 파일은 include 필터로 추가한다.
최종 import를 마친 뒤 export해야 새 OGG·PNG·PO·폰트의 import/remap도 제품에 반영된다.

| 포함 | 이유 |
|---|---|
| `data/campaign/campaign.json`, `data/missions/*.json` | 전체판 코어와 이전 M01 읽기/가져오기 경로에 사용하는 런타임 데이터 |
| `locales/{ko,en,ja,zh_Hans,es,de}.po`와 Godot import 리소스 | `localization.gd`의 실제 로드 경로. 작성용 JSON을 직접 읽지 않음 |
| `assets/audio/**`의 음악·효과음·환경음 리소스 | AudioDirector가 선택하는 런타임 자산. LICENSE/manifest도 명시 포함 |
| `assets/portraits/C01~C04-*.png` 16개와 SOURCE | 인물별 4표정. 얼굴 공개는 UI/서사 정책이 담당하며 파일 존재가 공개 조건은 아님 |
| KR/JP/SC/Mono 폰트·OFL·SOURCE·METADATA | 실제 fallback·Latin 고정폭 글리프와 제작자·출처·라이선스 확인 자료 |
| room 셰이더·UI 마크·장면·코드 | 실제 룸/가상 OS 표시 |
| `LICENSE-Godot.txt`, `THIRD-PARTY-LICENSES.json` | 엔진과 포함 라이브러리 고지 |

제외: `tests/*`, `tools/*`, `*solutions*.json`, `locales/*.json`, `data/campaign/locales/*`, `content_inventory.json`, `locale_revision.json`.
PO 생성용 `campaign.source.json`, narrative/results/common/guidance 원본과 pseudo-layout 계약은 작성·검사용이며 현재 런타임 로드 대상이 아니다.
`tests/fixtures/campaign_solutions.json`은 플레이 검증용 해법 자료이므로 제품에 넣지 않는다. 게임 판정에 필요한 본편 목표·상태 데이터와 구분한다.
이 구분은 파일 기밀성을 보장하는 암호화 장치가 아니다. 런타임 참조가 바뀌면 필터와 실제 PCK 검사도 함께 고쳐야 한다.
초기 필터·자산 정적 확인 뒤 Mono 고지/출처도 추가했다. 현재 외부 고지/출처는15개다. 실제 PCK의 포함·제외 확인 결과는 8절에 있다.

## 3. 표준 라이브러리 ZIP 패키저

[package_game.py](../../tools/package_game.py)는 완성된 로컬 export 디렉터리를 읽는다. Godot·실행 파일·외부 명령을 실행하거나 인터넷에서 자료를 가져오지 않는다.
출력 ZIP에는 `MidnightAccess/` 아래 게임 파일과 읽기 가능한 `licenses/`, `PACKAGE.json`, `SHA256SUMS.txt`가 있다.
고지 15개는 저장소의 현재 엔진·폰트·음향·초상 출처 파일에서 복사한다. 원작 게임의 파일이나 자산을 별도로 추가하는 경로는 없다.

- `PACKAGE.json`: 제품 ID, 버전, 대상 OS/아키텍처, source commit/tree SHA, payload 파일 수와 출처 한계.
- `SHA256SUMS.txt`: payload·고지·PACKAGE.json 전체의 SHA256. 자기 자신은 순환을 피하려고 제외한다.
- stdout: 최종 ZIP 경로·SHA256·파일 수·버전·commit/tree·대상. 외부 릴리스 체크섬 기록에 사용할 수 있다.
- 임시 ZIP을 **출력과 같은 디렉터리**에 작성하고 CRC·항목 중복·SHA 목록·실제 파일 해시를 재검증한 뒤 `os.replace()`한다.
- 실패하면 기존 ZIP을 교체하지 않고 임시 파일을 정리한다. 입력 export 디렉터리는 읽기만 한다.
- 절대/상위 경로·역슬래시·제어문자·Windows 예약명·대소문자/Unicode 정규화 충돌·중복 항목·비정규 파일·심볼릭 링크를 거절한다.
- 설정/정답 fixture/소스 도구·중첩 ZIP·일부 자격 증명 확장자가 export 폴더에 있으면 거절한다. 깨끗한 대상별 staging 디렉터리를 사용한다.
- source의 실행 비트와 알려진 macOS/Linux 실행 파일의 `0755`를 ZIP Unix 속성에 보존한다. 일반 파일은 `0644`다.

동일 입력·메타데이터의 자체 검사에서는 ZIP 바이트 해시가 재현됐다. 일반 실행 파일까지 같은 빌드가 재현된다는 주장과는 다르다.
commit/tree는 호출자가 제공하는 라벨이다. 패키저만으로 해당 export가 그 소스에서 만들어졌다는 사실이나 OS 실행/서명을 증명하지 않는다.
입력 파일의 동시 export/수정은 허용하지 않는다. 프레임워크 심볼릭 링크가 필요한 자산을 도입하면 지원 경계를 먼저 확장해야 한다.
서명한 `.app` 내부에 고지를 덧쓰지 않고 외부 `licenses/`에 복사하므로 코드서명 대상의 바이트를 바꾸지 않는다.

### root가 소스 확정·export 후 실행할 명령

아래 명령은 이 작업에서 실행하지 않았다. 경로는 저장소 루트 기준이며 먼저 각 staging 디렉터리를 준비한다.

```sh
git status --short
source_commit="$(git rev-parse HEAD)"
source_tree="$(git rev-parse 'HEAD^{tree}')"
python3 tools/package_game.py --self-test
python3 tools/package_game.py --input builds/1.0.0-rc1/macos --output builds/packages/MidnightAccess-1.0.0-rc1-macos-universal.zip --source-commit "$source_commit" --source-tree "$source_tree" --target macos-universal
python3 tools/package_game.py --input builds/1.0.0-rc1/windows --output builds/packages/MidnightAccess-1.0.0-rc1-windows-x86_64.zip --source-commit "$source_commit" --source-tree "$source_tree" --target windows-x86_64
python3 tools/package_game.py --input builds/1.0.0-rc1/linux --output builds/packages/MidnightAccess-1.0.0-rc1-linux-x86_64.zip --source-commit "$source_commit" --source-tree "$source_tree" --target linux-x86_64
```

`git status`가 나타낸 변경을 정리하고 export에 사용한 소스 commit/tree와 위 라벨을 맞춘다. 오래된 다른 버전의 ZIP을 staging에 섞지 않는다.
macOS 실제 검증에는 universal 실행 파일 확인, ad-hoc 서명 검증, ZIP을 푼 뒤 실행 비트·서명·실행 재확인이 필요하다.
Windows/Linux의 실행·IME·저장·오디오 검증도 ZIP 생성 성공과 구분한다.

## 4. 3OS 소스 CI

[game-checks.yml](../../.github/workflows/game-checks.yml)은 Ubuntu 24.04/macOS 15/Windows 2025에서 root의 `tools/gate.sh` 전체를 실행한다.
본편·campaign·presentation·locale·문서·경계 검사의 실제 목록은 gate가 소유한다. workflow에서 축소한 별도 통과 경로를 만들지 않는다.
Godot `4.7-stable`, 공식 `godotengine/godot-builds` URL, 고정한 공식 SHA512 목록의 SHA256와 다운로드 archive SHA512 검증을 유지한다.
checkout/setup-python의 기존 commit pin, `contents: read`, Python 3.12, Windows의 python3 보완과 gate의 활성 Bash 전달도 유지한다.
추가 Action·패키지 설치·템플릿 다운로드·자동 export/publish는 없다. 패키저 자체 검사도 각 runner에서 실행한다.

## 5. Linux 소프트웨어 렌더 smoke와 증거

공식 [Ubuntu runner 이미지 목록](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)에 Xvfb가 있지만 실행 중 이미지의 도구 존재는 다시 확인한다.
`xvfb-run`, `Xvfb`, `xauth`가 없으면 설치하지 않고 해당 renderer 검증을 `NOT_RUN`으로 기록한다.
있으면 임시 빈 프로젝트를 virtual X11에서 시작해 소프트웨어 OpenGL 초기화를 확인한다. 이 단계만 성공했다고 제품 GUI PASS를 주지 않는다.
[Mesa의 `LIBGL_ALWAYS_SOFTWARE=true`](https://docs.mesa3d.org/envvars.html)는 소프트웨어 렌더를 요청한다. 실제 로그의 llvmpipe/softpipe도 확인한다.
환경 preflight가 실패하거나 소프트웨어 renderer가 식별되지 않으면 이유·로그와 함께 `NOT_RUN`이다.
환경이 확인되면 **headless 옵션 없이** 실제 source `capture_full_game.gd -- --ci-render-smoke`를 Compatibility/OpenGL로 실행한다. 이 프로필은 M01 1/28사건과 6언어의 부분 GUI 검사다. 나머지27사건·결말 GUI는 NOT_RUN이며, 전체28사건×2해법 headless와 로컬 Mac 전편 GUI를 별도로 보고한다.
이후 제품 스크립트 오류·타임아웃·실패 suite·누락된 capture/metrics는 CI 실패다. 환경 문제라는 이유로 제품 실패를 무조건 건너뛰지 않는다.
성공 조건은 양의 검사 수·빈 failures·실제 OpenGL software 로그·PNG 서명/크기·샘플 명암 차이·파일 SHA256과 helper 기록의 일치다.
job summary에 suite 실행 로그와 renderer, PNG별 크기·샘플 명암 min/max·SHA256을 남긴다. 원본 PNG는 업로드하지 않아 CI 종료 후 다운로드할 수 없다.
소프트웨어 렌더·합성 InputEvent의 성공은 실물 GPU 성능·마우스/키보드 장치·IME 조합·청각 검증을 대신하지 않는다. 오디오는 Dummy다.
[Godot CLI](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)의 `--headless`는 headless display/Dummy audio이므로 픽셀 증거 대용으로 사용하지 않는다.

## 6. Windows WARP와 나머지 renderer의 상태

제품은 OpenGL Compatibility를 사용한다. [Godot renderer 문서](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)에서 D3D12는 Forward+/Mobile의 RenderingDevice 경로다.
[Microsoft 문서](https://learn.microsoft.com/en-us/windows/win32/direct3d12/porting-from-direct3d-11-to-direct3d-12)는 WARP를 D3D12의 명시적인 소프트웨어 adapter 생성으로 설명한다.
[Godot 4.7 공식 소스](https://github.com/godotengine/godot/blob/4.7-stable/drivers/d3d12/rendering_context_driver_d3d12.cpp)는 DXGI software adapter를 CPU 장치로 분류한다.
그러나 이것만으로 해당 Windows hosted runner에서 WARP를 선택해 실제 화면을 그렸다는 증거는 없다. 검증된 강제 선택 절차·실행 결과 없이 PASS로 쓰지 않는다.
이 workflow의 Windows native Compatibility/D3D12-WARP와 macOS hosted-runner GUI는 명시적으로 `NOT_RUN`이다. 3OS headless 통과와 별개다.
새 driver·SDK·소프트웨어 renderer를 설치하지 않는다. root의 실제 OS별 export/GUI 검증과 로컬 macOS 캡처가 후속 증거다.

## 7. 초기 담당 검증과 당시 남은 확인

- 패키저 자체 검사 **10개 PASS**: 세 대상 구조, 실행 권한, 메타/고지/SHA/CRC, 같은 입력 재현, 부정 경로·중복·symlink ZIP 거절, 실패 시 기존 ZIP 보존.
- 초기 프리셋 필터·버전 경로·당시 고지/출처13개·초상16개 존재 확인 PASS. 당시 실제 게임 export의 내부 파일 목록 검증은 미실행.
- workflow YAML/내장 Bash/Python 문법과 공식 Action 2개·읽기 권한 유지 확인 PASS.
- 이번 작업의 전체 gate·3OS 실제 export·CI renderer·패키지 앱 실행·공증·push는 **NOT_RUN**이다.
- `capture_full_game.gd`는 UI API 완성 후 root가 실행한다. helper가 미완성 FAIL을 내는 동안 가짜 성공 보고로 바꾸지 않는다.

## 8. root 최종 실행·배포 결과

소스 `32f31bc9178f494713df28ce61230fb4b5ea6ddd`에서 세 release export를 만들었다. 실제 PCK는 각47항목 PASS, SHA256 `d86471b43a38edc5bf01aa1380e88116920665f1eb132ad44f9e527a606b80d0`으로 동일하다. Mono·6PO·28사건·16초상·7음악을 로드하고 해법 fixture·검사 도구 제외를 확인했다.

[CI41970688330](https://github.com/choijunhuk/packet-trail/actions/runs/41970688330)은 세OS 전체 gate와 패키저10회귀 PASS다. Linux의 Xvfb/Mesa llvmpipe 부분 GUI도 **450항목·M01 1/28·13PNG·100.752초 PASS**이며 NOT_RUN으로 건너뛴 실행이 아니다. 로컬 M3의 기본 full 프로필은 **3,761항목·28사건·498행동·18PNG·84.195초 PASS**다. native 엔진 입력과 실제 OS 조작/물리 장치의 의미를 구분한다.

Mac 최종 ZIP을 별도 폴더에 압축 해제한 뒤 모든 파일 바이트·실행 비트·Universal2·strict/deep ad-hoc 서명을 재검증했다. 그 앱을 CUA로 실행해 저장한 M02 복원, 실제 OS 마우스 A+/A−와 단말 포커스, pwd 입력, 수동 저장, F10/W/E 왕복, 새 게임 확인창을 확인하고 M01로 전달했다. Apple 공증·Windows GUI·Linux 전편 GUI·물리IME·청취는 검증 완료로 표시하지 않는다.

[RC 릴리스](https://github.com/choijunhuk/packet-trail/releases/tag/v1.0.0-rc1)의 세 ZIP은 읽기 가능한 README·15개 고지/출처·PACKAGE.json·내부 전체 파일 해시를 포함한다. 외부 BUILD-INFO.json·SHA256SUMS.txt와 서버 파일 크기·digest도 대조한다. ZIP별 전체 해시와 검증 한계는 [최종 전체판 기록](2026-11-05-full-production.md#아카이브와-체크섬)에 있다.
