# 강화 캠페인 코어 독립 검토 — 2026-11-05

범위: `campaign_game.gd`, `campaign_runtime.gd`, `campaign_loader.gd`, `tool_runtime.gd`와 강화된 28사건/56해법 데이터의 정적 대조. 검토자는 캠페인 테스트 작성자이며 해당 코어의 구현자와 분리돼 있다. 아래는 **정적 검토 발견과 재현 회귀 준비**이며 실행으로 재현한 결과가 아니다.

현재 판정: **REVISE — root의 첫 backend 전체 묶음에서 RED 확인 대기**. 소스·콘텐츠는 수정하지 않았고, root가 허용한 소유 `test_campaign.gd`의 재현과 기대값만 보완했다. 기존 모든 해법·부정 검사를 유지한 채 새 사례를 같은 `campaign` suite에 연결했다.

## 검토한 소스 식별

작업 브랜치는 `feat/full-campaign`이고 다음은 수정 전 검토 대상의 SHA256이다. 코드가 바뀐 뒤 이 정적 판정을 그대로 최신 통과 결과로 재사용하지 않는다.

| 파일 | SHA256 |
|---|---|
| `campaign_game.gd` | `1b9a714a4ecc7c68dc6531d5ac513776972410477f351257a8e0b0d4260cad75` |
| `campaign_runtime.gd` | `88639d1b208c8491162b52e082173506910c2602e12dd68d9f66ac64c2aa29c9` |
| `campaign_loader.gd` | `d1a205e77b41ac18362a9bb77fe028d8030d8a86f78d69eb9c4987cff62f94e8` |
| `tool_runtime.gd` | `21b847d5e426ef5bd59a3d2f67f05801bebcc297c54a45d34be6553d281f5241` |
| `campaign.json` | `54bdf942a9376941355a0e6968e1600007fdd94387dbb5dd2205d1f432cf55a6` |

## 1. P1 — 직접 HTTP 로그인이 같은 계정의 인증 제한을 우회

- 위치: [campaign_runtime.gd](../../godot/scripts/core/campaign_runtime.gd) `request_page` 418~435줄, `_auth_model` 342줄 이후.
- 재현: M06의 실제 선수/선행 근거를 확보하고 `rate_limit=true`로 둔다. auth 모델에서 동일한 실제 계정의 잘못된 암호를 반복해 429/blocked를 만든다. 그 상태에서 같은 host의 `POST /login`을 잘못된 암호와 올바른 암호로 각각 요청한다.
- 정적 근거: `/login` 분기는 account/password만 직접 검사하고 `users/remaining`을 읽지 않는다. 잘못된 암호는 401로 반환하고 올바른 암호는 별도 웹 세션을 만든다. 모델의 429 제한은 이 경로에 적용되지 않는다.
- 영향: 제한을 고쳤다는 미션 상태와 실제 가상 로그인 서비스의 동작이 다르며, 같은 인증 영역의 다른 진입점으로 차단을 우회할 수 있다.
- 최소 수정: 직접 로그인과 workbench/tool 관찰이 같은 계정별 제한·회복 처리를 사용하게 한다. 차단 중에는 올바른 암호도 새 웹 세션을 만들지 않고, 회복 뒤 정상 로그인은 유지한다.
- 준비한 회귀: `_test_auth_endpoint_parity` — 모델 차단을 먼저 확인하고 두 직접 요청의 429·세션 부재, 회복 뒤 200·정확한 계정을 독립적으로 검사한다.

## 2. P1 — 만료된 모델 토큰이 실제 웹 인증 주체로 남음

- 위치: [tool_runtime.gd](../../godot/scripts/core/tool_runtime.gd) session 123~150줄; [campaign_runtime.gd](../../godot/scripts/core/campaign_runtime.gd) `_has_session` 244~249줄, `use_challenge`의 웹 세션 반영, `request_page` 462줄의 actor 선택.
- 재현: M07의 필요한 근거와 유효 역할로 모델 토큰을 발급해 실제 `web_sessions` 자격으로 사용한다. 모든 SSH 연결을 종료하고, strict 상태에서 `wait ticks=32`로 그 토큰의 TTL을 넘긴다. 보호 workbench를 Browser로 연 뒤 암호 없이 `issue`로 새 토큰을 요청한다.
- 정적 근거: 모델은 `expires_at/tick`으로 reuse를 거절하지만 웹 권한 소비자는 캐시의 account만 신뢰한다. wait는 캐시를 무효화하지 않으며, 만료된 캐시 주체로 다시 issue할 수 있다.
- 영향: 모델에서 배운 폐기/만료 규칙과 실제 가상 웹 권한이 분리돼 유효 기간을 무기한 연장할 수 있다.
- 최소 수정: 웹 권한을 소비할 때 관리 토큰의 현재 폐기/만료를 검사하거나 해당 상태 변화에서 권한 캐시를 무효화한다. 새 암호 인증 경로는 정상적으로 남기며, 단순 계정명 캐시를 인증 근거로 사용하지 않는다.
- 준비한 회귀: `_test_expired_web_session` — SSH 우회 권한을 실제로 모두 닫고 토큰의 만료 상태를 확인한 뒤 Browser 401/403·anonymous 및 무자격 재발급 거절을 검사한다.

