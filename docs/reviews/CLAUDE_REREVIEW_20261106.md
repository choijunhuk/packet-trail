# Claude 재검토와 독립 수용 판단 · 2026-11-06

기준: `v1.4.0-rc1`, 실행 소스 `44c12d5`, 문서 태그 `2f166d7`. 사용자 요청에 따라 Claude를 다시 실행하고 지적을 실제 소스/재현 테스트로 확인했다.

## 실제 호출

Claude Code2.1.311, 요청 `claude-opus-5-5` / effort `high`. 세 응답의 `modelUsage`도 `claude-opus-5-5`를 보고했고 exit0, is_error=false, num_turns1, permission_denials=[]였다. 도구 목록을 비우고 MCP 서버를 비활성화한 읽기 전용 프롬프트 검토다. 저장166.40초, 모델186.85초, 사용성119.43초에 완료했다. 앞선600초/300초 시간 초과 호출을 이번 성공과 혼동하지 않는다. 진단 옵션을 제외한 실행이 성공했지만 과거 시간 초과의 단일 원인을 입증한 것은 아니다.

원문 프롬프트·응답 JSON은 로컬 `.omx/artifacts/claude-rereview-20261106/`, 전체 묶음은 `.omx/artifacts/claude-rereview-complete-20261106.md`에 있다. 아래 원문은 응답 결과를 그대로 보존한다.

## 수용 판단

| 지적 | 독립 확인·처리 |
|---|---|
| 생활 저장 손상 + 백업 없음 → 영구 잠김 | 재현. 원본/백업을 보존하는 명시적 생활 초기화·확인/취소·IO 실패 복구를 추가. 정상 저장에서는 초기화 API 거절 |
| 의뢰 백업이 본편47사건을 덮어씀 | 그대로는 기각. 독립 슬롯이며 정상 백업은 이미 감지. 다만 무효한 고립 백업의 직접 API 진입은 재현돼 backup_exists 조건 보강 |
| 향후 가격 변경 시 v1 저장 무효화 | 현재 버그는 아님. 배포 v1 골든 저장 fixture를 고정해 실수 검출. 가상 v2 마이그레이션은 추가하지 않음 |
| IAM 선택 경로만 검사해 현재 의뢰 초기 상태로 통과 | 현재 콘텐츠로 재현되지 않음. deny 요청에 대체 경로가 없고 초기 허용이 목표 위반. direct 강제는 의도된 제한 중계 해법을 파괴하므로 기각 |
| IAM 과거 검사와 현재 설정 불일치가 안 보임 | 재현. 요청별 current와 화면 재확인 안내 추가 |
| 승인 재빌드의 출처 불일치가 스키마 통과 | 재현. 승인 build만 digest/빌더/소스/신뢰 일치 검사. 교육용 잘못된 artifact는 보존 |
| JSON 왕복으로 IAM 저장 클리어 손실 | 캠페인은 정규화·재생하므로 저장 손실 주장은 기각. 직접 모델 경계의 정수 tick 비교 문제만 재현·수정 |
| release probe403을 액션 실패로 오인 | 현재 런타임은 ok로 반영하며 status는 가상 HTTP 응답이다. 기존 모델과 동일한 의미를 보존 |
| 분전함 선택 미적용 상태로 검증 가능 | 재현. 미적용 표시와 검증 차단, 적용 후 재활성화. UI 선택은 저장을 바꾸지 않음 |
| 힌트/툴팁 내부 ID | 보고 선택지는 현지화 라벨을 표시함. 힌트를 같은 표시 이름으로6언어 정렬, 불필요한 경로 ID 툴팁 제거. 모든 기술 토큰 금지 정규식은 기각 |
| 의뢰 버튼이 시작으로만 표시 | 실제6언어 값은 시작/이어하기. 기각 |
| 벤치 조명 현재 상태 미표시 / 야외 반영 없음 | 현재 선택 비활성화만 수용. 공유 WorldEnvironment가 야외도 변경하므로 추가 조명 계층은 불필요 |
| 패널 재구성 시 키보드 포커스 손실 | 재현. 최초 포커스·의미가 같은 상품/조작 복원·비활성 시 닫기 대체·스크롤·모달 종료 후 이전 포커스 복원 |

## 검증

