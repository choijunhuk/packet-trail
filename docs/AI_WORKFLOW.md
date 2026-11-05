# 모델·추론 수준·협업 계획과 실제 기록

기준: 2026-11-04, 최신 재검토 기록: 2026-11-05. Codex 6.1 기준 배정과 모델·추론 수준 기록을 유지한다. Claude 협업은 과제별 사용자 지시를 따른다. 세션별 실제 수행 내용은 §4 표에 시점과 함께 남긴다.

## 1. 실제 실행과 권장 계획을 구분하는 규칙

아래의 권장 배정표는 실행 이력이 아니다. 실제 호출은 별도 표에 모델 ID, 추론 수준, 업무, 확인 근거, 결과를 남긴다. 요청한 모델과 역할 설정의 모델이 다르면 덮어쓴 사실까지 기록한다.

별칭이나 전역 기본 설정만 보고 실제 모델이라고 쓰지 않는다. Codex는 해당 세션의 `turn_context.model`과 `effort`, Claude는 향후 호출 결과의 모델 사용 정보를 확인한다. 인증정보·세션 원문·개인 경로를 저장소에 커밋하지 않는다.

## 2. 앞으로의 Codex 작업 배정 제안

| 작업 | 모델 | 추론 수준 | 이유·완료 조건 |
|---|---|---|---|
| 기획 통합·핵심 설계 | gpt-6.1-sol | xhigh | 요구 충돌·콘텐츠·기술 경계를 함께 판단. 결정 이유와 대안을 문서화 |
| 공식 자료 조사 | gpt-6.1-sol | high | 원저자·버전·추론을 구분하고 필요한 출처가 모이면 종료 |
| 좁은 파일·심볼 조회 | gpt-6.1-sol | medium | 관련 위치와 현재 동작만 확인. 결과가 불명확하면 high |
| 일반 기능 구현 | gpt-6.1-sol | high | 작은 기능을 호출부·테스트까지 연결 |
| 명령 파서·권한·목표 판정 | gpt-6.1-sol | xhigh | 다중 해법·경계값·순서 의존성 검증 |
| 저장·마이그레이션·진행 복구 | gpt-6.1-sol | xhigh | 손실·부분 실패·버전 불일치 처리 검증 |
| 창 UI·가상 브라우저·도구 화면 | gpt-6.1-sol | high | 포커스·키보드·한글·창 전환까지 실제 조작 |
| 미션·대사 초안 | gpt-6.1-sol | high | 학습목표·증거·판정·힌트 일관성 확인 |
| 독립 설계·코드 검토 | gpt-6.1-sol | xhigh | 작성자와 별도 맥락에서 실패 사례 검토 |
| 문서 정리·정해진 형식 변환 | gpt-6.1-sol | medium | 사실을 추가하지 않고 구조·링크 확인 |

모든 일을 xhigh로 처리하는 것이 목표는 아니다. 조사·구현·검토를 분리하고, 실패 비용이 큰 결정에 깊은 추론을 배정한다. 반복 파일 조회나 형식 변환은 도구로 먼저 처리한다. 추론 수준을 낮추려고 검증·테스트·범위를 생략하지 않는다.

### 상승 조건

- 한 번의 targeted test로 원인이 드러나지 않는 반복 실패: high → xhigh.
- 저장 손실·판정 우회·호스트 경계·권한 변경이 걸린 작업: 처음부터 xhigh.
- 문서 작성이 엔진 선택이나 학습 정책 결정으로 번진 경우: medium → high 또는 리더.
- 같은 원인을 두 에이전트가 동시에 추적 중이면 추가 인원을 늘리지 않고 소유를 정리한다.

### 병렬화의 단위

의존성이 없는 조사와 문서 검토는 병렬로 진행할 수 있다. 구현은 예를 들어 `simulation/`과 `ui/`의 데이터 계약이 먼저 고정된 뒤 나눈다. 같은 파일을 두 명이 수정하지 않는다. 통합·검증은 리더가 맡는다.

기능 하나가 작으면 리더가 직접 끝낸다. 모델 호출 개수나 생성 코드량은 진척 지표가 아니다. 실제 미션 완주·재시작·저장 복구와 사용자 피드백을 기준으로 삼는다.

## 3. Claude 협업의 범위

