# 1.1 확장 콘텐츠 · 생성과 검증 인계

기준 `0565166`, 작업 트리 `packet-trail-expansion/feat/three-perspectives`. 설계 기준은 [재설계 브리프](campaign-redesign-brief.md), [실제 모형 계약](three-perspectives-contract.md), 활성 PRD/test spec 및 DESIGN이다. 방어/추적 각8사건은 확장 승인 아래 제작자가 제안한 이번 수량이며 사용자가 직접 숫자를 지정한 것으로 인용하지 않는다.

## 생성물

| 공개 팩 | 파일 | 사건 | ko/en 표시 키 | 대표 실행 경로 |
|---|---|---:|---:|---:|
| intruder | `godot/data/campaign/packs/intruder_v2.json` | 메인24+선택4 | 577 | 56 |
| defender | `godot/data/campaign/packs/defender_v1.json` | D01~D08 | 193 | 16 |
| tracker | `godot/data/campaign/packs/tracker_v1.json` | T01~T08 | 131 | 16 |

한영 원고는 `godot/data/campaign/locales/{intruder_v2,defender_v1,tracker_v1}.{ko,en}.json`의 키→문자열 사전이다. `IN2_`·`DF1_`·`TR1_`를 사용해 기존826키 및 다른 새 팩과 충돌하지 않는다. 나머지 네 언어와 PO 병합은 현지화 담당이 소유한다.

테스트 전용 [perspectives_solutions.json](../../godot/tests/fixtures/perspectives_solutions.json)은 `packs → pack_id → missions → mission_id → paths` 구조로 44사건의 A/B 88경로를 담는다. 완료 플래그를 주입하지 않고 공개 command/password/request/tool API를 재생한다. 각 경로는 완료·보존·자료·정책·서비스/세션 또는 새 모형의 업무/관측/VM 결과를 기대한다. 이 파일은 실행 패키지에서 제외해야 한다.

생성기는 [build_expansion_content.py](../../tools/build_expansion_content.py)다. 표준 라이브러리만 사용한다. 원래 저자의 서사 literal과 보존 정의를 읽지만 기존 생성기를 실행하지 않는다. 생성 전후 기존 campaign/legacy_v1·old ko/en·old 해법·old 생성기 6파일 SHA를 비교한다. `legacy_v1.json`의 `51699e38…` 고정 지문을 확인하며 이 파일을 다시 쓰지 않는다.

## 침투편의 실제 변경

- 기존66개 공통 exhibit의 필수 자료·fact 목표와 compare/trace challenge, 그 전용 원장 호스트를 새 팩에서 제거했다. 기존판에는 그대로 남아 이전 저장의 원래 의미를 보존한다.
- 전용 원장을 찾으러 다녀온 뒤 같은 대상에 다시 인증하는 no-op 경로를 새 fixture에서 제거했다. 실제 다른 trust/vantage가 필요할 때만 기존 gateway·현재 actor·직접 route를 사용한다.
- M04/05/09/11/14/16/18/21의 보관 대안은 고정 문장 trace 대신 현재 인증된 위임 객체 서비스의 실제 owner/scope 조회로 연결했다. 특정 공격 기술을 쓰지 않은 경로도 유효 목표 자료이면 인정한다.
- M17은 XOR 후보 판정을 제거했다. 승인 후보 규칙을 읽고 실제 제한 계정 인증→VFS 자료 접근을 하거나 좁은 감사 위임으로 같은 검증표를 읽는다. 실제 암호 해시 균열 알고리즘·성능을 제공했다고 표현하지 않는다.
- R01은 실제 `branch_vm`의 format→signature→release 호출 흐름이다. 정상 scope와 제외 scope를 실제 실행해 같은 release가 생기는 반례를 확인한다. 다른 경로는 형식/서명 입력쌍과 call trace로 빠진 검사를 찾는다. case 이름이나 XOR 단어가 판정이 아니다.
- M24는 `current_boundaries`가 qualified challenge/case 참조로 웹·route·service를 각각 검사한다. 외부/중계 vantage, owner/비담당 actor, 제한 서비스 자격이 실제 handler에서 다른 응답을 낸다. 목표 지시 사본은 원래 호스트 또는 승인된 gateway의 실제 파일 권한으로 회수한다. 과거 compare/trace 자료만 제출해서 끝내지 않는다.
- 새 상태 리소스·자료·policy·challenge·fact는 팩 이름공간을 갖는다. 짧은 M01/D01/T01 표시는 활성 팩 안에서 해석한다. 공개 도메인·계정 handle·VM 함수명·모형 내부 case/control ID는 각각 자신의 호스트/프로그램/모형에 qualified되며 공유 TranslationServer의 전역 키와 혼합하지 않는다.