집중 회귀: 생활1,125 / 의뢰UI43 / 생활UI52 / IAM182 / 공급망138, 실패0. 새로운 문제의 RED를 확인한 뒤 GREEN을 확인했다. 기존4선택/47사건/94경로와 선택4해법을 보존한다. 통합 gate PASS와 선택·생활 네이티브903/0·30PNG를 확인했다. 이후 사용자 요청의 전체 수동 저장·게임 창 연출까지 합친1.5검증/배포는 [구현 기록](../implementation/2026-11-06-manual-profiles.md)에 구분한다.


## 후속 검토와 실제 화면 확인

수정본을 Claude Opus5.5 high에 다시 제공했고120.99초에 정상 응답했다. 차단 수준 문제 없음, 비차단 제안2건과 조건부 확인1건을 보고했다.

- 유효 백업이 있으면 생활 초기화 대신 복구를 우선하도록 반영했다. 확인 창이 열린 사이 정상 백업이 생기는 경우도 디스크에서 다시 확인하고 파일을 이동하지 않는다.
- 비활성화된 구매/장착 버튼에서 첫 활성 동작으로 자동 포커스 이동하라는 제안은 기각했다. 연속 Enter로 다른 구매가 실행되지 않도록 닫기로 이동하는 의도적 대체 동작을 유지했다.
- release 스키마의 JSON 정수형 float 허용 불일치는 직접 입력에서 재현했다. 정수 검증 뒤에만 int 변환해200/403/503 비교를 수행하고 소수·문자열·불리언 거절을 유지했다.
- 실제 큰 글씨 화면에서 새 초기화 확인 문구가 창을 가로로 넘치는 문제가 추가 발견됐다. 이는 Claude가 실행해서 찾은 결과가 아니라 네이티브 QA의 발견이다. 확인 창 줄바꿈/크기를 보정했고 KO/DE 큰 글씨의 실제 취소/확인과 원본 보존을 재검증했다.

## 원문

### storage

# 저장소 리뷰: habitat / save_store / room 커미션 경로

도구 없이 제공된 소스만 읽고 검토했습니다. 테스트를 실행하지 않았고 파일도 바꾸지 않았습니다.

## 증명된 소스 결함

### [P2] 방 저장이 손상되고 정상 백업이 없으면 꾸미기 기능이 영구히 잠김

- **위치**: `godot/scripts/core/habitat_store.gd`의 `load_state` / `apply` / `recover_backup`, `godot/scripts/room/room.gd`의 `_recover_habitat`
- **재현**:
  1. 첫 구매를 한 번만 합니다. 이 저장에서는 `previous`가 비어 있어서 `.bak`가 만들어지지 않습니다 (`save_store.gd`의 `save`).
  2. `habitat_01.json`이 손상됩니다(외부 편집, 부분 쓰기 등).
  3. 손상 이후 흐름:
     - `load_state`가 `load_save`를 거쳐 `backup_available=false`를 받고, `_remember_failure`가 `_writable=false`로 둡니다.
     - `get_view().recovery_available`는 `not _writable and _backup_available`이므로 `false`입니다.
     - `apply`는 항상 `HABITAT_RECOVERY_REQUIRED`를 돌려줍니다.
     - `recover_backup`는 `SAVE_BACKUP_INVALID`를 돌려줍니다.
  4. `save_store.start_new`는 있지만 habitat_store와 room.gd 어디에서도 호출하지 않습니다. 새로 시작할 경로가 없습니다.
  5. 같은 원인이 하나 더 있습니다. `_remember_failure`가 `_loaded=true`로 고정하므로 같은 실행 중에는 다시 읽지도 않습니다.
- **영향**: 선택 콘텐츠(방·캐비닛 잡)를 그 세이브로는 다시 쓸 수 없습니다. 같은 패턴인 커미션 경로에는 `"fresh"`가 있어서 동작이 서로 다릅니다.
- **최소 수정**: `start_new`를 감싸는 메서드를 추가하고, 확인을 거쳐 패널 버튼에 연결합니다.

  ```gdscript
  func start_fresh() -> Dictionary:
      var guard: Dictionary = _guard()
      if not guard.ok:
          return guard
      var started: Dictionary = _store.start_new(_fresh_snapshot(), validate_snapshot, _path)
      if not started.ok:
          return _remember_failure(started) if not _writable else started
      _snapshot = _fresh_snapshot()
      _loaded = true
      _writable = true
      var result: Dictionary = _success("HABITAT_FRESH", "Starter room restored; previous files preserved.", true)
      result["damaged_path"] = started.get("damaged_path", "")
      return result
  ```

  `get_view`에는 `view["fresh_available"] = _loaded and not _writable`를 추가합니다. room.gd에는 `_recover_habitat`와 같은 형태의 `_fresh_habitat`를 추가합니다.