## 3. P1 — v2 저장의 원격 mode 변조로 가상 파일 권한 상승

- 위치: [campaign_runtime.gd](../../godot/scripts/core/campaign_runtime.gd) `_sources_preserved` 124~135줄, `validate_world`의 원격 mode 검사 770줄 주변.
- 재현: 정상 초기 M01 v2 snapshot의 `current_world.remote_files.archive`에서 `/vault`를 `777`, `/vault/handoff.log`를 `644`로만 바꾼다. 이를 복원한 뒤 원래 guest 계정으로 접속해 보호 파일을 읽는다.
- 정적 근거: 보존 검사는 비교 사본의 mode를 원본 값으로 먼저 덮으므로 차이를 제거한다. 후속 검사는 세 자리 8진수인지 확인할 뿐이다. 현재 등록 API에는 원격 chmod가 없으므로 이 변화는 정상 Action으로 생성할 수 없다.
- 영향: canonical 본문/ID/출처를 바꾸지 않고도 저장 필드 하나로 가상 권한 경계를 넘는다. 원래 M01 저장기의 엄격한 원격 보존 검사보다 약한 회귀다.
- 최소 수정: 현재 지원 범위에서는 원격 mode도 원본과 일치시킨다. permission 모형의 별도 검증된 group grant는 그대로 허용하며, 미래의 권한 변경은 실제 지원 Action/허용 필드가 생긴 뒤 제한적으로 추가한다.
- 준비한 회귀: `_test_remote_mode_forgery` — 복원 거절·실패 원자성과 이후 guest의 보호 원본 읽기 거절을 각각 검사한다.

## 4. P1 — 업로드 정책을 다시 켜면 실행 가능한 저장물이 남아도 현재 완료

- 위치: [tool_runtime.gd](../../godot/scripts/core/tool_runtime.gd) upload 166~184줄; [campaign_runtime.gd](../../godot/scripts/core/campaign_runtime.gd) configure 609줄, `_computed_facts`/`_goal`/`_evaluate_completion`.
- 재현: M12의 전체 A 해법으로 실제 안전 완료를 얻는다. `upload_checked=false`로 바꾸고 가짜 JPEG/SCRIPT를 업로드해 `stored_files.execution_allowed=true`인 상태를 만든다. 추가 업로드 관찰 없이 `configure upload_checked true`만 수행한다.
- 정적 근거: 현재 저장물의 실행 허용을 해제하는 코드는 strict 업로드 관찰 안에 있다. configure는 bool만 바꾸고, 과거 solved/fact는 남으므로 현재 목표가 다시 true가 될 수 있다. 저장된 실행 허용/모델 executable 상태는 여전히 true다.
- 영향: 이는 과거 완료 영수증을 보존하는 문제가 아니라 **오염된 현재 상태를 새 안전 상태로 판정**하는 문제다. 그 true 상태가 유효 완료 checkpoint를 덮을 수도 있다. 실제 OS 코드 실행이 있다는 뜻은 아니다.
- 최소 수정: 정책 변경이 기존 가상 저장물의 유효 실행 권한도 일관되게 갱신하게 하거나, 현재 안전 조건이 만족될 때까지 현재 목표를 미충족으로 둔다. 과거 영수증은 취소하지 않는다.
- 준비한 회귀: `_test_upload_current_safety` — 완전한 선행 완료·실행 허용 저장물 생성이라는 사전 조건을 확인하고, 현재 완료와 현재 실행 허용이 동시에 true인 상태를 거절한다. 자동 정리와 미충족 유지 중 어느 일관된 처리도 허용한다.

## 5. P2 — 추가 결말이 아직 얻지 않은 후속 근거를 단정