기존 원고 중 실제 의미가 같은 부분은 새 키 아래 재사용한다. 새 힌트는 삭제한 원장/exhibit를 요구하지 않고 현재 actor·대상·경로와 허용 대안을 안내한다. KO 표시 원고는 현지화 담당의 기존 R3 문단 교정을 읽어 재사용하며 원본 KO source JSON은 수정하지 않는다. R01 의사코드의 사람용 주석도 KO로 표시하고 함수/변수는 유지한다.

## 방어편의 다른 대응

| 사건 | 직접 정밀 대응 | 다른 유효 대응 |
|---|---|---|
| D01 객체 열람 | 원래 서비스의 소유자 검사 | 노출 ingress를 닫고 현재 위임 scope가 있는 gateway로 업무 이관 |
| D02 인증 폭주 | 계정별 retry 제한과 실제 실패/정상 로그인 | 원래 인증 ingress 제한과 별도 승인 인증 경로; 같은 주소의 정상 시민·작업은 유지 |
| D03 끝난 세션 | 서버의 유효성 검사+표적 폐기 | 옛 세션을 발급하지 않은 승인 provider로 교체하고 원래 ingress 제한 |
| D04 사진 처리 | 실제 내용 검사·비실행 저장 | 원래 처리 입구 제한과 이미 검증된 안전 processor |
| D05 내부 요청 | 내부 객체의 현재 owner 검사 | 건강 확인만 위임한 proxy 경로, 시민 미리보기는 별도 유지 |
| D06 작업 권한 | 실제 notifier 그룹에 필요한 deploy 권한만 추가 | 별도 승인 경로의 VFS 파일로 동일 작업 이관 |
| D07 잘못된 긴급 규칙 | 검증된 인계의 availability 정책만 rollback | 알림을 standby 경로로 이관, 보안 그룹·폐기 키 유지 |
| D08 종합 교대 | 원래 업무 경로의 정밀 owner/session/target 제어 | 좁은 gateway/standby 조합으로 같은 업무·위협 행렬 충족 |

`response_lab`의 실제 응답은 요청자·대상·현재 정책/route/service/session에서 계산한다. class/expect는 판정용 기대값이지 서버가 숨은 공격자 flag를 읽는 입력이 아니다. 전부 끄면 threat가 사라져도 normal 업무가 실패한다. 별도 승인 경로도 위임 밖 객체·종료 세션·위장 파일·허용 밖 목적지를 별도로 검사한다.

D06은 가짜 policy flag로 파일 권한을 대신하지 않는다. 실제 VFS의 조상 디렉터리·현재 그룹·파일 mode를 사용한다. 쓰기는 선언된 작업 파일 두 경로에 제한하고 `expected.remote_files`로 실제 결과 본문을 확인한다. 보호 원문과 작업 결과 파일은 구별한다.

D07은 이미 잘못된 notify 정책으로 시작한다. `initial_checkpoints.baseline_availability`는 인계 당시의 availability control 값만 보존한다. 사용자가 일부러 좋은 정책을 망가뜨려야 진행하는 순서가 아니다. 두 경로 모두 노출된 세션을 폐기하고 서버가 폐기를 검사하도록 한다. rollback은 이 폐기와 보안 그룹·수집 이력을 복원하지 않는다.

## 추적편의 관측과 인계

T01은 같은 IP와 세션/사람 동일성을 분리하고, T02는 실제 시각 구간 보정, T03은 출처와 원문 진실성, T04는 다음 관찰 위치, T05는 계정과 사용자, T06은 암호화 가시성, T07은 새 반증, T08은 최소 연결망과 한계 인계로 이어진다. 민서는 T01에서 자기 역할을 소개하며 타편의 인물 비밀을 요구하지 않는다.