- **회귀 테스트**:
  1. `user://tests/habitat_locked.json`에 깨진 JSON을 쓰고 `.bak`는 만들지 않습니다.
  2. 고치기 전 동작을 확인합니다. `load_state().ok == false`, `recovery_available == false`, `apply("set_lighting", {"lighting":"dawn"}).code == "HABITAT_RECOVERY_REQUIRED"`.
  3. 고친 뒤 기대 동작을 확인합니다.
     - `start_fresh().ok`이고 `damaged_path` 파일이 존재합니다.
     - 이어서 `apply(...)`가 성공합니다.
     - 정상 저장 상태에서 `start_fresh()`를 부르면 거부됩니다 (`RECOVERY_NOT_NEEDED`).

## 가설 (제공되지 않은 코드나 향후 변경에 의존)

### [P1 조건부] 메인 저장 없이 `.bak`만 있을 때 `open_commission`이 조사 캠페인 백업을 덮어쓸 수 있음

- **위치**: `room.gd`의 `open_commission`과 `commission_entries` 비교
- **증명된 부분**: 두 함수의 조건이 다릅니다.
  - `commission_entries`는 `exists or backup_available or backup_exists`로 판단합니다.
  - `open_commission`은 `exists or backup_available`만 봅니다. 앞쪽에서 굳이 `backup_exists`를 추가했다는 것은 `get_save_status`가 `path_status`와 같은 키를 돌려줄 수 있다는 신호입니다.
- **"메인 없음 + 정상 `.bak`" 상태는 save_store 자체에서 생깁니다**: `recover_backup`가 `rename(path, damaged)`에 성공한 뒤 `rename(tmp, path)`에서 실패하면 이 상태가 됩니다(`SAVE_RECOVERY_FAILED`).
- **재현 가설** (`CommissionGame.get_save_status`가 `backup_available` 없이 `backup_exists`만 돌려주는 경우):
  1. 위 상태에서 세션이 비활성인 채로 `open_commission("I01")`이 호출됩니다.
  2. 로드를 건너뛰고 새 candidate로 `choose_mission` → `save_game`이 실행됩니다. 메인 경로에 새 게임이 기록됩니다.
  3. 다음 저장에서 `.bak`가 이 새 게임 상태로 교체됩니다. 기존 조사 캠페인 진행(필수 47케이스 쪽)이 사라집니다.
- **영향**: 선택 기능의 진입점이 필수 캠페인 진행을 지울 수 있습니다.
- **최소 수정**: 두 함수가 한 판정을 함께 쓰게 합니다.

  ```gdscript
  func _commission_disk_state(status: Dictionary) -> bool:
      return status.get("exists", false) or status.get("backup_available", false) or status.get("backup_exists", false)
  ```
- **회귀 테스트**:
  1. 슬롯을 `user://tests/inv.json`으로 둡니다.
  2. 정상 저장을 2회 해서 `.bak`를 만든 뒤 메인 파일을 지웁니다.
  3. `open_commission("I01")`을 호출합니다.
  4. 기대 결과: `ok == false`, 메인 파일이 생성되지 않음, `.bak` 바이트가 그대로.

### [P3] 재생 검증이 현재 상수에 묶여 있어 밸런스 조정 시 모든 방 저장과 백업이 동시에 무효화됨

- **위치**: `habitat_store.gd`의 `validate_snapshot`과 `_transition`
- **근거(증명)**:
  - 검증기는 `_fresh_state()`(`STARTING_CREDITS`)에서 시작해 현재 `CATALOG[id].price`와 `JOB_REWARD`로 이벤트를 재생합니다.
  - 그 결과가 저장된 `state`의 `balance`, `orders[].price`와 정확히 같아야 통과합니다(`recursive_equal`).
  - `save_version`은 1로 고정되어 있습니다.
