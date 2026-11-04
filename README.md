# 심야접속 · 가칭

[GitHub 저장소](https://github.com/choijunhuk/packet-trail) · 프로젝트 ID `packet-trail` · 비공개

**심야의 의뢰를 따라 서버에 들어가 자료를 회수하고, 여러 터미널·해킹 도구·가상 브라우저로 감춰진 네트워크와 인물의 진실을 찾아가는 설치형 해킹 시뮬레이터.**

스토리 속에서 도구를 배우고 이전 기술을 조합한다. 소개된 방법을 쓰지 않아도 목표와 제약을 만족하면 진행한다. 제작 권고는 Godot 4+GDScript, 최종 형태는 작은3D 작업실+전체 화면 가상 OS다.

## 먼저 읽을 문서

| 문서 | 내용 |
|---|---|
| [첫 실행 묶음·실행 방법](docs/implementation/2026-11-05-first-playable.md) | M01 구현·검증·실행·현재 범위 |
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

- **P0/P1 첫 실행 묶음이 구현됐다.** 터미널·메일·가상 브라우저·파일·보관소·경보·저장/복구와 M01의 두 완주 경로를 플레이할 수 있다.
- 첫 의뢰는 guest 접근 거부→공개 메모→maint 재접속→scp 회수이며, 가상 웹 보관 사본으로도 완료할 수 있다. 실제 shell·인터넷·사용자 파일을 게임 명령으로 조작하지 않는다.
- 새 작업은 메모리의 세계를 초기화하고 자동저장을 일시중지한다. 이전 디스크 진행은 [저장]을 명시적으로 누르기 전까지 유지한다. 암호 대기는 Esc로 취소한다.
- 현재 콘텐츠는 **M01 한 사건**이다. 8~12시간 캠페인·3D 작업실·캐릭터 정본·다국어·OST는 후속 제작 목표다. 캐릭터 디자인/프롬프트와 3관점 캠페인 계획은 문서로 정리돼 있다.
- 실제 검사 결과·OS별 범위·설치 패키지는 [구현 기록](docs/implementation/2026-11-05-first-playable.md)을 따른다. 헤드리스·렌더/자동UI·실제키보드·사람플레이를 구분한다.
- 가칭 심야접속의 상표·스토어 중복은 확인하지 않았다. 내부 실행파일·저장소 ID는 `MidnightAccess`/`packet-trail`이다.

## 실행

설치형 첫 실행판 **0.1.1-dev**: [Windows·Mac·Linux 다운로드](https://github.com/choijunhuk/packet-trail/releases/tag/v0.1.1-dev). 현재는 M01 한 사건이며, 각 OS 검증 범위는 [전달 기록](docs/implementation/2026-11-05-first-playable.md)을 따른다.

Godot 4.7 standard가 설치된 환경에서 저장소 루트에서 실행한다.

```sh
godot --path godot
```

게임 전체 자동 검증은 `bash tools/gate.sh`다. GUI/IME·실제 각 OS 플레이·사람의 재미 판단은 별도다. 기본 저장은 Godot 사용자 데이터의 `MidnightAccess/saves/slot_01.json`에 기록한다.

## 문서 검증 재실행

```sh
python3 tools/check_docs.py
python3 -m unittest discover -s tools -p 'test_check_docs.py' -v
```

Python 표준 라이브러리만 사용한다. 이 검사는 문서와 문서 검사기용이며 게임 gate·빌드·실제 플레이 검증과 구분한다.