초기 기획 중에는 사용자 지시로 새 Claude 호출을 중단했고, 사용자가 전달한 응답만 참고했다. 이후 사용 가능 여부 질문에서 최소 응답 호출에 성공했고, 사용자는 별도 Claude 피드백 파일을 제공했다. 1차 피드백 개정(A08~A12)에서는 그 파일만 검토했다. 2차 평가와 그 개정은 사용자 요청으로 Claude Code 세션이 직접 수행했다(C06~C08). 과거 중단 지시를 프로젝트의 영구 사용 금지로 적지 않는다. 향후 자문은 허용된 과제·입력·출력 범위를 정하고 실제 모델을 기록한다. 게임 런타임은 고정 콘텐츠를 사용한다.

| 시점 | 지정할 모델 | 추론 수준 | 맡길 일 | 넘길 자료 |
|---|---|---|---|---|
| 상세 설계가 안정된 뒤 | claude-opus-5-5 | high | 학습·스토리·시스템의 모순과 누락 반론 | 계획서·미션 카드·수용 기준 |
| 첫 수직 시제품 뒤 | claude-opus-5-5 | high | 플레이 흐름·힌트의 과도한 정답 유도 검토 | 화면 기록·실제 오류·익명 테스트 요약 |
| 저장·판정 구조 변경 전 | claude-opus-5-5 | xhigh 후보 | 실패 시나리오와 변경 영향 검토 | 작은 diff·계약·테스트 결과 |
| 캠페인 집필 | claude-opus-5-5 | high | 인물 목소리·대사 반복·단서 모순 검토 | 확정 세계관·미션 의도·금지 설정 |

Claude CLI 도움말은 `low/medium/high/xhigh/max` 입력을 제공한다. 특정 모델의 적용 의미·사용 가능 여부는 실제 사용 직전에 확인한다. Codex의 xhigh와 Claude의 xhigh를 동일한 계산량·품질로 환산하지 않는다. 미지원 수준은 조용히 다른 값으로 바꾸지 않고 기록한다.