- **가설(향후 변경)**: 가격이나 보상을 한 번 바꾸거나 상품 ID를 하나 지우면 다음과 같이 진행됩니다.
  1. 메인 저장과 `.bak` 모두 `HABITAT_INVALID_SAVE`가 됩니다.
  2. 모든 플레이어가 위 P2 잠금 상태에 들어갑니다.
  3. 현재 테스트는 같은 빌드 안에서 저장하고 읽기만 하므로 이 문제를 잡지 못합니다.
- **최소 수정**: v1 가격·초기값·보상 상수를 `V1` 테이블로 고정하고, 재생은 `save_version`별 테이블을 쓰게 합니다. 밸런스를 바꿀 때는 버전을 올리고 마이그레이션 경로를 추가합니다.
- **회귀 테스트**: 모든 액션(구매 5, 수령, 장착, 조명, 잡 보상 후 재설정)을 담은 v1 골든 세이브 fixture를 커밋합니다. 테스트는 `load_state().ok`와 `balance`/`owned`/`job.rewarded`를 정확히 단언합니다. 상수가 바뀌면 즉시 실패합니다.

## 확인했지만 결함 없음

- **`_compact_history`**: 보상 구성, 마지막 구성 2개, 보상 검증, 마지막 검증을 남기는 규칙을 수작업으로 추적했습니다. "보상 → 다른 경로 → 보상 경로로 복귀" 등 여러 순서에서 재생 결과가 같았습니다.
- **액션 수 상한**: 압축 후 대략 21개 이하로 유지되어 `MAX_ACTIONS`에 닿지 않습니다.

### models

# 검토 결과: IAM/공급망 케이스 모델 (읽기 전용)

전제: `tool_runtime.gd`와 `campaign_model_view.gd`는 "SELECTED METHODS" 헤더만 있고 본문이 비어 있었습니다. 그래서 런타임 연동이나 저장 형식에 관한 내용은 모두 **가설**로 분리했습니다. 테스트는 실행하지 않았습니다.

---

## 입증된 소스 결함

### [P1] IAM 승리 판정이 플레이어가 고른 경로 하나만 봄 → 우회 경로 취약점을 고치지 않아도 클리어됨
- **위치**: `iam_case.gd` `goal_met`
- **근거**:
  - `goal_met`은 `observed.get("route_id")`, 즉 플레이어가 마지막으로 probe한 경로 하나의 결정만 `expect`와 비교합니다.
  - `routes`에 있는 다른 경로(대리 credential)는 평가하지 않습니다.
  - `deny` 기대값은 사유를 가리지 않습니다. `DEFAULT_DENY`든 `CREDENTIAL_REVOKED`든 `CREDENTIAL_EXPIRED`든 모두 통과합니다.
- **재현**:
  1. 필수 deny 요청 R에서 `direct`는 원래 거부되고, `routes.deputy`는 넓은 권한의 서비스 주체 credential로 허용되도록 정의합니다. 경로 레지스트리와 `route_options` 노출이 존재하는 이유가 이 구조입니다.
  2. 초기 상태에서 allow 요청과 R을 둘 다 `route_id:"direct"`로 probe합니다.
  3. 바인딩을 하나도 바꾸지 않았는데 `solved == true`가 됩니다.
  - allow 쪽도 같은 문제가 있습니다. direct가 막혀 있어도 특권 경로로 probe하면 "정상 접근 유지"가 충족됩니다.
- **영향**: 선택 케이스의 핵심 판정이 무력화됩니다. 고칠 대상을 고치지 않고 클리어할 수 있습니다. 해당 경로는 `SENSITIVE_PATHS`(`godot/scripts/core/**`)에 속합니다.
- **최소 수정**: 기존 receipt 일치 검사는 유지하고, `goal_met`에 아래 검사를 추가합니다.
  ```gdscript
  var request: Dictionary = definition.requests[id]
  if request.expect == "deny":
      for r in ["direct"] + request.get("routes", {}).keys():
          if _receipt(definition, state, id, r).decision != "deny":
              return false
  elif route != "direct":
      return false
  ```
  - allow를 특정 경로로 의도한 데이터가 있다면, 이 하드코딩 대신 요청별 `required_route` 필드를 둡니다.
  - revoke로 대리 경로를 닫는 것을 정답으로 인정할지는 설계 판단입니다. 위 수정을 적용하면 인정됩니다.
