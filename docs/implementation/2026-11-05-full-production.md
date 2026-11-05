# 심야접속 전체 제작·검증 기록

## 사용자 지시와 완료 범위

2026-11-05 사용자는 첫 실행판에서 멈추지 말고 끝까지 완성하며, 사람의 피드백은 나중에 주겠다고 명시했다. 따라서 P2/MVP 같은 중간 이정표에서 승인 대기나 턴 종료를 하지 않는다. 기존 `939bbcc`/0.1.1 실행판은 보존하고 `feat/full-campaign` 작업트리에서 전체 제품을 만든다.

제작 범위는 기존 [프로젝트 계획](../../PROJECT_PLAN.md)의 메인24+선택4·6장 서사와 선택 결말, 목표 기반 대안 해법, 여러 터미널·Linux식 명령·네트워크/웹/권한/로그/패킷/선택 리버싱과 포너블, 작은3D 작업실, 6언어, 오리지널 OST7큐, 설정/접근성/안전 저장·업데이트, Windows/macOS/Linux 패키지다. 방어자/추적자 캠페인은 합의한 별도 후속편이며 이번 침투자편의 분량을 세 편으로 나누지 않는다.

8~12시간은 콘텐츠 제작 예산이다. 실제 사람의 플레이타임·재미·원어민 언어 품질·각 OS 물리 IME·공증/스토어 등록은 자동 검증으로 대신하지 않는다. 이것을 이유로 제작 가능한 기능을 중단하지 않으며, 최종 검증표에서 증거의 종류와 한계를 구분한다.

## 변경이 닿는 범위

- 새 CampaignGame/Runtime/Loader가 공통 상태·요청·목표·복수 터미널·세이브v2를 맡는다. 기존 Game/FS/Parser/Store와 M01 회귀336항목은 유지하고 필요한 부분을 재사용한다.
- 전체 캠페인 JSON·canonical 자료·별도 표시 문자열·해법 fixture를 작성한다. 튜토리얼/특정 도구는 캠페인 통과 조건이 아니다.
- Claude는 새 campaign_desktop.gd/scene의 제품 UI를 맡고 Codex는 코어·콘텐츠·3D·언어·음악·독립 검증을 맡는다. 원작 파일이나 다른 프로젝트를 수정하지 않는다.
- 부트 장면/프리셋/번역·폰트/오디오·gate/CI/패키징/README/검증표까지 연결한다. 실행된 코드와 배포 파일의 소스·체크섬을 기록한다.

## 제작 순서

1. 캠페인 계약과 전체 QA 계약을 고정하고 파일 소유를 나눈다.
2. 코어, 28사건 콘텐츠, Claude UI, 3D 작업실/설정, 6언어, OST/효과음을 병렬 제작한다.
3. 부모가 한 제품으로 연결한 뒤 첫 전체 import/content/core/campaign/locale/boundary 묶음을 실행한다. 자잘한 편집마다 전체 빌드를 반복하지 않는다.
4. 모든 사건의 서로 다른 유효 경로·진행/결말·저장·부정 입력을 자동 재생하고 실제 네이티브 화면/입력/3D/오디오 상태를 검증한다.
5. fresh Claude와 Codex 독립 검토의 중요한 발견을 비판적으로 판단하고 회귀로 재현·수정한다. 동의를 실행 증거로 쓰지 않는다.
6. 세 OS 소스 CI·export·최종 패키지 검사·비공개 release·문서/해시 검증까지 수행한다. 이 단계까지 진행한 뒤 전체 결과와 사람이 나중에 평가할 항목을 전달한다.

## 소유·모델 기록

| 레인 | 실제/요청 모델·수준 | 소유 |
|---|---|---|
| 부모 | gpt-6.1-sol/max | 통합·부트·gate/CI·이미지 자산·실제 검증·배포 |
| 코어 | gpt-6.1-sol/xhigh | campaign_*·공통 도구 runtime·캠페인 계약 |
| 콘텐츠 | gpt-6.1-sol/high | data/campaign·제작 helper·독립 해법 fixture |
| 공간/설정 | gpt-6.1-sol/high | room scene/scripts·settings store/panel |
| 검증 | gpt-6.1-sol/xhigh | 전체 QA 계약·campaign/validator 부정/재생 검사 |
| 음향 | gpt-6.1-sol/high | 원곡7큐·효과음·AudioDirector·재현 generator |
| 현지화 | gpt-6.1-sol/high | 6PO·공식 CJK fallback·locale 검사/API |
| UI | claude-opus-5-5/high 요청 | 새 전체 캠페인 데스크톱/장면·UI 문자열 |
| 최종 독립 검토 | claude-opus-5-5/xhigh 요청, Codex6.1/xhigh | 구현자와 분리한 전체 검토 |