- 출처: root의 콘텐츠 검토 추가 발견을 실제 데이터와 대조했다.
- 위치: [campaign.json](../../godot/data/campaign/campaign.json) endings 19001~19017줄, [campaign_game.gd](../../godot/scripts/core/campaign_game.gd)의 `choose_ending`/`get_view` ending availability.
- 재현: 모든 메인을 실제 해법으로 완료한다. S01 또는 S02/R01/P01을 A 해법의 main fact까지만 진행하고 post 근거 직전에 멈춘다. partial checkpoint를 유지한 채 M24로 돌아가 public_redacted 또는 independent_review를 선택한다.
- 정적 근거: requires_facts는 `s01_evidence` 또는 `s02_evidence/r01_evidence/p01_evidence`만 요구한다. 결말 문장이 주장하는 공지/재배포·검증기/메모리의 후속 확인은 `s01_exhibit_2/s02_exhibit_2/r01_exhibit_2/p01_exhibit_2`에서 생긴다.
- 영향: 아직 관찰하지 않은 결론을 후일담이 사실로 서술한다. 선택 사건을 끝까지 해야 기본 결말을 볼 수 있어야 한다는 뜻은 아니다.
- 최소 수정: 추가 결말의 주장에 필요한 post fact를 해당 requires_facts에 추가한다. 기본 sealed_audit는 선택 근거 없이 계속 유효하게 둔다.
- 준비한 회귀: `_test_ending_post_evidence` — main-only 실제 완료 snapshot에서 partial optional을 합법적으로 플레이하고 M24로 복귀한다. 확장 결말의 UI available=false/API 거절·상태 불변과 기본 결말 available=true를 함께 검사한다.

## 별도 판정 — 완료 영수증과 현재 재검증

최초 완료 Action에서 답장/후일담/영수증이 이미 커밋된 이후, 재방문 실험으로 현재 목표를 깨뜨려도 기존 진도를 지우지 않는 것이 타당하다. `_sync`는 현재 미충족 상태로 마지막 유효 완료 checkpoint를 덮지 않는다.

root는 이 판정을 채택했다. view의 `completion_recorded`와 `current_goals_met`는 파생값으로 분리하고, UI는 “현재 재검증 미충족 · 완료 기록 보존”, NEXT는 “완료 기록으로 계속”이라고 구분한다. 이를 위해 v2의 9개 저장 키나 모든 과거 완료를 되돌리는 규칙은 추가하지 않는다.

잘못 처리했을 때의 비용은 두 가지다. 과거 영수증을 지우면 이미 얻은 스토리·플레이 시간을 잃고, 현재 미충족을 안전 완료로 표현하면 지금의 상태와 후속 효과를 오해한다. 4번은 후자에 해당하므로 단순 라벨 변경만으로 닫을 수 없다.

## 테스트 기대값 정정과 검토한 경계

`Runtime.view.archive[].content`는 `display_content_key`를 번역한 화면 문구다. 이를 canonical `record.content`와 비교했던 테스트 기대값은 잘못됐다. 무결성 비교를 `snapshot.current_world.local_files`의 ID/content/source로 옮기고, UI 문구는 선언된 display key의 번역 결과로 별도 확인했다. 유효한 해법을 성공시키려고 보호 조건을 완화한 것이 아니다.

최종 getter 코드는 요청 터미널을 일시적으로 렌더링한 뒤 이전 terminal/sessions/pending 바인딩을 복원하고, 없는 터미널의 표시만으로 영구 world 항목을 만들지 않는다. 이 정적 검토에서 getter 문제를 별도 결함으로 확정하지 않았다. GET 빈 본문 preview와 상태 변경 메서드 구분도 최신 코드에 반영돼 있다.

## 검증 상태와 다음 순서

- 이 검토에서 runtime suite·gate·GUI·OS·사람 검증은 실행하지 않았다. 과거 336/32와 다른 작업자의 check-only를 새 캠페인 통과 근거로 쓰지 않는다.
- 5개 재현과 기존 56해법/부정 사례를 같은 campaign suite에 유지했다. 코드·콘텐츠는 root의 첫 전체 backend RED 수집 전까지 고치지 않는다.
- root가 실제 RED 결과·환경·대상 소스를 기록한 뒤 코어/데이터 담당자가 한 묶음으로 수정한다. 이후 전체 backend를 다시 확인하고 UI/3OS 검증과 분리한다.
- 이 문서의 정적 발견·준비된 테스트와 실제 재현/해소 결과를 구분해 후속 기록을 추가한다. 현재 PASS나 배포 완료 선언은 없다.