- **회귀 테스트**:
  - 위 픽스처에서 초기 상태로 direct만 probe하면 `goal_met == false`.
  - 서비스 주체 바인딩을 최소 권한 역할로 바꾸고 재-probe하면 `true`.
  - 모든 IAM 미션 데이터에 대해 `goal_met(def, initial_state(def, {}))`가 false인지 확인하는 콘텐츠 검사도 추가합니다.

### [P2] IAM receipt가 낡았는지 플레이어에게 보이지 않음 → "다 맞는데 클리어 안 됨" 상태
- **위치**: `iam_case.gd` `public_data`(requests 행), `_basis`
- **근거**:
  - `basis`는 전체 bindings, revoked, tick의 해시입니다.
  - 따라서 bind, revoke, advance 중 무엇을 해도 **모든** receipt가 `goal_met`에서 불일치가 됩니다.
  - 그런데 `public_data`는 `observed`만 보여주고, 현재 상태와 일치하는지는 노출하지 않습니다. release 케이스는 `deployment.current`로 이를 노출합니다.
- **재현**:
  1. allow 요청 A를 probe해서 allow를 확인합니다.
  2. 무관한 주체 P의 바인딩을 변경합니다.
  3. deny 요청 B를 probe해서 deny를 확인합니다.
  4. 화면에는 A=allow/기대 allow, B=deny/기대 deny로 표시되지만 `solved == false`입니다.
- **영향**: 피드백이 막힙니다. 플레이어는 원인을 모른 채 반복 시도하게 됩니다.
- **최소 수정**: requests 행에 `"current"` 필드를 추가합니다. receipt가 Dictionary이고 route가 유효하며, 그 route로 다시 계산한 `_receipt` 결과와 같을 때 true입니다. UI는 false면 "재확인 필요"를 표시합니다.
- **회귀 테스트**: 위 재현에서 A 행이 `current == false`인지, A를 재-probe하면 `true`가 되고 `solved == true`가 되는지 확인합니다.

### [P3] release 스키마가 build의 `statement_id`/`registry_id`를 필수로 요구하지만, 모델은 이 값을 쓰지 않고 검증 가능성도 확인하지 않음
- **위치**: `release_case_schema.gd` `validate`(builds 루프), `release_case.gd` `_valid_verification`
- **근거**:
  - 스키마는 두 참조가 레지스트리에 존재하는지만 확인합니다.
  - 그 statement의 `subject_digest`가 build payload digest와 같은지, `builder_id`와 `source_revision`이 일치하는지, registry가 그 builder를 신뢰하는지(그리고 revoke하지 않았는지)는 확인하지 않습니다.
  - 모델 쪽은 플레이어가 고른 statement와 registry로만 검증하고, build에 선언된 참조는 어디에서도 읽지 않습니다.
- **재현**: build payload를 한 글자 수정합니다. 그러면 statement digest가 불일치합니다. 그래도 스키마는 오류 0건이고, 재빌드 경로는 `deploy`에 영원히 도달하지 못합니다.
- **영향**: 저작 실수로 풀 수 없는 선택 케이스가 검증을 통과합니다. 솔루션 픽스처가 없는 케이스에서는 검출되지 않습니다.
- **최소 수정**: builds 루프에서 `Model._valid_verification(definition, {"built":[id]}, {"artifact_id":id, "statement_id":build.statement_id, "registry_id":build.registry_id})`가 false이면 오류를 냅니다.
- **회귀 테스트**: digest가 불일치하는 build 픽스처에 대해 `validate()`가 비어 있지 않은 오류 목록을 반환하는지 확인합니다.

---

## 가설 (보이지 않는 코드에 의존)