네이티브 실행기와 CLI 응답의 실제 모델/성공 여부를 확인한다. 이미지 생성은 imagegen 스킬의 내장 도구를 사용하며 모델 선택 옵션이 없는 경우 모델명을 추정하지 않는다.

## 정확성·보존 기준

상태·콘텐츠·저장·UI·관측을 분리한다. 가상 경로/요청/도구 입력이 실제 OS·네트워크·임의 코드가 되지 않는다. 열린 포트만으로 셸을 주지 않는다. 문서에서 다루는 기술은 최소 실제 조건·관측·상태 전이로 모델링한다. 단순 정답 문자열 한 개를 넣고 자료를 지급하는 반복을 전체 캠페인으로 포장하지 않는다.

새 저장은 고정 `campaign_01` 슬롯과 v2를 사용한다. 기존 v1 슬롯은 명시적으로 검증·가져오며 자동 덮어쓰지 않는다. 교체 실패/손상/백업/잘못된 snapshot은 기존 상태·원본을 보존한다. UI의 선택/캐시는 세계 교체 뒤 유효성을 다시 확인한다.

## 검증 기록

아래 전반부는 제작 과정과 실패→수정 판단 기록이며 마지막 절이 최종 RC 배포 상태다. 계획에 존재한다는 이유로 구현/검증 완료로 표시하지 않는다.

## 첫 전체 통합 결과와 수정 판정

실제 실행으로 기존 M01 content3/코어·저장336을 보존했다. 새 캠페인의 첫 실패는 미션별 schema_version 누락이었으며 원본 규격을 완화하지 않고 생성 데이터를 교정했다. 이어 B의 gateway 경유와 M15/M17/M22의 현재 세션 순서를 고쳐 모든 경로를 실제 도달 관계로 재생했다. `via`를 local로 풀어 통과시키지 않았다.

독립 코어 검토의 HTTP 로그인 제한·만료 웹 세션·원격 파일 mode 변조·업로드 현재 실행 안전·부가 결말의 후속 근거 누락을 실제 부정 회귀로 재현하고 보완했다. 후일담에 필요한 post 자료는 추가 결말 조건에 포함하고 기본 봉인 감사 결말은 유지했다.