Opus 5.5의 공식 모델 ID는 `claude-opus-5-5`다. 모델 ID와 계정 사용 가능 여부는 구분한다. 현재 환경의 최소 응답 성공은 아래 C04에 기록했다. [공식 모델 문서](https://platform.claude.com/docs/en/models/opus-5-5/overview)

향후 요청할 때의 형태는 다음과 같다. **지금 실행하라는 명령이 아니다.**

```sh
claude --print --model claude-opus-5-5 --effort high --tools "" \
  --no-session-persistence --output-format json < review-prompt.txt
```

검토자는 코드·파일을 변경하지 않고 문제와 근거를 보고한다. 리더가 타당성을 검토하고 필요한 수정만 반영한다. 모델의 동의 자체를 승인·테스트 통과로 취급하지 않는다. 사용량·속도는 구독·계정·컨텍스트 크기에 따라 달라지므로 고정 비용·성능 향상 수치는 제시하지 않는다.

## 4. 초기 기획의 실제 실행 기록

| ID | 실제/요청 모델 | 추론 수준 | 업무 | 확인 근거·결과 |
|---|---|---|---|---|
| A01 | gpt-6.1-sol | xhigh | 리더 기획·통합·로컬 문서 작성 | 현재 세션 `turn_context`에서 실제 모델·effort 확인 |
| A02 | gpt-6-sol | low | 최초 공식 자료 조사 | 설치된 researcher 역할 기본값과 자식 세션에서 확인. 사용자가 6.1 기준을 요청하기 전 실행. 후속 호출에 재사용하지 않음 |
| A03 | gpt-6.1-sol | high | 효율적인 제작 방식 조사 | model-flexible native default에 명시 지정, 자식 세션 실제 값 확인 |
| A04 | gpt-6.1-sol | high | Hacknet 제작 방식·설치형 게임 구조 조사 | A03과 같은 자식 세션에 최신 요구를 전달 |
| A05 | gpt-6.1-sol | high | 24미션·학습·대안 풀이 문서 | model-flexible native default 명시 지정, 자식 turn_context에서 실제 모델·effort 확인 |
| A06 | gpt-6.1-sol | xhigh | 가상 OS·서비스·명령·저장 기술 설계 | model-flexible native default 명시 지정, 자식 turn_context에서 실제 모델·effort 확인 |
| A07 | gpt-6.1-sol | xhigh | 작성자와 별도 맥락의 독립 기획 검토 | 실제 turn_context 확인. 4개 계약 보완 후 재검토 READY(기획 기준) |
| C01 | Claude 모델 미실행 | 기본 요청 | 최초 자문 시도 | 인증 실패로 `Not logged in`, 유효한 검토 결과 없음 |
| C02 | opus 별칭 요청, 실제 모델 미확인 | high 요청 | 로그인 후 자문 재시도 | 동일 인증 실패. Opus 5.5 검토로 계산하지 않음 |
| C03 | claude-opus-5-5 | high 요청 | 사용자가 터미널에서 완료해 전달한 초기 기획 자문 | 응답 modelUsage와 is_error=false 확인. 최신 요구에 맞는 부분만 채택, 추가 호출 없음 |

초기 중단·실패·사용자 전달 응답은 각각의 시점 기록이다. 이후 인증 확인과 파일 기반 검토가 그 이력을 성공한 자문으로 바꾸지는 않는다. [Claude 참고 기록](reviews/CLAUDE_REVIEW.md)을 함께 읽는다.

### 2026-11-04 피드백 개정과 추가 확인

| ID | 실제 모델 | 추론 수준 | 업무·근거 |
|---|---|---|---|
| C04 | claude-opus-5-5 | low 요청 | 사용 가능 여부 질문에 따른 최소 CLI 호출. 응답 OK·is_error=false·modelUsage 확인. 게임 기획/코드 생성은 안 함 |
| C05 | claude-opus-5-5라고 원문에 기재 | 원문 미기재 | 사용자가 제공한 CLAUDE_FEEDBACK_20261104.md. 이번에는 실행 로그가 아니라 전달 문서로 취급 |
| A08 | gpt-6.1-sol | max | 이번 리더의 현재 turn_context 확인. 피드백 수용 판단·제품/화면/스토리·통합·검증 |
| A09 | gpt-6.1-sol | high | 미션 담당 세션: M01·후속 연결·학습 선택성 개정 |
| A10 | gpt-6.1-sol | xhigh | 기술 담당 세션: P1 최소 계약·로드맵·단계 도입 구분 |
| A11 | gpt-6.1-sol | xhigh | 독립 검토 세션: 피드백 비판 검토와 개정 정합성 검토 |
| A12 | gpt-6.1-sol | high | 캐릭터 외형·아트 바이블·영문 생성/표정 프롬프트 문서. 실제 이미지/음악 생성 호출 없음 |
| C06 | claude-opus-5-5 (Claude Code 세션 정보) | 세션 설정, 수준 미기록 | 2차 평가. 사용자가 대화에 붙여 넣은 Hacknet 정적 분석 보고서를 참고. 결과는 `reviews/CLAUDE_FEEDBACK_20261104_R2.md`. 원작 설치본 열람·실행 없음 |
| C07 | claude-opus-5-5 (같은 세션) | 세션 설정, 수준 미기록 | 사용자 지시 "시작은 하지말고 수정만"에 따라 2차 피드백을 문서에 반영. 게임 코드·gate 파일 없음. 문서 검사기를 `tools/check_docs.py`로 추적 |
| C08 | Claude Code 서브에이전트 sonnet (요청 모델) | 기본 | C07과 분리된 맥락의 읽기 전용 검토. READY, 🟡4·🟢1 반영 |

현재 리더 max는 실행 기록이며 모든 작업의 기본 권고로 격상하지 않는다. 위 high/xhigh 배정은 해당 자식 세션에서 확인한다. Claude 전역 규칙 파일에는 gpt-5.6-sol이라는 별도 기본값이 있으나 이 프로젝트의 Codex 실제 6.1 기록에 덮어쓰거나 전역 파일을 수정하지 않았다.

### 2026-11-05 Codex의 R2 재검토

| ID | 실제 모델 | 추론 수준 | 업무·근거 |
|---|---|---|---|
| A13 | gpt-6.1-sol | max | 현재 리더 turn_context 확인. 이미 작성된 Claude R2 반영 초안 보존·독립 대조·계약 보완·검사기 회귀 테스트/수정·통합 |
| A14 | gpt-6.1-sol | xhigh | 독립 검토 세션. 완료 효과1회·회수 기록 무결성·지속 snapshot 비교 경계를 검토 |
| A15 | gpt-6.1-sol | high | 공식 Godot JSON·Dictionary·저장 문서 확인. 원작 파일 추가 열람·코드 수정 없음 |

C06~C08은 기존 Claude 세션이 남긴 이력이다. 이번 Codex 재검토에서는 새 Claude 호출·게임 구현·원작 추가 분석을 하지 않았다. R2 평가와 기존 반영 초안을 구분해 검사하며 사용자 `.serena/`는 보존한다.

### 2026-11-05 첫 플레이 구현 묶음

| ID | 실제/요청 모델 | 수준 | 역할·증거 |
|---|---|---|---|
| A16 | gpt-6.1-sol | max | 리더 코어·데이터·통합·실행/렌더/검증, 현재 세션 메타데이터 확인 |
| A17 | gpt-6.1-sol | xhigh | 별도 저장기/실제 I/O 회귀 작성 |
| A18 | gpt-6.1-sol | high | headless runner·콘텐츠/gate/경계 검사 작성 |
| A19 | gpt-6.1-sol | xhigh | 독립 코어·저장·게이트 읽기 검토. 3개 높은효과 보완 반영 |
| A20 | gpt-6.1-sol | high | 후속3캠페인 문서·native export/3OS CI 준비 |
| C09 | claude-opus-5-5 | high 요청 | UI/scenes 소유2파일 실제작성, response modelUsage/is_error=false 확인 |
| C10 | claude-opus-5-5 | xhigh 요청 | 별도 fresh context의 코어/통합 읽기 검토, 4개 UI 발견 |
| C11 | claude-opus-5-5 | high 요청 | 4개 수정/회귀 정적 재검토 READY. 모델 응답 확인, 직접실행이아닌코드검토로구분 |
| C12 | claude-opus-5-5 | high 요청 | 최종 키보드/CI 변경분 정적 검토 REVISE: 마우스 버튼 후 입력 포커스 복귀 누락. 공통 처리와 실제 이벤트 회귀로 보완, modelUsage/is_error=false 확인 |

사용자가 Claude 실제 활용과 양쪽 결과 검증을 요청해 기존 중단 범위를 변경했다. 새 구현은 서로 다른 파일 소유로 진행하고 완성된 묶음에서 검증했다. 실제 UI·헤드리스 실행은 리더가 확인했으며 Claude의 동의를 실행 증거로 대체하지 않았다. raw prompt/response는 로컬 `.omx/artifacts/claude-first-playable-*.md`로 보관한다.

## 5. 구현 때 남길 작업 기록 형식

```text
작업 ID / 날짜:
목표·완료 조건:
선택 모델 / 요청 추론 수준:
실제 모델 / 실제 수준 / 확인 경로:
소유 파일 / 선행 작업:
변경 내용 / 선택 이유:
테스트 명령 / 결과 / 검증하지 못한 것:
검토자 / 반영·보류 사유:
다음 작업 / 중단 조건:
```

요청값만 알면 ‘요청’, 런타임에서 확인하면 ‘실제’, 앞으로의 계획이면 ‘권장’이라고 쓴다. 전역 Codex·Claude 설정은 이 저장소를 위해 변경하지 않았다.

### 2026-11-05 전체 게임 제작 재개

사용자가 첫 실행판에서 끊지 말고 끝까지 완성하고, 피드백은 나중에 주겠다고 명시했다. 범위는 P0/P1에서 전체 침투자편으로 확장됐다. 작업은 `feat/full-campaign`의 별도 작업트리에서 진행하고, 구버전 M01과 사용자 저장을 보존한다.

| ID | 모델 | 추론 수준 | 실제 작업·확인 범위 |
|---|---|---|---|
| A21 | gpt-6.1-sol | max | 부모의 전체 통합·파서/경계/gate·native 실행·배포. 기존 세션 모델 이력 유지 |
| A22 | gpt-6.1-sol | xhigh | Campaign façade/runtime/loader/tool models·savev2·복수터미널·실제 회귀 수정 |
| A23 | gpt-6.1-sol | high | 24메인+4선택·113host·89자료 목표·56해법·서사/KOEN 원고. 부모의 반복 템플릿 비판을 받고 다중 근거 체인으로 재집필 |
| A24 | gpt-6.1-sol | high | 3D 작업실·메뉴/설정·세 OS 프리셋/CI·검증된 ZIP 패키저 |
| A25 | gpt-6.1-sol | xhigh | 전체 QA 계약·해법/부정/저장 검증·독립 코어 리뷰 5건. 추가 테스트 turn의 서비스 분류 오류 후 부모가 남은 테스트 보완을 수행 |
| A26 | gpt-6.1-sol | high | 오리지널 OST7큐·효과음·AudioDirector·실제 입력/렌더 검사. 독립 audio39, native 회귀 증거는 전체 구현 기록에서 확인 |
| A27 | gpt-6.1-sol | high | 6PO 1,443키/언어·KR/JP/SC/Mono·공식 출처/OFL·문자열/토큰/폰트 검사 |
| A28 | gpt-6.1-sol | xhigh | fresh UI 통합 독립 읽기 검토. Important3·Critical0, 수정은 부모가 담당 |
| C13 | claude-opus-5-5 | high 요청 | 전체 UI 첫 호출. Read/Write 절대 경로 rule 오류를 발견해 중단했으며 성공 기여로 계산하지 않음 |
| C14 | claude-opus-5-5 | high 요청 | 올바른 Read(//절대경로)/Edit(//소유파일)로 재실행. UI/scene/KOEN UI475키 작성. `is_error=false`, 실제 modelUsage, 권한 거절0 확인 |
| IG01 | 내장 image_gen | 모델/수준 미노출 | 성인 허구 캐릭터 중립4·정본 참조 표정 편집12. 선택한16PNG를 프로젝트에 저장·SHA/alpha 검사 |

Claude는 CLI의 safe-mode/restricted에서 Read/Glob/Grep/Write/Edit만 주고, 소유한 UI 네 파일 외에는 수정 권한을 주지 않았다. 내장 Write 도구 허용은 `Edit(//absolute/file)` 규칙이 담당한다는 공식 권한 문서를 확인해 교정했다. 전역 Claude/Codex 설정·인증은 변경하지 않았다. [공식 경로 규칙](https://code.claude.com/docs/en/permissions#how-path-patterns-match), [Write 규칙 설명](https://code.claude.com/docs/en/permissions#writepath-notebookeditpath-and-globpath-rules-never-match).

C14는 직접 Godot를 실행하지 않았다. 부모의 전체 headless/import·runtime·실제 renderer 검증이 별도 실행 증거이며, 모델의 READY/완료 응답을 통과로 대신하지 않는다. 모델이 본 소스와 후속 수정 범위의 SHA·재현 로그를 구분한다. 숨은 모델 thinking/signature는 사용자용 보고서에 옮기지 않는다.

완료한 검토·배포 검증만 아래 실제 이력으로 남긴다. 요청 모델과 서비스가 보고한 실제 사용 모델을 구분한다.


### 전체판 최종 독립 검토 실제 이력

- C15: Opus5.5/xhigh 다중파일 읽기 검토는 서비스 세션 한도 메시지로 끝나 성공 판단으로 쓰지 않았다.
- C16: 한도 초기화 뒤 같은 모델/수준으로 재시도했으나 88회 읽기 도중 API ENOTFOUND로 종료했다. 모델을 낮추거나 검토 성공으로 표시하지 않았다.
- C17: 읽기 스냅샷을 한 API 입력으로 묶어 Opus5.5/xhigh에 제공했다. is_error=false와 READY·확인된 Important/Critical0를 확인했다. 요청은5.5/xhigh였지만 실제modelUsage에는 claude-opus-5-5와 claude-opus-4-8 두모델이 함께 기록됐다. 최종화자별 귀속은 응답에 노출되지 않아 단독5.5검토라고 표시하지 않는다. 추가4.8을 호출자가 선택한 것은 아니며, 서비스가 보고한 실제 사용 이력을 그대로 기록한다. 파일 접근/실행 없는 정적 판단이다. 소스 SHA별 범위와 원문 결과를 로컬 `.omx/artifacts/claude-full-release-review-20261105.md`에 남겼다.
- A29: fresh gpt-6.1-sol/xhigh 독립 release_verification은 소스 등38개 해시 전후 동일을 확인하고 READY·신규 Important/Critical0를 기록했다. 최신 synthetic pointer stream의 별도 실행 한계는 소스 판정과 분리했다.

부모는 서비스 검토 대기 중에도 native 패키지의 실제 마우스 확인창·암호 가림/취소·M01→M02·3D 복귀·앱 재시작 복원을 CUA로 검증했다. 원본 가상 자료나 모델의 긍정 응답을 실제 사람 플레이타임/원어민 품질/실제 Windows GUI 증거로 바꾸지 않는다.

A26은 마지막 실제 재실행에서 일반 입력 대기와 캡처 draw를 분리했다. static/occluded 창에서 `frame_post_draw`를 무조건 기다리던 검증기 가정을 제거했으며, 실제 포인터를 옮기거나 버튼 신호를 직접 호출하지 않았다. 결과는 M3 full 3,761/0·28사건498행동, smoke451/0이며 root가 로그와 소스 `32f31bc` 일치를 확인했다. A24의 CI 부분 프로필은 실제 Linux450/0·M01 1/28로 통과했고 세OS 전체 headless 범위는 유지했다.

부모는 같은 소스의 세OS export와 PCK47×3·ZIP검증·Mac strict/deep ad-hoc 서명을 확인하고, 최종 ZIP에서 꺼낸 앱의 실제 OS 마우스 A+/A−·입력 포커스·수동저장·저장복원·작업실 왕복·새게임 확인창을 CUA로 검증했다. 배포와 최종 문서의 검증 근거는 [전체판 기록](implementation/2026-11-05-full-production.md)에 있다.

### 2026-11-05 사용자 피드백 뒤 읽기 전용 전체 재검사

사용자는 OST가 너무 잔잔하다고 평가하고 Claude의 전체 검사와 코드 수정 금지를 요청했다. [최신 결과](reviews/CLAUDE_FULL_AUDIT_20261105.md)의 기준은 a70e3bc다. 실행 소스/설정55개와 실제 캠페인·fixture·KOEN원고·관련 도구/계약을 세 입력으로 나눴다. 모든 원본260파일의 전후 SHA가 같음을 확인한 뒤 부모가 보고 문서만 작성했다.

| ID | 요청 모델·수준 | 실제 사용 이력과 작업 |
|---|---|---|
| C18 | claude-opus-5-5 / xhigh | modelUsage5.5, 코어/저장/모델/목표,950.289초, exit0/is_error=false, Important2 원문 |
| C19 | claude-opus-5-5 / xhigh | **modelUsage5.5+4.8**, 화면/입력/3D/현지화/오디오,907.064초, exit0/is_error=false. 최종 화자 귀속 미노출, 단독5.5로 표시하지 않음 |
| C20 | claude-opus-5-5 / xhigh | modelUsage5.5, 제작/콘텐츠/검사/패키징/CI,565.846초, exit0/is_error=false, Important4 원문 |
| A30 | gpt-6.1-sol / xhigh | Claude의6개 중요 주장에 대한 독립 읽기 전용 source triage. Important3·Medium3으로 재판정, 변경 제안 미실행 |
| A31 | gpt-6.1-sol / high | 원본을 보존한 검토용 OST7곡+엔딩 edit·음량 일치 A/B·decode/hash/loop/clipping 검증. 게임 적용0·실청미실시 |

세 Claude 호출은 로컬 CLI2.1.311의 safe-mode/restricted, tools빈목록·empty strict MCP·dontAsk/permission-promptsnone·no-session-persistence로 수행했다. Write/Edit/Bash/Read를 포함한 파일/실행 도구를 주지 않고 동결 본문만 전달했으며 permission_denials는 모두빈배열이다. 전역 Claude 설정·인증은 바꾸지 않았다. 실제 사용 모델과 요청 수준을 별도로 기록했으며 숨은 thinking 원문은 보고서에 옮기지 않았다.

부모는 새 임시 진단 파일과 고유 테스트 슬롯으로 최종경로 초과 저장 거절, 완료 여부에 따른 reset복구 차이,128항목 보관 제한, M06/M23 HTTP보상 비대칭, 역방향 창 순환, UI등록 배열 누적을 재현했다. 기본 저장/설정 SHA는 같았다. 기존 전체 gate도 다시 PASS였지만 새 결함을 덮는 근거로 사용하지 않았다. 사람 청취·재미·원어민·실제8~12시간과 독립 퍼즐 다양성은 자동 검사와 구분했다. 게임/테스트/제작 도구 원본은 수정하지 않았다.