### [P2·조건부] JSON 왕복 후 IAM `goal_met`이 영구 false
- **위치**: `iam_case.gd` `goal_met`의 `observed.recursive_equal(current, 0)`
- **근거**:
  - Godot 4의 `recursive_equal`은 타입까지 엄격하게 비교합니다(`hash_compare`). 그래서 `int 3`과 `float 3.0`은 다른 값으로 취급됩니다.
  - `JSON.parse_string`은 숫자를 float으로 복원합니다.
  - `_valid_state`/`_integer`는 float tick을 받아들이므로 로드 자체는 성공합니다. 하지만 `_receipt`는 `int(state.tick)`을 넣기 때문에 비교가 실패합니다.
  - release 쪽은 `!=` 연산자를 쓰므로 int/float 차이에 관대합니다. 두 모델이 비대칭입니다.
- **조건**: 캠페인 저장이 JSON을 거칠 때만 발생합니다. `store_var`나 `var_to_str`을 쓰면 해당하지 않습니다.
- **영향**: 클리어한 케이스가 재시작 후 미해결로 보일 수 있습니다. 재-probe하면 복구됩니다.
- **최소 수정**: `initial_state`의 previous 경로에서 `tick`과 각 receipt의 `tick`을 `int()`로 정규화합니다.
- **회귀 테스트**: `goal_met(def, JSON.parse_string(JSON.stringify(solved_state)))`가 true인지 확인합니다.

### [P3] release `_ok`의 `status`가 가상 서비스 응답 코드(403/503)를 그대로 반환
- **위치**: `release_case.gd` `_ok`의 `feedback.get("status", 200)`
- **근거**: 기대값이 403/503인 service check를 정상적으로 probe해도 액션 결과 `status`가 403/503이 됩니다. IAM은 항상 200을 반환합니다.
- **조건**: `tool_runtime`이나 view가 `status`를 기준으로 명령 실패 표시, trace 또는 경보를 처리한다면, 정답 행동이 실패처럼 보입니다.
- **최소 수정**: `_ok`는 `status: 200`을 반환하고, 서비스 코드는 `feedback.status`에만 남깁니다.
- **회귀 테스트**: `expected_status == 403`인 case를 probe했을 때 `result.status == 200`이고 `feedback.status == 403`인지 확인합니다.

---

참고로 IAM은 입력에 `terminal_id`/`challenge_id` 같은 envelope 키를 허용하지만, release의 `_valid_input`은 이를 거부합니다. 런타임이 이 키들을 공통으로 주입한다면 release 액션이 전부 `RELEASE_INVALID`가 됩니다. 기존 검사가 통과한다고 하셨으므로 현재는 발생하지 않는 것으로 보지만, `tool_runtime`을 확인할 때 같이 봐 주세요.


### experience

# 검토 결과 (읽기 전용, 제공된 소스 기준)

테스트는 실행하지 않았습니다. 판단 근거는 제공된 코드와 문자열뿐입니다. Room의 액션 처리기, `_close_habitat_panel`, 생활 모델, I02 도구 UI는 받지 못했으므로 그 부분에 기대는 내용은 가설로 표시했습니다.

---

## P2-1 · [소스로 증명] 분전함: 설정을 적용하지 않아도 검증 버튼이 열려 있어 플레이어가 함정에 빠짐

- **위치**: `godot/scripts/presentation/habitat_panel.gd` `render()`의 `network_cabinet` 분기
- **근거**:
  - 경로 `OptionButton`과 잠금 `CheckBox`의 값은 `HAB_CONFIGURE`를 눌러야만 `configure_cabinet`으로 전송됩니다.
  - `HAB_VERIFY`는 `verify_job`, `{}`로 보내므로 화면의 컨트롤 값을 읽지 않습니다. 활성 조건도 `ready and job.inspected`뿐입니다.
  - `item_selected`·`toggled` 연결이 없어서 컨트롤 값이 저장값과 달라도 화면에 아무 표시가 없습니다.
- **재현**:
  1. 일감을 수락하고 조사합니다. 경로는 `public`, 잠금은 해제된 상태입니다.
  2. 드롭다운을 "service"로 바꾸고 잠금을 체크합니다.
  3. 설정 버튼을 누르지 않고 "검증"을 누릅니다.
  4. 저장된 `public`/미잠금 상태로 판정되어 `HABITAT_JOB_CHECK_FAILED`가 나옵니다.
