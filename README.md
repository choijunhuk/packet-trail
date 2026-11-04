# 심야접속 · 가칭

[GitHub 저장소](https://github.com/choijunhuk/packet-trail) · 프로젝트 ID `packet-trail` · 비공개

**심야의 의뢰를 따라 서버에 들어가 자료를 회수하고, 여러 터미널·해킹 도구·가상 브라우저로 감춰진 네트워크와 인물의 진실을 찾아가는 설치형 해킹 시뮬레이터.**

스토리 속에서 도구를 배우고 이전 기술을 조합한다. 소개된 방법을 쓰지 않아도 목표와 제약을 만족하면 진행한다. 제작 권고는 Godot 4+GDScript, 최종 형태는 작은3D 작업실+전체 화면 가상 OS다.

## 먼저 읽을 문서

| 문서 | 내용 |
|---|---|
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

- 이 저장소의 현재 납품은 기획·조사·검토 문서다. 게임 코드·실행 가능한 Godot 프로젝트·설치 파일은 아직 없다.
- OST·번역·3D 자산·캐릭터 이미지·8~12시간 플레이·교육 효과는 제작/실측 전 목표다. 캐릭터 외형과 프롬프트는 제안으로 문서화했다.
- 원문 피드백은 보존하고 개정 내역과 새 검증 결과를 함께 기록한다. 과거 READY는 당시 문서 계약에 대한 판단이다.
- 가칭 심야접속의 상표·스토어 중복은 확인하지 않았다. 폴더·GitHub 이름은 그대로 유지한다.

가상 명령은 게임 데이터만 조작한다. 원작 코드·자산을 가져오거나 게임 입력을 실제 shell·외부 서버 호출로 실행하는 계획은 없다.

## 문서 검증 재실행

```sh
python3 tools/check_docs.py
python3 -m unittest discover -s tools -p 'test_check_docs.py' -v
```

Python 표준 라이브러리만 사용한다. 이 검사는 문서와 문서 검사기용이며 게임 gate·빌드·실제 플레이 검증과 구분한다.