- A는 현장 관측과 명시 가설 평가, B는 독립 출처의 관측과 직접 handoff claims를 사용한다. 같은 요청을 GUI/CLI에서 보낸 것을 다른 경로로 세지 않는다.
- 관측 사본 ID는 sensor/window/event에 결합되고 SHA·provenance·보정 시간 구간을 보존한다. 빈 citation을 자동으로 전체 근거로 채우지 않는다.
- T04/T07의 `advance_watch`는 유한한 새 관측 구간을 열며 실시간 기다리기가 아니다. 이미 가진 같은 행을 다시 읽어 새 근거를 만들지 않는다.
- T07의 이전 추측은 작성자가 제공한 `initial_claims.prior`다. 사용자가 이를 개인의 오답으로 먼저 제출해야 하는 것은 아니다. A는 불충분 가설→새 반증→정정 이력을, B는 강한 독립 관측→올바른 연결 직접 인계를 지원한다.
- T06 metadata에는 본문/authorized excerpt가 없다. 승인된 endpoint 관측에만 제한된 excerpt가 있다. 각각 public 사전을 별도로 복사해 같은 Python 객체 공유로 payload가 새지 않도록 했다.
- status는 수집한 공개 관측만으로 지원/반박/미확정을 계산한다. 범인 실명·hidden actor·근거 없는 정답률은 포함하지 않는다. “모름”만 제출해서는 요구 연결과 다음 관찰 조건이 충족되지 않는다.

## 독립 시작과 정보·저장 경계

Catalog는 intruder `midnight/version2`, defender `midnight_defender/version1`, tracker `midnight_tracker/version1`을 별도 슬롯으로 연결한다. 기존 `midnight/version1`은 legacy continuation으로 남긴다. 콘텐츠가 사용자 경로를 지정하거나 기존 세이브를 다시 쓰지 않는다.

contacts metadata는 팩 안의 소개/공개 조건만 쓴다. D01의 도윤, T01의 민서는 즉시 자기 역할로 소개되고 타편 M02/M16 등의 완료를 참조하지 않는다. C01은 각 편의 등장 조건과 explicit privacy 선택을 유지한다. 기존 portrait asset ID를 공유하는 것은 팩 진도를 공유한다는 뜻이 아니다.

## 현재 검증 범위와 남은 통합

생성 assert는44개 정의·팩별 두 경로·전역 표시 키 충돌 없음·현재 host/account/route/endpoint 참조·미션 home 디렉터리·공통 exhibit 목표0·metadata payload 경계를 확인한다. 6개 보존 입력의 전후 SHA는 같다.

아키텍처 담당의 첫 대표 실행에서 T 경로들과 D 상태를 대조했고, D03의 취약 서비스가 폐기를 실제 검사하도록 guard 조치를 추가했다. M24의 복사된 home/public 참조와 T06 공유 객체 문제도 데이터에서 수정했다. 이는 전체88경로·저장·부정·native 검증을 대신하는 결과가 아니다.

Root가 큰 묶음의 legacy 회귀·새88경로·partial rollback/과잉차단·반증/정보공정성·분기/현재3경계·팩별 저장과 원본 보호·6locale·native·PCK/3OS를 통합 검사한다. fixture/작성 도구/locale 원고는 실행 PCK에서 제외한다.

## 독립 검토 I3 · 복구5사건의 실질 대안 수리

기존 새 침투 M06·M07·M08·M12·M23의 A/B가 같은 bool과 입력 순서를 도구/HTTP 표면에서만 바꾸던 문제를 채택해 실제 데이터·목표·해법을 고쳤다. 이제 이5사건의 목표는 **현재 response_matrix + 유효한 대응 인계 사본 + 원본 보존**이다. A 전용 solved fact나 단일 bool=true를 필수 목표로 보지 않는다.