- **영향**: 정답을 고른 플레이어가 실패 판정을 받고, 자기 추론이 틀렸다고 오해합니다. 재렌더가 일어나면 드롭다운이 저장값으로 되돌아가 선택이 "사라진" 것처럼 보입니다. 같은 실패가 반복되면 실험 기록도 쌓입니다(이전 검토에서 지적된 기록 한도 문제와 같은 경로).
- **최소 수정**: 저장 모델은 그대로 두고 UI만 고칩니다.
  - `route.item_selected`와 `locked.toggled`에 동기화 콜백을 연결합니다.
  - 컨트롤 값이 `view.job.route`/`view.job.locked`와 다르면 `controls.verify_job.disabled = true`로 막고, `feedback`에 "적용되지 않은 변경" 키를 표시합니다.
  - 이를 위해 verify 버튼을 콜백 연결보다 먼저 생성합니다.
- **회귀 테스트**:
  1. `job={accepted:true, inspected:true, route:"public", locked:false, ...}`로 패널을 setup합니다.
  2. `controls.route.select(1)`, `controls.locked.button_pressed = true`로 바꾸고 시그널을 emit합니다.
  3. `controls.verify_job.disabled == true`인지 확인합니다.
  4. configure를 누르면 `{"route":"service","locked":true}`가 emit되는지 확인합니다.
  5. 갱신된 view로 `render()`한 뒤 verify가 활성인지 확인합니다.

## P2-2 · [문자열은 증명 / 영향은 조건부] I02 마지막 힌트와 경로 툴팁에 내부 식별자가 노출됨

- **위치**:
  - `investigation_v1.ko.json`의 `IV1_I02_HINT_3`
  - `habitat_panel.gd`의 `route.set_item_tooltip(..., id)`
- **근거**:
  - HINT_3은 "`stable_evidence·delivered_evidence`의 공개 digest를 보고"하라고 안내합니다.
  - 같은 대상에는 현지화된 라벨이 따로 있습니다. `IV1_I02_EVIDENCE_STABLE`은 "독립 원장의 비교 자료", `..._DELIVERED`는 "전달받은 배포 자료"입니다.
  - 경로 툴팁도 `approved_relay` 같은 원시 ID를 그대로 보여줍니다.
- **영향**: 가장 막힌 플레이어가 보는 3단계 힌트가 화면에 없는 이름으로 대상을 지칭합니다. 다른 5개 언어에도 같은 패턴이 있다면 같은 문제가 생깁니다.
- **가설 경계**: I02 보고 필드 선택 UI가 원시 필드명을 의도적으로 보여준다면, 해커 연출로서 일관된 표현이므로 결함이 아닙니다. 이 부분은 I02 도구 UI를 확인해야 판정할 수 있습니다.
- **최소 수정**:
  - HINT_3을 "독립 원장의 비교 자료와 전달받은 배포 자료의 공개 digest"로 바꾸고 6개 언어에 똑같이 적용합니다.
  - 툴팁 줄은 삭제합니다. 항목 텍스트가 이미 현지화되어 있습니다.
- **회귀 테스트**: 로케일 린트를 추가합니다. 플레이어에게 보이는 값에 `\b[a-z]+_[a-z_]+\b` 토큰이 있으면 실패시키고, 계정명 같은 허용 목록만 예외로 둡니다. 패널 테스트에서는 각 경로 항목의 `get_item_tooltip(i)`가 비어 있거나 현지화된 값인지 확인합니다.

## P3-3 · [증명] 의뢰 버튼이 상태와 관계없이 항상 "시작"으로 표시됨

- **위치**: `godot/scripts/apps/campaign_desktop.gd` `_show_commissions()`
- **근거**: `completed` 여부에 따라 `UI_COMMISSIONS_DONE` 라벨만 추가되고, 버튼은 언제나 `UI_COMMISSIONS_START`입니다. 문서(`optional-living.md`)는 "시작/재개"를 약속하지만, 진행 중 상태는 표시되지 않습니다.
- **영향**: 진행 중인 의뢰가 있는 플레이어는 "시작"이 진행 상황을 초기화할까 봐 망설입니다. 완료한 의뢰에서는 "다시 하기"인지 "기록 보기"인지 알 수 없습니다.
- **가설**: 완료된 의뢰를 다시 시작했을 때 실제로 초기화되는지는 Room·모델 코드를 확인해야 합니다.
- **최소 수정**: 엔트리에 이미 있는 상태 필드(예: `started`/`in_progress`)로 버튼 키를 고릅니다. `START`, `RESUME`, `REVIEW` 3종입니다. 해당 필드가 없다면 `commission_entries()`에 bool 하나를 추가합니다.
- **회귀 테스트**: 가짜 room이 `[{id:"I01", completed:false, in_progress:true}, {id:"I02", completed:true}]`를 반환하게 하고, 각 `commission_id` 버튼의 텍스트가 서로 다른 키인지 확인합니다.

