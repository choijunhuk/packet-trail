# 심야접속 · 가칭

[GitHub 저장소](https://github.com/choijunhuk/packet-trail) · 프로젝트 ID `packet-trail` · 비공개

**심야의 의뢰를 따라 서버에 들어가 자료를 회수하고, 여러 터미널·해킹 도구·가상 브라우저로 감춰진 네트워크와 인물의 진실을 찾아가는 설치형 해킹 시뮬레이터.**

스토리 속에서 도구를 배우고 이전 기술을 조합한다. 소개된 방법을 쓰지 않아도 목표와 제약을 만족하면 진행한다. 제작 권고는 Godot 4+GDScript, 최종 형태는 작은3D 작업실+전체 화면 가상 OS다.

## 먼저 읽을 문서

| 문서 | 내용 |
|---|---|
| [전체판 구현·검증](docs/implementation/2026-11-05-full-production.md) | 현재 전체 캠페인·실제 검증·배포 기록 |
| [실행·조작·저장 안내](docs/PLAYING.md) | 배포 ZIP 실행, 단축키, 저장 백업과 업데이트 |
| [첫 실행 묶음 기록](docs/implementation/2026-11-05-first-playable.md) | 이전 M01 개발판의 당시 구현·검증 범위 |
| [후속 3관점 캠페인](docs/FUTURE_CAMPAIGNS.md) | 침투자·방어자·추적자의 독립 이야기 |
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

- 최종: Windows/macOS/Linux, 3D 거점+가상 OS, 다국어·OST, 메인24+선택4.
- 플레이타임: 빠른 첫회 약8시간, 충분한 탐색 약12시간. 강제 대기로 시간을 맞추지 않는다.
- 제작 단계: P0 2D 입력 → P1 M01 한 사건 → P2 3미션 시제품 → MVP → 1.0. 범위와 판단은 [단계표](docs/ROADMAP_AND_QA.md#단계별-필수-범위)가 기준이다.

## 현재 상태

**전체 캠페인 1.0.0-rc1 구현·검증·3OS 패키지 배포 완료.** [배포본 다운로드](https://github.com/choijunhuk/packet-trail/releases/tag/v1.0.0-rc1)에서 설치형 게임을 받을 수 있다.

- 6장 메인24 + 선택 S01·S02·R01·P01, 서로 다른 해법56개, 근거에 따른 결말3개.
- 113개 사건별 가상 호스트, 89개 필수 자료와 연쇄 근거. 소개된 도구·힌트·읽기 순서 자체는 완료 조건이 아니다.
- 독립된 터미널4개와 Linux식 명령, 가상 브라우저·RequestLab·분석 도구·파일/보관 자료·사건 보드·연락처·일시정지.
- 작은3D 야간 작업실, WASD/RMB/E/F10 전환, 접근성·글자 크기·개별 음량·화면 설정.
- 한국어·영어·일본어·간체 중국어·스페인어·독일어: 1,443키/언어. 번역은 원어민 검수 전 초안이다.
- 원곡 OST7큐 19분51.64초·효과음·환경음, 성인 허구 인물4명의 정본/표정16장.
- 안전한 campaign v2 고정 슬롯, 명시적인 구버전 M01 가져오기. 구버전 슬롯은 자동 덮어쓰지 않는다.

세OS 전체 headless CI, 개발 Mac의 실제 렌더·입력 3,761항목/28사건 완주, Linux 소프트웨어 렌더 부분 GUI 450항목/첫 사건, 세 패키지의 실제 PCK 각47항목이 통과했다. 최종 Mac ZIP은 압축 해제 뒤 실제 OS 마우스·키보드·저장 복원·3D 왕복도 확인했다. 소스·체크섬·독립 검토·한계는 [전체판 기록](docs/implementation/2026-11-05-full-production.md)을 따른다. 8~12시간은 분량 예산이며 실제 사람의 플레이타임·재미로 측정한 수치가 아니다.

후속 방어자·추적자 캠페인은 같은 세계관의 독립 이야기로 기획돼 있으며 이번 침투자편을 세 편으로 나누지 않는다. [캐릭터 실제 제작](docs/implementation/character-production.md), [모델·추론 수준](docs/AI_WORKFLOW.md)을 함께 기록했다. 가칭 상표·스토어 등록·Apple 공증은 완료했다고 주장하지 않는다.

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

게임 전체 자동 검증은 `bash tools/gate.sh`다. GUI/IME·실제 각 OS 플레이·사람의 재미 판단은 별도다. 기본 캠페인 저장은 Godot 사용자 데이터의 `MidnightAccess/saves/campaign_01.json`, 설정은 `MidnightAccess/settings.json`이다. 구버전 `saves/slot_01.json`은 명시적 가져오기용으로 보존한다. 파일 이름·캐노니컬 자료와 번역 표시를 분리한다.

## 문서 검증 재실행

```sh
python3 tools/check_docs.py
python3 -m unittest discover -s tools -p 'test_check_docs.py' -v
```

Python 표준 라이브러리만 사용한다. 이 검사는 문서와 문서 검사기용이며 게임 gate·빌드·실제 플레이 검증과 구분한다.