| 사건 | A의 실제 상태 | B의 실제 다른 상태 | 독립 반례 |
|---|---|---|---|
| M06 | 원래 인증 서비스의 retry 제한으로 반복 실패429, 정상 인증200 | 원래 입구503, 별도 제한을 가진 승인 인증 경로로 정상200·반복 실패429; 원래 retry 제어는false | A의 retry 제한을 끄면 반복 실패가401에 머묾. B에서 원래 입구를 다시 열면 제한 없는 경로가 돌아옴 |
| M07 | 원래 서버가 폐기를 검사하고 노출 키를 실제 폐기; 새 정상 세션200 | 원래 입구를 닫고 옛 키를 발급하지 않은 provider로 이관; 옛 키403/새 키200, 원래 guard는false | A의 guard를 끄면 폐기 검사 없는 서비스에서 옛 키가 통과. B에서 원래 입구를 열면 옛 issuer가 다시 허용 |
| M08 | 원래 폼의 계정별 nonce 검사로 정상 저장200/유도 변경403 | 원래 변경 입구503, 독립 nonce·Origin·자기 설정 scope의 gateway로 같은 정상 저장200/위조403; 원래 nonce 제어false | A의 nonce 검사를 끄거나 B의 취약 원래 입구를 열면 실제 원치 않은 설정 변경이 수락됨 |
| M12 | 원래 내용 검사·비실행 저장, 정상 JPEG201/위장415 | 원래 입구503, 승인된 안전 processor에서 정상201/위장415; 원래 validation=false. 이전 store의 위험물은 B도 비실행으로 억제 | A의 validation을 끄거나 B의 원래 입구를 열면 위장 새 파일이201로 생성됨 |
| M23 | 원래 auth/session/upload/notify 제어와 폐기를 정밀 복원 | 원래 취약 입구를 닫고 안전 gateway/standby에서 같은 업무를 처리; 원래 retry/session/validation 제어false, 공유 노출 키는 실제 폐기 | A의 파일 검증을 끄거나 B의 원래 입구를 열면 위장 파일 경로가 다시 수락됨. 정상 업무는 별도로 유지 |

고정 gateway 보호 속성은 선언된 서비스의 특성이며 호출자 JSON이 expected/class를 덮어 응답을 만드는 방식이 아니다. M08의 닫힌 `csrf_change` 연산 하나만 추가하고, 나머지는 기존 실제 auth/session/upload/notify handler와 route/service를 재사용했다. 정상·위협 기대값은 결과와 비교할 뿐 서버 응답으로 복사하지 않는다.

새 fixture의 각 `alternative_witness`는 A 전용 policy ID, B의 그 값=false, 실제 두 provider, normal/threat 요청, A/B를 각각 깨는 control과 실제 bad-status 요청을 명시한다. QA는 이름·JSON 순서·kind 개수 대신 해당 상태와 요청 결과를 독립 검사했다.

**실제 독립 표적 결과:** `recovery-alternatives-integration.log`, 14,004검사·88경로·0실패, 42.094초. A/B의 실제 provider·A-only=false B완주·각 고유 실패 control·현재 목표 실패·정상 업무 유지·저장 재개를 확인했으며 실행 중 core/pack/fixture/test SHA는 동일했다. 이는 새44사건의 총수와88개 실행 witness의 기능 근거이며, 사람의 재미·8~12시간 또는 모든 가능한 대응을 증명하지 않는다.

최종 제품 문구만 추가 교정했다. 기본 KO의 bool/case/route·설계 비평 표현을 설정·정상 요청·승인 경로·업무 권한으로 바꾸고, 대응 인계 기본 표시에는 현지화된 문단을 사용한다. 교정 전후 **3팩 JSON과 해법 fixture bytes는 동일**해 위 기능 결과의 입력·판정은 변하지 않았다. 최종 IN2 원고는577키(기존508대비71신규/50변경/2삭제)이며 DF193/TR131의 source SHA와 기존판 입력6개 SHA는 유지했다. locale 병합 후 Root의 전체 gate→native44→PCK/3OS 검증이 최종 통합 증거다.

침투 8~12시간은 실측 전 설계 목표다. 이번 변경은330개 반복 행동을 제거하는 방향이며 그 빈 시간을 필독 설명·재인증·강제 대기로 채우지 않는다. 88개의 유효 실행 fixture는88개의 독립 재미·학습 효과 또는 사람 플레이 시간을 증명하지 않는다.