M20의 유효 진행이 복원을 거절하던 문제는 숫자 정규형 불일치였다. JSON 정의의 integral float와 검증된 snapshot int를 같은 규칙으로 정규화하고, 모델 재계산과 canonical 비교 자체는 유지했다. [Godot Variant 비교 소스](https://github.com/godotengine/godot/blob/4.7-stable/core/variant/variant.cpp#L3038). 테스트의 `recursive_equal(...,96)`도 시작 재귀 깊이와 최대 깊이를 혼동한 것이어서 0으로 수정하고 전체 깊은 값 비교를 유지했다.

`grep -i -n`의 단락 평가 때문에 옵션을 소비하지 않던 반복은 기존 실제 가상 파일에서 8초 timeout으로 재현했다. 옵션 pop을 독립 실행하고 실제 Godot 20초 deadline 회귀를 추가했다. 문서 검사 fixture는 새 검토 보고서의 코드/워크플로 링크 대상도 복제하도록 보완했다. 패킷 rows.body는 번역 문구가 아니라 관측 데이터임을 정적 검사에서 구분했다.

마지막 전체 headless gate는 다음과 같다. 세부 로그는 로컬 `.omx/artifacts/full-production/full-gate-ui-fixed.log`에 있다.

| 검사 | 결과·실행 범위 |
|---|---|
| 기존 content / M01·저장 | PASS 3 / 336항목 |
| 전체 콘텐츠 | PASS 81항목 |
| 캠페인 | PASS 31,717검사항목, 28사건×2 fresh-engine 해법·모든 결말·부정·v2/구버전 가져오기 |
| presentation 계약 | PASS 275항목, 설정/locale/font/audio·격리 경로 |
| portrait 실제 이미지 | PASS 36항목 |
| Python / 경계 자체 회귀 | PASS 35 / 5테스트 |
| 실행 경계 | PASS 런타임18스크립트, 파일 어댑터 외 IO 및 실제 프로세스/네트워크 API 거절 |

이 수치는 서로 다른 테스트 함수 수와 독립 사용자 수가 아니다. 캠페인 검사항목에는 선수 사건 재생과 반복 검증이 포함된다. 콘텐츠 예산480+240분이 실제 사람의 플레이타임 증거는 아니다.

## 실제 native 화면·입력 검증 중간 기록

M3 Max OpenGL 실제 렌더에서 메뉴·3D·설정·전 캠페인·결말·6언어 큰 글씨까지 주입 입력으로 도달했다. 자식 확인창의 mouse viewport hover를 합성 입력이 갱신하지 못한 문제는 target Window의 실제 KEY_ENTER 입력으로 분리했고 버튼 신호를 직접 호출해 통과시키지 않았다. 실제 OS 포인터를 이동하는 진단은 반복하지 않고 제거했으며 최종 OS 마우스 검증은 CUA로 분리한다.

암호 입력에서 Tab은 정상 포커스 이동이며 자동완성으로 비밀을 노출하지 않는다. 테스트가 포커스를 되돌리지 않고 Esc를 보내 pause를 열던 기대값을 고쳤다. failed test의 즉시 quit 때 생긴 Ogg 잔류 경고는 stop·stream 해제·scene free 뒤 frame 정리로 사라졌다. 이를 제품 메모리 누수 없음으로 확대하지 않는다.

fresh UI 검토의 Important3는 기존 소스에서 실제 752항목/10실패로 재현했다. 암호→일반 모드 전환 전에 비밀 입력/초안을 지우고, 터미널 선택 때 Tools 주체를 갱신하며, 공개 관찰 data가 바뀌면 관찰 부분만 다시 그리도록 보완했다. 초안·결과·기존 단일 코어 권위를 유지한다. 최종 native 재생 수치와 fresh Opus 검토/패키지 결과는 완료 후 이어 기록한다.

최종 인라인 Claude 검토는 요청 Opus5.5/xhigh, 응답READY·확인된중요결함0이었다. 실제 modelUsage에는5.5와4.8이함께기록되어최종화자귀속은미확인이다. 요청값/실제서비스사용모델을분리해 [AI기록](../AI_WORKFLOW.md)에남겼고단독5.5동의로실행검증을대신하지않았다. fresh Codex6.1/xhigh독립검토도READY이며최신GUI실행한계와소스판정을구분했다.

## 최종 RC 배포와 소스

[1.0.0-rc1 다운로드](https://github.com/choijunhuk/packet-trail/releases/tag/v1.0.0-rc1) · [실행·조작·저장 안내](../PLAYING.md) · [검증한 소스 CI](https://github.com/choijunhuk/packet-trail/actions/runs/41970688330)

- 배포 소스 commit: `32f31bc9178f494713df28ce61230fb4b5ea6ddd`.
- 배포 source tree: `0f319f5c665901836a60d73995b00f4acaa71ff6`.
- 게임 `godot/` tree: `0dfafb1b3620f27e081d67eea215556035aaf705`.
- 엔진: `4.7.stable.official.5b4e0cb0f`, 세OS 모두 실제 release export 성공.

최종 문서 커밋은 위 배포 소스와 다를 수 있다. 게임 하위 트리와 최종 패키지 소스 라벨을 별도로 대조한다. 패키저에 commit 값을 입력했다는 사실만으로 출처를 증명하지 않으며, clean Godot subtree·실제 export 로그·PCK·CI·아카이브 해시를 함께 확인했다. 작업 중 원본 `packet-trail`의 `.serena/`와 기존 개발판/구버전 저장을 보존했다.

## 최종 검증표

| 범위 | 실제 결과 | 의미·한계 |
|---|---|---|
| 세OS 전체 source CI | Windows 2025/macOS15/Ubuntu24.04 모두 PASS | 각각 전체 gate·패키저10회귀. GUI와 구분 |
| Mac 전편 실제 렌더/엔진 입력 | PASS 3,761검사항목·28사건·498행동·84.195초·18PNG | 실제 M3/OpenGL, 대안56개 중 GUI는 A경로28개. 두 경로는 headless에서 모두 실행 |
| Mac 부분 프로필 | PASS 451항목·M01·6.483초·13PNG | CI smoke 프로필의 로컬 동작 확인 |
| Linux Xvfb/Mesa 부분 GUI | PASS 450항목·M01 1/28·100.752초·6언어·13PNG | 실제 llvmpipe LLVM20.1.2/OpenGL4.5. 나머지27사건·결말 GUI는 NOT_RUN |
| 실제 세 PCK | 각47항목 PASS | 28사건·번역·초상·7음악·폰트·라이선스 로드, 해법 fixture/검사 코드 제외 |
| Mac 최종 ZIP | 모든 추출 파일 바이트 일치·실행 비트·strict/deep 코드서명 PASS | Universal2 `x86_64 arm64`, ad-hoc이며 공증 아님 |
| 최종 ZIP 앱 실제 OS 조작 | PASS | CUA 실제 마우스 A+/A−와 터미널 포커스/pwd, M02저장복원·수동저장, F10/W/E왕복, 새게임 확인창, M01 첫 의뢰로 전달 |
| 독립 소스 검토 | fresh Codex READY, Claude C17 READY | 새 확인 Important/Critical0. 실행 증거는 위 검증이 담당 |

마지막 native helper는 static/occluded 창에서도 모든 입력 뒤 draw가 발생한다고 가정하던 무조건 `frame_post_draw` 대기를 제거했다. 일반 입력은 process frame으로 처리하고 캡처에서만 `RenderingServer.force_draw(false)`로 실제 화면을 만든다. 포인터 stream은 held frame 뒤 같은 위치의 motion과 release로 완결하며 OS 포인터 워프·버튼 신호 직접 emit으로 통과시키지 않는다. 변경 후 smoke/full 모두 새로 종료코드0, 엔진 Script ERROR/ERROR/WARNING/잔류 경고0, 기본 캠페인·구버전 저장·설정 바이트 보존을 확인했다.

원본 M01 Game/FS/Parser/Store를 재사용했고, 제품에 테스트 전용 입력 API나 검토용 임의 코드 실행 경로를 추가하지 않았다. opaque 가상 OS 뒤의 보이지 않는 3D만 숨겨 소프트웨어 렌더 부하를 줄인다. 새로운 런타임 의존성은 없다.

최종 로컬 증거는 `.omx/artifacts/full-production/`의 `native-coherent-forceframe-{full,smoke}.log`, `native-coherent-forceframe-summary.json`, `ci-final-32f31bc.log`, `export-final-source.json`, `export-final-{macos,windows,linux}.log`, `pck-final-{macos,windows,linux}.log`, `package-final-{macos,windows,linux}.json`, `extracted-final-macos.json`이다. CI 로그는 위 실행 링크에서도 확인한다. Linux PNG는 CI 종료 뒤 별도 업로드되지 않으며 로그의 치수·명암·SHA만 남는다.

## 아카이브와 체크섬

| ZIP | 바이트 | SHA256 |
|---|---:|---|
| `MidnightAccess-1.0.0-rc1-macos-universal.zip` | 111,228,754 | `378343752c89f2c47f894334e9f37376a908e00b4d3e32939a3cdf122749d137` |
| `MidnightAccess-1.0.0-rc1-windows-x86_64.zip` | 89,940,589 | `1fa21a0a0fc6a4829cf4cc9db93d73740c5fc444fa17c216d80da4a767e39d1e` |
| `MidnightAccess-1.0.0-rc1-linux-x86_64.zip` | 80,334,509 | `1a420165c6a60da4b117c99316b48701892015def72a9a4dde861a56582b3b22` |

세 PCK의 SHA256은 모두 `d86471b43a38edc5bf01aa1380e88116920665f1eb132ad44f9e527a606b80d0`으로 동일하다. 배포 ZIP은 로컬 `builds/releases/v1.0.0-rc1/`에도 있다. 각각 외부 `licenses/` 15개 고지/출처 파일, README, `PACKAGE.json`, 파일별 `SHA256SUMS.txt`를 포함한다. GitHub 릴리스의 `BUILD-INFO.json`은 commit/tree/엔진/검증 종류·한계·크기를 함께 기록한다. 릴리스 서버의 크기·SHA256도 로컬 다섯 자산과 대조한다.

## 이후 사람이 평가할 범위

기능·자료·패키지를 모두 연결한 RC다. 실제8~12시간·재미/난이도·장시간 음악 피로도·원어민 문장·물리 IME와 기기별 오디오·Windows 실제 GUI·Linux 전편 GUI는 완료 증거가 없다. 확인되지 않은 플레이타임을 강제 대기나 자동 해법 소요시간으로 대체하지 않는다. macOS Apple 공증과 Windows 인증서 서명도 미실시다.

Linux식 명령은 구현한 부분집합이며 진짜 Linux 전체가 아니다. 메모·핀은 현재 세션용이다. 한 저장 슬롯에 동시 여러 인스턴스 쓰기는 지원하지 않는다. 방어자·추적자 캠페인은 별도 후속 기획이며 이번 침투자편의 누락 콘텐츠로 취급하지 않는다. 사용자의 후속 피드백은 재현 조건과 영향으로 검토해 다음 변경에 반영한다.
