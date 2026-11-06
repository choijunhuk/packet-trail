# 심야접속 · 가칭

[GitHub 저장소](https://github.com/choijunhuk/packet-trail) · 프로젝트 ID `packet-trail` · 비공개

**심야의 의뢰를 따라 서버에 들어가 자료를 회수하고, 여러 터미널·해킹 도구·가상 브라우저로 감춰진 네트워크와 인물의 진실을 찾아가는 설치형 해킹 시뮬레이터.**

스토리 속에서 도구를 배우고 이전 기술을 조합한다. 소개된 방법을 쓰지 않아도 목표와 제약을 만족하면 진행한다. 제작 권고는 Godot 4+GDScript, 최종 형태는 작은3D 작업실+전체 화면 가상 OS다.

## 먼저 읽을 문서

| 문서 | 내용 |
|---|---|
| [1.4 선택 의뢰·생활 공간](docs/implementation/2026-11-06-optional-living.md) | 독립 의뢰·안뜰·현장 일감·주문/수령/데스크 꾸미기 |
| [1.3.1 앱별 색 역할](docs/implementation/2026-11-06-color-refinement.md) | 균일한 남색 개선·앱 식별색·대비/실제화면 검증 |
| [1.3 종합 도전·분석 작업대](docs/implementation/2026-11-06-challenge-workbench.md) | 실제 복합제약3사건·작업대·실패 재현/복구·최종 검증 |
| [전체 발전 계획](docs/EVOLUTION_PLAN.md) | 실제성·게임성·디테일·시각성의 우선순위와 보류 범위 |
| [1.2.1 시각·조작·난이도 점검](docs/implementation/2026-11-06-immersion-quality.md) | 사이트 문서·큰 글씨 폼·명령 재사용·실제 경보 안내와 검증 |
| [1.2 데스크톱·첫 플레이](docs/implementation/2026-11-06-desktop-experience.md) | 시나리오/지원·설정·바탕화면/런처·탭 브라우저와 실제 검증 |
| [1.1 세 관점 기록](docs/implementation/2026-11-05-three-perspectives.md) | 이전 침투 개선·독립 방어/추적·OST와 당시 배포 증거 |
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

**1.4.0-rc1은 본편의 네 선택·47사건을 유지하면서 독립 선택 의뢰 2개와 작은 3D 안뜰·생활 공간을 추가했다.** [다운로드](https://github.com/choijunhuk/packet-trail/releases/tag/v1.4.0-rc1) · [변경·검증 기록](docs/implementation/2026-11-06-optional-living.md).

- 사건 보드에서 IAM·공급망/보고 의뢰를 자유롭게 고르고 원래 본편으로 돌아온다. 새 분야는 메인 필수가 아니다.
- 작업실에서 안뜰로 나가 배송을 받거나 선택 통신함 일감을 수행한다. 벤치에서는 밤/새벽 분위기를 바꾼다.
- 데스크샵 주문→배송함 수령→키보드·모니터·조명 장착이 실제 외형에 반영된다. 시작 크레딧으로 구매 상품 전부를 살 수 있어 반복 노동이 필요 없다.
- 작은 거점형 공간과 고정 장착 슬롯이다. 거대한 도시·가구 자유 배치·실제 결제는 포함하지 않는다. 의뢰와 생활 저장은 본편에서 분리된다.
- 검증: 전체 gate, 본편 native6,286/47사건/4결말, 선택·생활 native688, 생활 저장1,068, 세OS 패키지 각564. 물리 OS 장시간 플레이·8~12시간 실측은 별도다.


**1.3.1-rc1은 공통패널을 차콜로 정리하고 앱별 제목·선택·포커스·아이콘 색을 구분했다. 1.3의47사건과 분석 작업대는 유지한다.** [다운로드](https://github.com/choijunhuk/packet-trail/releases/tag/v1.3.1-rc1) · [이번 변경·검증 기록](docs/implementation/2026-11-06-color-refinement.md). 이전 [1.3 배포본](https://github.com/choijunhuk/packet-trail/releases/tag/v1.3.0-rc1)·[1.2.1 배포본](https://github.com/choijunhuk/packet-trail/releases/tag/v1.2.1-rc1)·[1.2 배포본](https://github.com/choijunhuk/packet-trail/releases/tag/v1.2.0-rc1)·[1.1 배포본](https://github.com/choijunhuk/packet-trail/releases/tag/v1.1.0-rc1)과 [1.0 배포본](https://github.com/choijunhuk/packet-trail/releases/tag/v1.0.0-rc1)은 보존한다.

- 바탕화면 아이콘·검색 런처에서 앱을 열고 실행 중 작업표시줄로 최소화·복원한다. 창 이동·크기·최대화·제목줄 조작과 초안/세션을 보존한다.
- Nightfox는 최대8개 탭과 사이트 문서 표면·호스트·제목·본문·링크를 제공한다. 큰 글씨에서도 폼/하단까지 스크롤하고 현재 요청 주체와 과거 응답을 구분한다. Alt+좌/우·Ctrl/Cmd+R·F5와 터미널 접두어 기록 탐색을 지원한다.
- 시작 화면에서 네 가지 선택과 진행을 확인하고 가이드·표준·자율을 선택한다. 이는 **안내·힌트량**이며 목표/경보를 바꾸는 압박 난이도는 아직 없다.
- 일반 설정15개와 편별 지원5개를 플레이/화면/음향/조작으로 묶었다. 키보드 카테고리 탐색·적용/취소·읽기 실패 원본/backup·임시 지원을 보존한다.

- 침투 메인24+선택4, 방어8, 추적8의 기존44사건에 독립 종합 도전3사건을 더한 공개47사건. 각 편의 온보딩·이야기·결말·저장이 독립돼 있다.
- 필수 공통 자료66개와 반복 회수 체인을 제거하고, 다섯 복구 사건에 실제 다른 서비스·정책·승인 경로를 통한 대안을 추가했다. 88개 해법 fixture는 실행 경로 수이며 서로 다른88개 퍼즐이라는 뜻은 아니다.
- 방어는 정상 업무와 위협의 실제 요청 결과·격리·부분 복원으로, 추적은 수집한 관측·시간·출처와 가설의 지원/반박/부족으로 판정한다. 선택 R01은 제한된 VM의 분기·호출·정상 입력·반례를 실행한다.
- 종합 도전은 정상 업무/접근 통제/인증 제한, 현재 파일 내용/통지 범위, 복합 관측/반례를 함께 만족한다. 독립 슬롯과 두 유효 해법씩을 제공하며 기존 캠페인의 규칙을 바꾸지 않는다.
- 도구 작업대는 관찰과 행동·결과를 나누고 공개 기록의 펼침/행 상세·유효한 선택을 보존한다. 현재 목표 바로가기와 첫 안내/중요 실패 알림도 개선했다.
- 터미널4개, Linux식 명령, 가상 브라우저·RequestLab·구조화된 도구 폼·파일·사건 보드·연락처, 작은3D 작업실과 접근성 설정을 공유한다.
- 한국어·영어·일본어·간체 중국어·스페인어·독일어, 2,993키/언어. 번역은 원어민 검수 전 초안이다.
- 강화 원곡 OST7큐와 엔딩 편집본 약20분23초, 효과음12개·환경음, 허구 성인4명의 정본/표정16장.
- 저장 크기·경로·항목 경계, 인증 관측과 보상 분리, 창 순환·활성 세션·음악·불러오기 확인을 수리했다. 기존 진행은 원본을 보존하는 별도 이전판 이어하기로 제공한다.

Claude의 이전 감사와 C23·C24 및 C25 새 콘텐츠/작업대 검토(Opus5.5/high)를 실제 회귀 실행과 대조해 수용했다. 요청 모델·실제 응답 모델·추론 수준은 [AI 기록](docs/AI_WORKFLOW.md)에 있다. [캐릭터 실제 제작](docs/implementation/character-production.md)도 별도로 보존한다.

현재색상소스에서 기존88해법+새도전6해법의 전체gate·1,270개 native검사/71PNG·대비44조합을 확인했다. 1.3의47사건/네 결말 GUI재생은 이전버전 근거이며 이번색상버전에서 반복하지 않았다. Mac 최종ZIP의시작/작업실이동/메뉴/종료도 별도확인했다. 1.3 독립 UX 수정 확인92/pass는 해당 캡처의 사용성 판정이며 사용자 미적 승인이나 사람 플레이시간 증거는 아니다. [현재 소스 CI](https://github.com/choijunhuk/packet-trail/actions/runs/42179897714)와 상세 기록에서 hosted3OS·실제PCK/ZIP·OS·사람 수락을 구분한다.

침투편8~12시간은 분량 설계 목표이며 실제 사람의 시간·재미·난이도 측정값이 아니다. 자동/headless·렌더·실제 OS·사람 평가는 실행 기록에서 구분한다. 가칭 상표·스토어 등록·Apple 공증은 완료했다고 주장하지 않는다.

## 실행

ZIP 전체를 압축 해제한 뒤 내부 `MidnightAccess/README.md`를 읽는다. 별도 Godot 설치는 필요 없다.

- [Mac · Apple Silicon/Intel](https://github.com/choijunhuk/packet-trail/releases/download/v1.3.1-rc1/MidnightAccess-1.3.1-rc1-macos-universal.zip)
- [Windows · x86_64](https://github.com/choijunhuk/packet-trail/releases/download/v1.3.1-rc1/MidnightAccess-1.3.1-rc1-windows-x86_64.zip)
- [Linux · x86_64](https://github.com/choijunhuk/packet-trail/releases/download/v1.3.1-rc1/MidnightAccess-1.3.1-rc1-linux-x86_64.zip)

같은 [릴리스](https://github.com/choijunhuk/packet-trail/releases/tag/v1.3.1-rc1)의 `BUILD-INFO.json`과 `SHA256SUMS.txt`에서 소스와 파일 해시를 확인할 수 있다. 저장소와 배포는 비공개다. 이전 M01 개발판은 [0.1.1 기록](docs/implementation/2026-11-05-first-playable.md)으로 보존한다.

소스 개발 실행은 Godot 4.7 standard가 설치된 환경에서 저장소 루트에서 한다.

```sh
godot --path godot
```

게임 전체 자동 검증은 `bash tools/gate.sh`다. GUI/IME·실제 각 OS 플레이·사람의 재미 판단은 별도다. Godot 사용자 데이터 `MidnightAccess/saves/` 안에 `intruder_v2_01.json`, `defender_01.json`, `tracker_01.json`, `challenge_01.json`을 분리한다. 이전판은 `legacy_continue_01.json` 사본에서 이어가며 원본 `campaign_01.json`·구버전 `slot_01.json`을 보존한다. 설정은 `MidnightAccess/settings.json`이다. 자세한 경로는 [실행 안내](docs/PLAYING.md#저장과-업데이트)를 따른다.

## 문서 검증 재실행

```sh
python3 tools/check_docs.py
python3 -m unittest discover -s tools -p 'test_check_docs.py' -v
```

Python 표준 라이브러리만 사용한다. 이 검사는 문서와 문서 검사기용이며 게임 gate·빌드·실제 플레이 검증과 구분한다.