## P3-4 · [일부 증명 + 가설] 벤치 조명: 현재 상태가 보이지 않고, 안뜰에서는 효과가 없을 수 있음

- **위치**:
  - `habitat_panel.gd`의 `render()` `bench` 분기
  - `neighborhood_world.gd`의 `apply_habitat()`
- **증명된 부분**:
  - bench 분기는 `view.lighting`을 읽지 않습니다. 밤/새벽 버튼이 항상 둘 다 활성입니다.
  - 상점의 `HAB_EQUIPPED`처럼 현재 선택을 보여주는 표시가 없습니다.
  - `apply_habitat()`도 lighting을 무시하며, `OmniLight3D`는 고정값입니다.
- **가설**: Room이 공유 `WorldEnvironment`로 안뜰 조명까지 바꾸지 않는다면, 플레이어는 안뜰 벤치에서 조명을 골라도 변화를 보지 못합니다. 피드백은 0.58 스크림 뒤의 텍스트뿐입니다.
- **최소 수정**:
  - `_action("HAB_LIGHT_NIGHT", ..., ready and view.get("lighting") != "night")`처럼 현재 값을 비활성화합니다. dawn도 같은 방식입니다.
  - 안뜰 반영이 의도된 기능이라면 `apply_habitat`에서 light의 `light_color`/`light_energy`를 lighting에 따라 2값 분기합니다.
- **회귀 테스트**:
  - `lighting:"dawn"`인 view로 렌더했을 때 dawn 버튼이 disabled이고 night 버튼이 enabled인지 확인합니다.
  - `apply_habitat({"lighting":"dawn"})` 전후로 OmniLight 색이 다른지 확인합니다. 이 검사는 의도가 확정된 경우에만 둡니다.

## P3-5 · [가설] 키보드만 쓰는 사용자의 포커스가 유실됨

- **위치**: `habitat_panel.gd`의 `setup()`, `render()`
- **근거**:
  - `setup()`은 어떤 컨트롤에도 `grab_focus()`를 호출하지 않습니다.
  - `render()`는 content의 자식을 전부 `queue_free`합니다. Room이 액션을 처리할 때마다 `render()`를 호출한다면, 방금 누른 버튼이 해제되면서 포커스가 사라집니다. `follow_focus = true`도 소용이 없습니다.
  - Room의 호출 경로는 제공되지 않았습니다.
- **영향**: 키보드/패드 사용자가 주문이나 장착을 할 때마다 탭 순서 처음부터 다시 이동해야 합니다. 1.6배 큰 글씨 사용자처럼 스크롤이 긴 경우 특히 불편합니다.
- **최소 수정**:
  - `render()` 시작 시 포커스 버튼의 `habitat_action`과 `product_id` 메타를 기억합니다.
  - 재구성 후 같은 메타를 가진 버튼에 `grab_focus.call_deferred()`를 호출하고, 없으면 닫기 버튼에 포커스를 줍니다.
  - `setup()` 끝에서도 첫 활성 버튼에 포커스를 줍니다.
- **회귀 테스트**: 상점 패널에서 두 번째 상품의 order 버튼에 포커스를 둔 상태로, 해당 상품이 owned가 된 view로 `render()`를 실행합니다. 한 프레임 뒤 `get_viewport().gui_get_focus_owner()`의 `product_id` 메타가 같은지 확인합니다.

---

**범위 밖 확인 사항**: 메인 4선택과 47사건의 보존, 의뢰 간 선수 조건, 강제 반복 작업은 제공된 소스에서 위반을 찾지 못했습니다. 비용 1,320과 시작 크레딧 1,500으로 반복 작업 없이 전부 구매할 수 있습니다.
