# 심야접속 · 가칭

[GitHub 저장소](https://github.com/choijunhuk/packet-trail) · 프로젝트 ID `packet-trail` · 비공개

**심야의 의뢰를 따라 서버에 들어가 자료를 회수하고, 여러 터미널·해킹 도구·가상 브라우저로 감춰진 네트워크와 인물의 진실을 찾아가는 설치형 해킹 시뮬레이터.**

스토리 속에서 도구를 배우고 이전 기술을 조합한다. 소개된 방법을 쓰지 않아도 목표와 제약을 만족하면 진행한다. 제작 권고는 Godot 4+GDScript, 최종 형태는 작은3D 작업실+전체 화면 가상 OS다.

## 먼저 읽을 문서

| 문서 | 내용 |
|---|---|
| [1.1 세 관점 구현·검증](docs/implementation/2026-11-05-three-perspectives.md) | 결함 수정·침투 개선·독립 방어/추적·OST 적용과 실제 검증 |
| [수정 전 Claude 검사](docs/reviews/CLAUDE_FULL_AUDIT_20261105.md) | 1.0 감사의 발견·실제 재현과 판단 원본 |
| [1.0 전체판 기록](docs/implementation/2026-11-05-full-production.md) | 이전 전체 캠페인·당시 검증·배포 기록 |
| [실행·조작·저장 안내](docs/PLAYING.md) | 배포 ZIP 실행, 단축키, 저장 백업과 업데이트 |
| [첫 실행 묶음 기록](docs/implementation/2026-11-05-first-playable.md) | 이전 M01 개발판의 당시 구현·검증 범위 |
| [3관점 캠페인 결정](docs/FUTURE_CAMPAIGNS.md) | 초기 제안과 1.1의 세 독립 이야기 |
| [전체 기획](PROJECT_PLAN.md) | 침투의 손맛·이야기·자유도·최종 범위 |
| [2차 피드백 독립 재검토](docs/reviews/CODEX_R2_REVIEW_20261105.md) | 남은 계약 보완·검사기 회귀 검증 |
| [Claude 피드백과 수용 판단](docs/reviews/CLAUDE_FEEDBACK_RESPONSE_20261104.md) | 1·2차 피드백의 채택·수정·보류와 개정 이유 |
| [개발 순서·검증](docs/ROADMAP_AND_QA.md) | 작은 P0/P1에서 3미션·MVP·출시로 확장 |
| [미션·도구 학습](docs/CURRICULUM.md) | 메인24개, M01 거부→재접속→회수 의뢰, 대안 해법 |
| [8~12시간·스토리](docs/PACING_AND_STORY.md) | 메인24+선택4, 분량 예산과 인물/선택 |
| [캐릭터 외형·생성 프롬프트](docs/CHARACTER_ART.md) | 인물 후보4인·공통그림체·영문프롬프트·표정·출력규격 |
| [화면·연출](DESIGN.md) | 기본 경보·침투 피드백, 가상 OS·도구·접근성 |
| [기술 계약](docs/ARCHITECTURE.md) | P1 최소 상태/명령/판정/저장과 이후 확장 |
| [분야 선택](docs/DOMAIN_SCOPE.md) | 네트워크·웹·서버·리버싱/pwn의 투자 순서 |
| [3OS·언어·OST](docs/PLATFORMS_LANGUAGES_AUDIO.md) | 플랫폼별 검증, 다국어, 오리지널 음악 |
| [참고 게임·제작 조사](docs/PRODUCTION_RESEARCH.md) | Hacknet·Anonymous·Grey Hack·NITE |
| [Hacknet 패키지 참고](docs/references/HACKNET_PACKAGE_NOTES_20261104.md) | 사용자 제공 정적 분석과 제한된 식별 확인 |
| [외부 기법·코드 제안 비평](docs/PROPOSAL_REVIEW.md) | 받아들인 원리와 수정한 오류 |
| [AI 작업 기록](docs/AI_WORKFLOW.md) | 모델·추론 수준의 권장과 실제 |
| [문서 검증](docs/PLANNING_VALIDATION.md) | 정적 검사·독립 검토와 검증 범위 |
| [다음 작업](docs/HANDOFF.md) | 현재 단계에서 시작할 최소 작업 |

## 제품 목표와 제작 순서

- Windows/macOS/Linux, 3D 거점+가상 OS, 다국어·OST, 침투 메인24+선택4와 독립 방어8·추적8.
- 플레이타임: 빠른 첫회 약8시간, 충분한 탐색 약12시간. 강제 대기로 시간을 맞추지 않는다.
- 제작 단계: P0 2D 입력 → P1 M01 한 사건 → P2 3미션 시제품 → MVP → 1.0. 범위와 판단은 [단계표](docs/ROADMAP_AND_QA.md#단계별-필수-범위)가 기준이다.

## 현재 상태

**1.1.0-rc1 세 관점 확장의 구현을 마치고 최종 통합·배포 검증 중이다.** 마지막 완료 상태·검증한 소스와 패키지는 [1.1 실행 기록](docs/implementation/2026-11-05-three-perspectives.md)을 따른다. 이전 [1.0 배포본](https://github.com/choijunhuk/packet-trail/releases/tag/v1.0.0-rc1)은 보존한다.

- 침투 메인24+선택4, 방어8, 추적8의 공개44사건. 각 편의 온보딩·이야기·결말·저장이 독립돼 있다.
- 필수 공통 자료66개와 반복 회수 체인을 제거하고, 다섯 복구 사건에 실제 다른 서비스·정책·승인 경로를 통한 대안을 추가했다. 88개 해법 fixture는 실행 경로 수이며 서로 다른88개 퍼즐이라는 뜻은 아니다.
- 방어는 정상 업무와 위협의 실제 요청 결과·격리·부분 복원으로, 추적은 수집한 관측·시간·출처와 가설의 지원/반박/부족으로 판정한다. 선택 R01은 제한된 VM의 분기·호출·정상 입력·반례를 실행한다.
- 터미널4개, Linux식 명령, 가상 브라우저·RequestLab·구조화된 도구 폼·파일·사건 보드·연락처, 작은3D 작업실과 접근성 설정을 공유한다.
- 한국어·영어·일본어·간체 중국어·스페인어·독일어, 2,574키/언어. 번역은 원어민 검수 전 초안이다.
- 강화 원곡 OST7큐와 엔딩 편집본 약20분23초, 효과음12개·환경음, 허구 성인4명의 정본/표정16장.
- 저장 크기·경로·항목 경계, 인증 관측과 보상 분리, 창 순환·활성 세션·음악·불러오기 확인을 수리했다. 기존 진행은 원본을 보존하는 별도 이전판 이어하기로 제공한다.

Claude의 수정 전 감사와 C21/C22 읽기 전용 후속 검토는 실제 회귀 실행과 대조해 수용했다. 요청 모델·실제 응답 모델·추론 수준은 [AI 기록](docs/AI_WORKFLOW.md)에 있다. [캐릭터 실제 제작](docs/implementation/character-production.md)도 별도로 보존한다.

침투편8~12시간은 분량 설계 목표이며 실제 사람의 시간·재미·난이도 측정값이 아니다. 자동/headless·렌더·실제 OS·사람 평가는 실행 기록에서 구분한다. 가칭 상표·스토어 등록·Apple 공증은 완료했다고 주장하지 않는다.

## 실행

ZIP 전체를 압축 해제한 뒤 내부 `MidnightAccess/README.md`를 읽는다. 별도 Godot 설치는 필요 없다.

- [Mac · Apple Silicon/Intel](https://github.com/choijunhuk/packet-trail/releases/download/v1.0.0-rc1/MidnightAccess-1.0.0-rc1-macos-universal.zip)
- [Windows · x86_64](https://github.com/choijunhuk/packet-trail/releases/download/v1.0.0-rc1/MidnightAccess-1.0.0-rc1-windows-x86_64.zip)
- [Linux · x86_64](https://github.com/choijunhuk/packet-trail/releases/download/v1.0.0-rc1/MidnightAccess-1.0.0-rc1-linux-x86_64.zip)

같은 [릴리스](https://github.com/choijunhuk/packet-trail/releases/tag/v1.0.0-rc1)의 `BUILD-INFO.json`과 `SHA256SUMS.txt`에서 소스와 파일 해시를 확인할 수 있다. 저장소와 배포는 비공개다. 이전 M01 개발판은 [0.1.1 기록](docs/implementation/2026-11-05-first-playable.md)으로 보존한다.

소스 개발 실행은 Godot 4.7 standard가 설치된 환경에서 저장소 루트에서 한다.

```sh
godot --path godot
```

게임 전체 자동 검증은 `bash tools/gate.sh`다. GUI/IME·실제 각 OS 플레이·사람의 재미 판단은 별도다. Godot 사용자 데이터 `MidnightAccess/saves/` 안에 `intruder_v2_01.json`, `defender_01.json`, `tracker_01.json`을 분리한다. 이전판은 `legacy_continue_01.json` 사본에서 이어가며 원본 `campaign_01.json`·구버전 `slot_01.json`을 보존한다. 설정은 `MidnightAccess/settings.json`이다. 자세한 경로는 [실행 안내](docs/PLAYING.md#저장과-업데이트)를 따른다.

## 문서 검증 재실행

```sh
python3 tools/check_docs.py
python3 -m unittest discover -s tools -p 'test_check_docs.py' -v
```

Python 표준 라이브러리만 사용한다. 이 검사는 문서와 문서 검사기용이며 게임 gate·빌드·실제 플레이 검증과 구분한다.
