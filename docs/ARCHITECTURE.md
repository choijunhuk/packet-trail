# 심야접속(가칭) 기술 설계 v0.2

작성일: 2026-11-04 · 대상: Windows/macOS/Linux 설치형 게임 · 저장소 ID: `packet-trail`.
현재 구현·검증 상태는 [README 현재 상태](../README.md#현재-상태)를 따른다. 아래 상세 설계보다 단계별 최소 계약이 먼저다.
사용자가 정한 가상 OS·다중 터미널·해킹 도구·가상 인터넷·리눅스 명령·스토리를 Godot 4+GDScript로 구현하는 방법을 다룬다.
Godot 권고는 Hacknet의 XNA/FNA 계열 기술(이번 조사에서 MonoGame 사용은 미확인)을 그대로 재현해야 한다는 뜻이 아니다.
구현 시작 시 Godot 4의 구체적인 안정 버전과 export template 버전을 함께 고정하고 세 플랫폼 빌드 기록에 남긴다.

## 1. 만들 것과 단계별 경계

단계별 구현 범위와 다음 단계 판단은 [ROADMAP](ROADMAP_AND_QA.md#단계별-필수-범위) 한 곳에서 정한다. 아래 각 절의 단계 표기는 그 표를 따른다.

P1의 M01은 ‘첫 번째 야간 의뢰’다. 익명 연락처 서윤이 삭제될 인계 기록의 사본 회수를 요청한다. 플레이어는 `guest`로 접속해 거부당하고, 남은 메모의 정비 계정으로 다시 접속해 지정 자료를 회수한 뒤 후일담·다음 단서를 받는다. 패치·보고서 시험은 완료 조건이 아니다. 세부 명세는 [CURRICULUM.md](CURRICULUM.md)를 따른다.
v0는 P2의 세 미션 프리셋을 뜻한다. M05·M09의 필요한 상태와 맥락 안내를 제공하되 정식 캠페인 완료 기록은 만들지 않는다.
v1 표기는 명령의 1.0 목표 범위를 뜻한다. 모든 v1 기능을 MVP에 먼저 만드는 계획은 아니다.
실제 VM, 컨테이너, 실제 셸, 범용 브라우저, 런타임 LLM, 사용자 코드 실행, 확장 편집기는 범위에 넣지 않는다.
권고 표현 방식은 작은 3D 작업실+가독성 좋은 2D 전체화면 가상 OS다. 3D 도시·오픈월드는 만들지 않는다.
중심 흐름은 네트워크 침투의 정찰→초기 진입→권한/발견→내부 이동→목표 달성이다. 웹·시스템·계정은 같은 가상 네트워크에서 선택/조합하는 접근 경로다.
1.0은 웹+서버/시스템+로그/패킷의 메인24+선택4에 집중한다. 리버싱/포너블은 기초 문자열·흐름 분석/작은 가상 메모리 모델의 기술 스파이크 후 선택 사건 후보로만 검토한다.
실제 바이너리의 범용 실행 엔진은 현재 범위가 아니다. 모바일·AD·cloud·WiFi의 별도 세계 모델은 후속 범위이며 상세 경계는 DOMAIN_SCOPE 문서를 따른다.
후속 접점은 기존 앱 등록·콘텐츠 계약을 이용하는 수준으로 남긴다. 별도 VM·디컴파일러·에뮬레이터나 미래용 추상계층은 추가하지 않는다.

## 2. 가상 데스크톱과 창

P0/P1은 `Desktop: Control`과 터미널 한 개로 시작한다. P2에 `Room: Node3D`와 `DesktopCanvasLayer`를 추가하고 각 앱 내용 장면을 재사용한다.
첫 선택은 Godot `Window`를 임베드하는 방식이다. 부모 Viewport의 `gui_embed_subwindows`와 프로젝트의 `display/window/subwindows/embed_subwindows`를 확인하고 게임 창 내부에만 표시한다.
`Window`는 네이티브 창과 임베드 창을 지원한다. 닫기 요청은 `close_requested` 처리로 앱의 수명 정책에 연결한다. [Godot Window](https://docs.godotengine.org/en/stable/classes/class_window.html), [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-property-gui-embed-subwindows)
기본 이동·크기 조절·포커스 기능을 먼저 재사용하고, 앱별로 창 이동 코드를 복제하지 않는다.
작업 표시줄의 최소화는 앱 창을 숨기고 세션을 유지하는 게임 동작이다. 운영체제 최소화와 동일하다고 가정하지 않는다.

| 장면/앱 | 책임 | 코어 상태와의 접점 |
|---|---|---|
| Desktop / Taskbar | 앱 실행·창 목록·앞으로 가져오기·복원 | 앱 인스턴스 ID와 UI 배치만 보관 |
| TerminalWindow | `RichTextLabel` 출력 + `LineEdit` 입력, 기록·자동완성 | terminal session ID로 명령 제출 |
| BrowserWindow | 주소·뒤로/앞으로·새로고침·링크·검색·폼 | browser session ID로 가상 요청 제출 |
| ToolWindow | 대상·옵션·실험·비교 결과 표시 | 터미널과 같은 명령/Action 호출 |
| NetworkMap | 발견한 노드·서비스·경로 시각화 | WorldState의 발견 정보 조회 |
| MailWindow | 사건 수신·인물 답신·새 도구 안내 | 미션/스토리 이벤트 조회 |
| EvidenceBoard | 출처·관찰·가설·재검증 묶기 | 자동 관찰 조회·선택적 pin·보고 Action 제출 |

터미널은 Enter 제출을 `LineEdit.text_submitted`로 받고 제출 뒤 입력 포커스를 유지한다. 한글 조합 중 Enter·Tab·화살표가 명령 제출/기록 탐색으로 중복 처리되지 않는지 별도 확인한다. [Godot LineEdit](https://docs.godotengine.org/en/stable/classes/class_lineedit.html#class-lineedit-signal-text-submitted)
출력은 선택·복사가 가능하며 최근 출력 한도를 둔다. 스크롤 중 새 로그가 와도 읽던 위치를 빼앗지 않는다.
창 닫기는 표시만 종료하고 앱 상태·터미널 연결·브라우저 쿠키/이력을 유지한다. 다시 열면 같은 앱 상태에 연결한다. `exit`는 해당 터미널의 연결 스택 한 단계를 종료하고, 명시적 로그아웃/세션 폐기는 해당 가상 인증만 만료시킨다. 최소화·포커스 변경도 가상 권한·미션 시간에 영향을 주지 않는다.
임베드 창의 배율·한글 IME·키보드 전환·제목줄 경계가 스파이크에서 해결되지 않으면 `PanelContainer` 기반 Control 창틀로 전환한다.
전환 시 앱 내용 장면과 WorldState는 유지한다. 두 종류의 창 관리자를 완제품으로 병행 개발하지 않는다.
P0는 개발 OS의 터미널 한 개에서 IME·포커스를 확인한다. P2는 터미널 2개+브라우저 1개(탭2개)의 입력 격리와 배율 복원으로 넓힌다.

## 3. 공유 상태와 처리 경로

미션 실행 하나에 `WorldState` 하나를 둔다. 캠페인은 사건별 실행 스냅샷과 명시적 이월 사실을 연결하는 구조이며 모든 원격 파일 변경을 영구 보존하는 오픈월드는 아니다. 터미널·도구·브라우저·맵이 각자 서버 상태를 복사해 소유하지 않는다.
불변 콘텐츠 정의와 가변 실행 상태를 구분한다. UI는 조회 결과를 표시하고 상태 변경은 `dispatch(action)`을 통해서만 요청한다.
코어는 `RefCounted` 기반 GDScript와 값 자료로 구성한다. Godot 엔진은 사용하지만 Control·Node 경로·SceneTree·프레임 입력에는 의존하지 않는다. [Godot RefCounted](https://docs.godotengine.org/en/stable/classes/class_refcounted.html)

```text
입력/클릭 → Action 생성 → 형식·참조·권한·전제 검증
        → 변경안 계산 → 변경안 위에서 미션 목표 평가
        → 미완료→완료 전이일 때만 완료 표시·답장·다음 단서를 같은 변경안에 추가
        → 일괄 적용 → events 반환 → UI 갱신 → 자동저장
```

미션 완료와 그 효과는 목표를 충족시킨 Action과 같은 커밋에 들어간다. 기존 완료 표시가 false이고 목표/제약이 충족된 전이에서만 완료 표시를 true로 바꾸고 답장·다음 단서·보상을 한 번 적용한다. 이후 조회·재회수·이미 완료된 저장의 복원은 효과를 다시 적용하지 않는다. 완료 표시도 지속 상태에 포함한다. 저장은 커밋 뒤에만 한다. 완료와 저장 사이에 종료되면 마지막 저장본에서 다시 시작하고, 목표는 현재 상태에서 다시 평가되므로 같은 결과에 도달한다.

P1의 `Action`은 `kind`, `session_id`, `args`로 시작하고 kind는 등록된 이름만 허용한다. 동시 창/실행 세대 구분이 필요한 P2부터 `run_id`, 낙관적 충돌 검사가 필요하면 `expected_revision`을 추가한다.
반환값은 `ok`, `error_code`, `message_key`, `output`, `events`, `revision`이다. UI 문구를 성공 판정에 사용하지 않는다.
파싱 오류·없는 참조·지원 밖 옵션으로 Action이 거절되면 WorldState·진행·관찰 기록을 바꾸지 않는다. 적용 전 대상·권한·전제를 확인하고 변경 실패는 부분 상태를 남기지 않는다.
유효한 서비스 요청의 `AUTH_DENIED`/접근 거부·HTTP 403은 정상적인 도메인 결과다. 응답·관찰·해당 경보 변화는 한 번에 기록한다. 로컬 입력 오류와 구분해야 경보가 오르지 않아야 할 오타에 벌을 주지 않는다.
변경안은 영향받는 객체의 사본에서 계산·검증한 뒤 한 번에 적용한다. 적용 구간에는 `await`, UI 콜백, 디스크 I/O를 넣지 않는다.
P1은 메인 스레드에서 Action을 순차 처리한다. 재진입하는 구독자가 생기는 P2부터 후속 Action 큐를 두며, 이벤트 구독자는 상태를 직접 변경하지 않는다.
이벤트는 `request_completed`, `file_changed`, `service_changed`, `evidence_added`, `goal_changed`, `tool_unlocked` 정도로 시작한다.
이벤트는 화면 통지와 관찰 기록이다. 모든 상태를 이벤트 재생으로 복원하는 이벤트 소싱은 도입하지 않는다.

### 캠페인 이월과 사건 스냅샷 — P2부터 다중 사건이 생길 때

새 사건은 불변 초기 번들에 검증된 `CampaignState.world_effects`와 발견 사실을 적용해 만든다. 자동 이월 대상은 완료·인물/서사 선택·발견한 대상/근거·회수한 개인 보관 자료·콘텐츠에 선언한 정책 효과다. 세션·작업 큐·임의 원격 파일 수정/삭제·사건 내 논리 시간은 자동 이월하지 않는다. 보존 자료는 ID·출처·내용 해시를 가진 게임 내 데이터이며 호스트 파일이 아니다.
콘텐츠 작성자는 다음 사건에 필요한 선택 효과를 허용된 Action/필드로 선언한다. 임의 스크립트나 전체 VFS 병합은 사용하지 않는다. 예를 들어 M05에서 선택 복구를 했다면 `portal_owner_check_fixed=true`와 해당 정책 효과를 이월해 후속 요청·대사가 이를 반영한다. 복구하지 않았으면 취약한 상태와 다른 후일담을 유지하며 스토리 완료를 취소하지 않는다.
P1은 완료·회수 자료·실제 경로와 후일담만 보존한다. P2부터 미션 완료의 판정·이월 효과·캠페인 기록·저장을 일관된 결과로 만들고, 학습 기록이 도입돼도 통과와는 별도로 보존한다. 재시작은 현재 사건만 되돌린다. 같은 서버 재방문은 이월 정책과 변경 이유를 명시해 조용히 초기화된 것처럼 보이지 않게 한다.

### 기본 스토리 모드의 Action 기반 경보와 결과 연출

P1은 동기 처리다. UI progress·타이핑·지연처럼 보이는 효과는 커밋된 결과의 연출이며 별도 작업 큐나 실제 대기를 요구하지 않는다.
기본 스토리 모드는 로컬 오타·허용된 파일 읽기·IME·창 조작에 risk를 부여하지 않는다. 반복 `AUTH_DENIED`/접근 거부 등 서비스 경계의 위험 행동만 해당 경보를 높인다. 경보는 미션 데이터 `alert_max`(기본 3)를 넘지 않는다.
임계 뒤에는 해당 비인증 경로를 제한하되 유효 세션·다른 허용 경로·체크포인트 재시도를 유지한다. wall-clock 사망 타이머는 없다. 구체적 수치와 회복 정책은 [DESIGN](../DESIGN.md)의 단일 정의를 따른다.
동일 초기 상태와 Action 순서는 같은 결과를 만든다. P2 이후 복습 변형에 랜덤이 필요할 때만 seed를 저장한다.
`pending_jobs`는 P2/MVP 이후 실제 비동기 서비스 효과가 필요한 미션이 생겼을 때 도입한다. 그때 due tick·대상·전제·실행 세대를 저장하고 완료 때 재검증하며, 취소/재시작/불러오기 후 이전 콜백을 무효화한다. UI 연출만으로는 도입하지 않는다.

## 4. 데이터 계약

### P1에서 구현할 부분집합

P1은 M01 한 건에 필요한 host/account/session(가상 암호 포함)·가상 파일과 `record_id`·회수 자료·현재 목표/대상 제약·`alert_max`·의뢰/후일담 텍스트·관찰 목록만 가진다. 명령 등록표와 최소 파서가 지원 기능을 제한한다. 웹 사본 경로를 택해도 완제품 브라우저가 아니라 내부 route/요청 부분만 추가한다.
현재 WorldState에서 목표와 제약을 매 Action 뒤 재평가한다. 관찰 두 개를 차례로 얻었다는 이유로 앞 관찰을 지우거나 revision 불일치로 무효화하지 않는다. 현재 권한/서비스 조건은 현재 상태로 확인한다.
저장은 `save_version`, `mission_id`, `world`, 완료/회수 자료/후일담 상태로 시작한다. 전체 schema·content hash·학습 분석·자동 migration을 선구현하지 않는다.
학습 안내/스킵 여부를 보관하더라도 통과 판정은 이를 읽지 않는다. 학습 진도와 캠페인 완료의 의미를 처음부터 분리하며 상세 루브릭은 구현하지 않는다.

### P3(MVP) 전체 참조 설계

아래 표와 JSON은 MVP 규모의 계약 참조다. P1 로더는 위 부분집합의 필수 필드·자료형·ID·경로·참조만 검증한다. 필요 없는 사이트·도구·번역·학습 필드를 빈 구조로 모두 채우게 하지 않는다.

ID는 안정적인 ASCII 문자열, 화면 이름은 별도 지역화 키다. ID는 저장 호환성과 참조용이며 번역하거나 표시 이름에서 생성하지 않는다.
JSON의 객체/배열/문자열/불리언과 문자열 키를 사용한다. Godot JSON 파싱은 숫자를 float로 읽으므로 정수 필드는 숫자 타입·유한성·소수부0·스키마 범위를 검사한 뒤 의미를 보존하는 int 정규화를 한다. 문자열/불리언/분수·범위 초과를 묵시 변환하지 않는다. 큰 식별자는 처음부터 문자열 ID로 둔다. 파싱된 TYPE_INT만 허용하는 검사나 저장 전후 원시 타입만 비교하는 방식은 사용하지 않는다. [Godot JSON](https://docs.godotengine.org/en/stable/classes/class_json.html)

| 계약 | MVP에서 해당 기능을 도입할 때의 필드와 의미 |
|---|---|
| HostDef | `id:string`, `address:string`(가상 주소), `account_ids:string[]`, `files:FileDef[]`, `services:ServiceDef[]` |
| FileDef | `path:string`(가상 절대 경로), `kind:file/dir`, `owner_id:string`, `group:string`, `mode:string`(세 자리 8진수), `content:string` 또는 서사 문서의 `content_key:string`, `record_id:string?`(목표 판정용 자료 ID, 복사·저장 경로가 바뀌어도 유지) |
| ServiceDef | `id:string`, `port:int`(1~65535), `protocol:ssh/http/https/ftp/db`, `enabled:bool`, `site_id:string?`, `policy:object`, `banner_key:string?` |
| DNSDef | `name:string`(`*.test`), `host_id:string`; 이름 해석과 호스트 도달 가능성을 별도 상태로 관리 |
| NetworkLink/FirewallRule | 출발/도착 host ID·활성 상태 / 우선순위·출발 범위·대상 port·allow/drop/reject; 실제 방화벽 API와 무관 |
| AccountDef | `id:string`, `host_id:string`, `groups:string[]`, `role:string`, `credential_ref:string`; 모두 가상 정보 |
| TerminalSession | `id`, `host_id`, `account_id`, `cwd`, `connection_stack`; 창마다 독립, 동일 서버 파일은 공유 |
| BrowserSession | `id`, `cookie_jars:object`, `history:array`, `cursor:int`; 앱 인스턴스마다 독립, 쿠키는 origin 단위 |
| AuthSession | `id`, `origin`, `account_id`, `issued_tick`, `expires_tick`, `revoked:bool`, `csrf_token`; 가상 토큰만 사용 |
| VirtualRequest | `id`, `origin`, `method`, `path`, `query`, `headers`, `body`, `browser_session_id`, `source_origin` |
| VirtualResponse | `request_id`, `status:int`, `headers:object`, `body_model:object`, `trace:array`, `evidence_tags:string[]` |
| SiteDef | `id`, `origin`, `host_id`, `routes:RouteDef[]`, `objects:object[]`, `policies:object`, `search_terms:string[]` |
| RouteDef/PageModel | method·경로 패턴·handler ID / 제목·본문 블록·링크·폼의 번역 키; HTML 문자열 실행/렌더 없음 |
| MissionDef | `id`, `initial_bundle_id`, `prerequisites`, `tool_unlocks`, `goals`, `alert_max:int`(1~3, 기본 3), `allowed_repairs`, `hint_ids`, `learning_checks`, `report_choices`; 학습 항목은 캠페인 통과 조건과 분리 |
| GoalDef | `id`, `kind`, `target`, `expected`, `evidence_policy:any_valid_evidence`; 최종 목표·정상 서비스·대상 제약을 평가하고 유효 근거 출처를 강제하지 않음 |
| CampaignState | 완료 미션·서사 분기·실제 풀이 경로 요약·발견 사실·보존한 player_artifacts·명시적 world_effects; 기술 사용 여부와 별도로 기록 |
| LearningState | 기술별 도입/연습/독립 확인/미평가·힌트 사용 단계·도구 소개·회고 응답; CampaignState와 별도 |
| SaveEnvelope | `save_version:int`, `schema_version:int`, `content_hash:string`, `slot_id:string`, `world:object`, `campaign:object`, `learning:object`, `settings_ref:object`, `ui_layout:object` |

가상 파일 경로는 `/` 기준으로 정규화하고 `.`·`..`를 처리한다. 가상 루트 밖으로 나가지 않으며 `res://`·`user://`·실제 절대 경로로 변환하지 않는다.
파일 읽기는 조상 디렉터리의 x와 파일 r, 디렉터리 열거는 r+x, 생성·삭제는 부모의 w+x를 확인한다. owner/group/other 세 범주로 시작한다.
심볼릭 링크·ACL·setuid·실제 프로세스·inode·마운트는 1.0 비지원이다. 이것이 실제 Linux 권한 전체 모델이라고 설명하지 않는다.
서비스 접근은 경로 도달→서비스 활성→프로토콜→계정 인증→객체 권한 순으로 평가하고, 실패 원인을 관찰 수준에 맞춰 구분한다.
포트 관찰은 경로/방화벽이 허용하고 서비스가 받으면 `open`, 도달하지만 서비스가 없거나 명시적 거절이면 `closed`, drop/차단으로 판단할 수 없으면 `filtered`다.
게임의 간소화 규칙을 도움말에 표시한다. 실제 스캔의 모든 네트워크 원인·추론을 재현했다고 주장하지 않는다.
진입 뒤 가상 세션의 접근 범위·권한·발견 정보를 통해 내부 노드로 이동하고 미션 목표를 달성한다. 복구 사건은 이후 최소 권한/정상 서비스를 확인한다. 특정 포트 번호만으로 침입시키지 않는다.
열린 포트는 서비스의 존재를 뜻한다. 올바른 자격 정보·허용 정책의 정상 연결과 취약한 설정을 이용한 접근은 서로 다른 근거로 기록한다.
초기는 HTTP와 SSH, 후속 미션에서 FTP의 익명/인증·가상 파일 접근, DB의 계정/바인딩/가상 query를 추가한다. 실제 FTP/DB 서버는 띄우지 않는다.
‘포트 개방’ 조치는 서비스 활성과 방화벽 허용을 각각 변경한다. 모든 포트 개방을 복구 정답으로 삼지 않고 필요한 서비스만 정상/비인가 경로로 검증한다.
브라우저 A의 로그인은 브라우저 B·터미널 curl에 자동 전파하지 않는다. 동일 앱의 탭을 나중에 추가하면 같은 쿠키 저장소 공유를 명시한다.
터미널 ssh는 가상 연결 스택을 쌓는다. 종료하면 이전 host/account/cwd로 복귀하며 다른 터미널의 계정은 바꾸지 않는다.
캠페인 Goal kind는 `state_assertion`, `request_assertion`, `service_available`, `target_constraint`처럼 유한하게 등록한다. 도구 사용·특정 입력·페이지 방문·설명 답안은 선택적 learning check이며 필수 완료 조건이 아니다.
미션 JSON에서 임의 식·스크립트·동적 클래스 경로를 받지 않는다. 두 미션 이상이 필요로 할 때만 새 kind를 추가한다.
콘텐츠 로더는 `goals`가 비어 있는 미션과 등록되지 않은 goal kind를 거절한다. 빈 목표 목록을 ‘완료’로 평가하거나 모르는 kind를 건너뛰면 미션이 즉시 완료될 수 있다. 콘텐츠에 적은 수치·문자열의 의미·단위·범위를 유지하며 `-1` 보정 같은 숨은 의미 변경을 두지 않는다. 앞서 정의한 JSON 숫자의 검증·의미 보존 타입 정규화는 허용한다.

### MVP 참조 JSON 예시: M05의 작은 콘텐츠 번들

아래는 **문법상 유효한 MVP 참조 예시**이며 P1 구현 체크리스트가 아니다. 안내 문장은 설명 편의상 직접 적었고 본편 서사/안내는 번역 키로 이동한다.
예시 ID는 이 블록 안에서 참조가 닫히도록 만들었다. 본편 데이터는 같은 계약을 hosts/sites/missions 등으로 분리한다.

이 JSON은 M05의 **선택 복구 연습용 변형**을 설명하는 계약 예시다. 캠페인 본 사건의 침투·조사 완료에 이 수정 경로를 강제하지 않는다.

```json
{
  "schema_version": 1,
  "bundle_id": "slice_m05",
  "accounts": [
    {"id": "alice", "host_id": "portal", "groups": ["users"], "role": "citizen", "credential_ref": "fixture_alice"},
    {"id": "bob", "host_id": "portal", "groups": ["users"], "role": "citizen", "credential_ref": "fixture_bob"}
  ],
  "credentials": [
    {"id": "fixture_alice", "kind": "scenario_login", "value": "training-alice"},
    {"id": "fixture_bob", "kind": "scenario_login", "value": "training-bob"}
  ],
  "hosts": [{
    "id": "portal", "address": "10.42.0.5", "account_ids": ["alice", "bob"],
    "files": [
      {"path": "/", "kind": "dir", "owner_id": "alice", "group": "users", "mode": "755", "content": ""},
      {"path": "/notice.txt", "kind": "file", "owner_id": "alice", "group": "users", "mode": "644", "content": "객체 소유자와 요청 계정을 비교하세요."}
    ],
    "services": [{"id": "portal_http", "port": 443, "protocol": "https", "enabled": true, "site_id": "citizen_portal", "policy": {}}]
  }],
  "dns": [{"name": "portal.test", "host_id": "portal"}],
  "sites": [{
    "id": "citizen_portal", "origin": "https://portal.test", "host_id": "portal",
    "routes": [
      {"method": "POST", "path": "/login", "handler": "scenario_login"},
      {"method": "GET", "path": "/records/:id", "handler": "record_by_id"}
    ],
    "objects": [{"id": "record_17", "owner_id": "alice", "body": "가상 신청 내역"}],
    "policies": {"object_authz": "authenticated_only"},
    "search_terms": ["시민 신청", "서비스 안내"]
  }],
  "tools": [{"id": "request_lab", "action_kinds": ["web_request"]}],
  "tutorials": [{"id": "authz_intro", "text": "로그인과 객체 접근 권한을 구분하세요."}],
  "missions": [{
    "id": "M05", "initial_bundle_id": "slice_m05", "prerequisites": [],
    "tool_unlocks": ["request_lab"], "hint_ids": ["authz_intro"],
    "allowed_repairs": [{"site_id": "citizen_portal", "policy": "object_authz", "values": ["owner_only"]}],
    "goals": [
      {"id": "deny_other", "kind": "request_assertion", "target": "citizen_portal", "expected": {"account_id": "bob", "object_id": "record_17", "status": 403}, "evidence_policy": "any_valid_evidence"},
      {"id": "keep_owner", "kind": "request_assertion", "target": "citizen_portal", "expected": {"account_id": "alice", "object_id": "record_17", "status": 200}, "evidence_policy": "any_valid_evidence"}
    ],
    "learning_checks": [],
    "report_choices": ["로그인 여부만 검사해 객체 소유권 검사가 빠졌다."]
  }]
}
```

콘텐츠 로딩은 필수 필드·자료형·중복 ID·알 수 없는 필드·enum·범위·경로·origin을 검사하고 오류의 파일/JSON 경로를 보고한다.
캠페인 goal에 `used_tool`·특정 입력 문자열·힌트 확인·pin 요구를 넣으면 계약 오류로 처리한다. 기술별 사용 확인은 learning_checks에만 둔다.
두 번째 패스에서 account→host, owner→account, service→site, DNS→host, goal→target, unlock→tool, hint→tutorial 참조를 모두 검사한다.
없는 참조를 빈 객체로 대체하거나 해당 목표를 건너뛰지 않는다. 개발 빌드는 번들 시작을 차단하고, 출시 빌드는 오류 안내 후 미션 선택으로 복귀한다.
순환 선수 미션, 동일 method+route 충돌, 다른 host 소유 계정, 불가능한 초기 경로, 지원되지 않는 기능만으로 풀어야 하는 목표도 검출한다.
validator 통과는 퍼즐 해결 가능성의 증명이 아니다. 정상 해결 재생과 실패/회귀 사례는 별도로 실행한다.

### 회수 자료의 정체성과 무결성

`record_id`는 신뢰된 콘텐츠가 선언한 불변 기록의 식별자다. 파일명·경로·UI 이름이나 플레이어가 편집한 본문에서 새 ID를 추측하지 않는다. 회수된 사본은 **목표 ID+해당 기록의 원본 데이터+허용 출처**를 유지해야 유효하다. ID만 같고 본문이 바뀐 사본, 다른 기록에 ID만 붙인 사본, 허용하지 않은 출처는 완료를 만들지 않는다.
P1의 작은 기록은 콘텐츠에 선언한 원본 데이터와 직접 값 비교해 충분하다. 별도 해시 엔진을 먼저 만들지 않는다. 웹 보관 사본은 같은 불변 기록과 허용 출처를 선언해 다른 유효 경로로 인정한다. 번역된 화면 문구와 기록 원본 데이터를 분리하며, 복사·파일명 충돌 처리도 ID와 원본 데이터·출처를 바꾸지 않는다.

## 5. 가상 브라우저와 내부 인터넷

주소는 URL 파서가 scheme·host·port·path·query·fragment로 나눈 뒤 내부 DNS와 SiteDef로만 전달한다.
지원 origin은 등록된 `http/https`의 `*.test`뿐이다. 사용자 정보 포함 URL, 임의 IP, 외부 host, `file:`·`javascript:` 등은 거절한다.
HTTPS 표시는 가상 보안 정책의 설명용이다. 실제 TLS·인증서·네트워크 스택을 구현했다는 의미가 아니다.
본문은 `RichTextLabel`의 텍스트/신뢰된 링크 메타데이터, 폼은 LineEdit·Button·OptionButton 등의 Control로 조립한다.
클릭한 링크는 `meta_clicked`에서 내부 URL 라우터로 보낸다. 공식 문서의 외부 브라우저 열기 예제를 그대로 사용하지 않는다. [Godot RichTextLabel](https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html#class-richtextlabel-signal-meta-clicked)
입력·가상 파일 내용·로그는 평문으로 렌더하고 BBCode로 해석하지 않는다. 스타일과 링크는 콘텐츠의 신뢰된 필드에서만 구성한다.
탐색 기록에는 URL과 페이지 조회 상태를 저장한다. 뒤로/앞으로는 GET을 재조회하고 POST 폼을 자동 재실행하지 않는다.
새로고침·재전송은 별도 Action이다. 폼 검증 메시지, redirect 최대 횟수, 404/403/서비스 중단 페이지도 같은 응답 계약을 사용한다.
검색은 발견/공개 상태의 SiteDef 제목·검색어·본문 색인을 조회한다. 검색 결과가 아직 알 수 없는 비밀 경로나 정답을 노출하지 않게 한다.
브라우저와 curl/RequestLab은 같은 VirtualRequest 처리기를 쓴다. 화면을 우회했다고 정책이 달라지지 않는다.
게임 입력 경로에서 `OS.execute`, `OS.create_process`, `OS.shell_open`, `HTTPRequest`, `HTTPClient`, 소켓·웹뷰 호출로 연결하지 않는다.
실제 파일 접근은 콘텐츠 로딩과 `user://` 저장 어댑터만 담당한다. 가상 wget·업로드는 실제 사용자 파일 선택기를 열지 않는다.

## 6. 리눅스 명령 부분 구현

아래는 전체 셸 호환이 아닌 **게임 안의 지원 계약**이다. 도움말에 지원 인자·예시·가상 범위를 표시한다.
P1은 M01 경로가 쓰는 `help`·`ssh`·`exit`·`ls`·`cd`·`pwd`·`cat`·`scp`만 등록한다. 아래 v0 표 전체는 P2 목표이며 P1 완료 목록이 아니다.
M01은 메일의 `guest` 계정으로 접속하고, 메모에서 찾은 정비 계정과 가상 암호로 다시 `ssh`한다. 두 계정 모두 같은 가상 서비스·인증·접근 검사를 거친다. 별도 `connect` 명령이나 자동 root 별칭은 등록하지 않는다.
v0 파서는 공백·단/쌍따옴표·제한된 이스케이프를 모든 명령에 같은 규칙으로 처리한다. 명령 이름은 대소문자를 구별하고, 별칭은 `command_registry.gd` 한 곳에서만 정의한다. 알 수 없는 옵션은 오류와 지원 도움말을 준다.

| 명령 | v0: 세 미션에 필요한 부분 | v1: 콘텐츠가 요구할 때 추가 | 비지원 경계 |
|---|---|---|---|
| help / man | 명령 목록, `help 명령`, `man 명령` | 해금 도구·관련 개념 링크 | 시스템 man 실행·외부 문서 다운로드 |
| ls / cd / pwd | 경로 하나, 상대/절대 이동, `ls -l` | `ls -a`, 복수 경로 | glob 확장·실제 홈·자동 마운트 |
| cat | 가상 텍스트 파일 하나 | 여러 파일 순서 출력 | 바이너리·디바이스·stdin 무한 읽기 |
| grep | 고정 문자열+파일, `-n` | `-i`, `-v`, `-F`, 파이프 입력 | 정규식·PCRE·셸 확장 |
| find | 미지원임을 명시 | 시작 경로와 `-name`의 제한된 `*` 패턴 | `-exec`·실제 디스크 탐색 |
| scp | 연결 중인 원격 host의 파일 하나를 로컬 `~/archive`(기본) 또는 지정 로컬 경로로 복사. 읽기 권한 검사, `record_id`·출처 유지, 같은 이름이 있으면 `이름(1)` 식으로 저장하고 알림 | 한 폴더의 `*` | 실제 SCP/SFTP·`-r`·원격→원격. 도움말에 실제 `scp user@host:경로 로컬경로` 형식과의 차이를 표시 |
| cp / mv | 미지원임을 명시 | 단일 파일 복사/이동, 권한 검사 | 재귀·장치간 이동·덮어쓰기 묵인 |
| mkdir / touch / rm | 미지원임을 명시 | 단일 디렉터리/빈 파일/파일 삭제 | `rm -rf`, 실제 파일 삭제 |
| chmod | 미지원임을 명시 | 세 자리 숫자 모드+가상 경로 | 기호 모드·재귀·ACL·setuid |
| ssh | `user@host`, 가상 암호 인증(입력 가림), 실패 시 `AUTH_DENIED`, `exit` | 가상 키 참조 인증·실패 로그 조회 | 실제 SSH·포트포워딩·호스트 키 시스템 |
| nmap | 단일 가상 host의 포트 상태, `-sV`의 작성된 서비스 배너 | `-p` 단일/쉼표 포트 목록 | CIDR·NSE·실제 패킷·OS 지문 |
| dig / ping / traceroute | `dig host` 내부 DNS 조회 | 제한 횟수 ping, 그래프 경로 traceroute | 외부 DNS·ICMP·실측 지연 |
| curl | URL, `-i`, `-X GET/POST`, `-H`, `-d` | 명시적 가상 cookie jar, 제한 redirect | 셸 치환·실제 TLS·임의 URL |
| wget | 미지원임을 명시 | URL 응답을 가상 cwd에 저장, `-O` | 실제 다운로드·재귀 수집 |

출력 결과는 표시 문자열과 별개인 `lines`, `records`, `evidence_refs`로 반환한다. 필요 이상으로 범용 스트림 추상화를 만들지 않는다.
v0 파이프는 지원하지 않는다. v1은 읽기 전용 출력에 `| grep` 한 단계를 연결하는 범위부터 만들고 양쪽을 먼저 검증한다.
리다이렉션, `&&`/`;`, 환경변수, command substitution, 백그라운드 작업, 실행 스크립트는 1.0 비지원이다.
Tab은 명령→지원 옵션→현재 세션에서 볼 수 있는 가상 경로/발견 host 순으로 후보를 제공한다. 다중 후보는 목록을 보여준다.
자동완성은 숨겨진 파일 내용·미발견 host·다른 계정의 비밀을 유출하지 않는다. 한글 IME 조합 중에는 후보 확정을 가로채지 않는다.
명령 이력은 터미널별로 분리한다. 인증 입력은 이력/스크린 로그에 남기지 않고 게임용 가상 암호임을 표시한다.

## 7. 도구는 같은 시뮬레이터를 보는 다른 조작면

| 도구 | 재사용하는 명령/코어 | 플레이어가 판단할 것 |
|---|---|---|
| NetProbe | nmap·dig·서비스/도달 가능성 조회 | 이름·경로·서비스 중 어디서 실패하는가 |
| RequestLab | curl·VirtualRequest 처리기 | 계정·객체·메서드·입력 하나를 바꾸면 무엇이 달라지는가 |
| AccessView | 파일 권한·객체 권한 평가 함수 | 인증과 인가, 정상 이용자와 타인 접근의 차이 |
| QueryProbe | 웹 query 모델·SQLi 분기 trace | 데이터가 조건 구조에 섞였는가, 수정 후 결과가 보존되는가 |
| LogLens | cat·grep·논리 tick 기준 로그 조회 | 관찰 순서와 원인 추정, 상관관계와 증거의 차이 |
| PacketLens | 가상 서비스가 생성한 request/response 기록 | 경로·요청·응답·세션 변화, 실제 pcap 분석은 아님 |
| CredAudit | 계정 정책·제한된 가상 인증 시도 | 재사용·잠금·추측 저항의 차이, 실제 크래킹은 아님 |
| TraceRoute / FileLens | traceroute / ls·cat·find·chmod | 연결 경로와 파일 권한이 후속 서비스에 미치는 영향 |

도구 버튼도 동일한 Action을 생성한다. 버튼 전용 정답 분기나 미션 완료 플래그를 두지 않는다.
미니게임을 추가한다면 대상·가설·관찰 결과 선택에 의미를 둔다. 클릭 성공으로 필요한 증거·정상 기능 검증을 생략하지 않는다.
스토리 해금은 새 도구의 소개·바로가기·안내를 제공한다. 지원 중인 기능을 이미 아는 사용자가 튜토리얼을 건너뛰고 쓰는 것은 막지 않으며 이전 명령/도구도 계속 조합할 수 있다.
기능을 잊었을 때 man과 사례를 다시 열 수 있다. 도구 레벨·수치 업그레이드가 개념 이해를 대신하지 않는다.

## 8. 웹 해킹을 어떤 수준으로 모사할 것인가

공통 원칙은 입력→처리 규칙→보호 경계→관찰 결과를 보여주는 것이다. 실제 JS·SQL·OS 명령은 실행하지 않는다.
취약점별 handler는 등록된 작은 처리 모델을 사용한다. 특정 정답 문자열 하나만 발견하면 성공시키지 않고 입력의 구조·맥락·정책 결과를 평가한다.

| 주제 | 구현할 상태/처리 모델 | 피드백과 일반화 한계 |
|---|---|---|
| IDOR | 계정, 객체 owner, 역할, endpoint 권한 정책 | 타인/소유자 요청 비교·403/200; 실제 프레임워크·복잡한 ABAC 전체는 아님 |
| 인증 | 가상 계정·자격 정보·실패 횟수·잠금·역할 | 로그인/실패/잠금과 자원 권한을 분리; 실제 암호 저장 구현 교육은 별도 |
| 세션 | origin별 쿠키·토큰·만료 tick·회전·폐기 | 재로그인/로그아웃/만료 후 요청 비교; 실제 브라우저의 모든 쿠키 규칙은 아님 |
| CSRF | source origin, 자동 쿠키 부착 규칙, SameSite 모드, 토큰 일치, 상태 변경 메서드 | 허용된 요청 전제와 차단 원인을 보여줌; 실제 navigation/브라우저 호환성 전체는 아님 |
| SQLi | 작은 조건식 문법, 문자열/비교/논리 연산 AST, 레코드 배열, 보간/매개변수 정책 | 입력이 데이터에서 조건식으로 바뀐 trace와 결과 집합; DB 엔진·전체 SQL·시간 기반 공격은 아님 |
| XSS | 입력 저장/반사 위치, 출력 context, escape 정책, 유한한 가상 script effect | 활성 컨텍스트와 평문 출력 차이를 표시; JS/DOM/CSP 엔진·모든 우회 문법은 아님 |
| 경로 순회 | 가상 문서 루트, URL decode 순서, 경로 정규화·경계 검사 | 요청 경로→정규 경로→허용/거절 trace; 실제 OS·심볼릭 링크는 아님 |
| 파일 업로드 | 가상 파일의 이름·형식·내용 분류·저장 위치·실행 가능 정책 | 확장자 검사와 처리 정책 차이; 실제 악성 파일·이미지 디코더는 아님 |
| 명령 주입 | 문자열 결합/인자 배열 정책, 제한 토큰 문법, 가상 허용 명령 효과 | 입력이 인자에서 추가 동작으로 바뀐 지점; 실제 셸·임의 명령은 아님 |
| SSRF | 가상 URL 대상, 서버 출발 위치, 내부/공개 서비스, redirect·egress 정책 | 사용자와 서버의 도달 범위 차이; 외부 HTTP·클라우드 메타데이터 접속은 아님 |

v0에는 IDOR와 SQLi의 필요한 모델만 구현한다. 다른 취약점 이름을 도움말에 넣었다는 이유로 지원 완료로 표시하지 않는다.
SQLi는 지원하는 소문법을 별도 명세하고 정상/동등 표현/지원 밖 표현을 fixture로 검증한다. 지원 밖 입력을 ‘안전한 공격’으로 오판하지 말고 범위 밖이라고 알린다.
XSS 가상 effect는 ‘피해자 화면 상태 변경’ 등 작성된 효과만 허용하고 플레이어 문자열을 `Expression`·eval·실제 코드 로더로 넘기지 않는다.
수정은 미션별 허용 정책 변경으로 표현한다. 예: 객체 소유자 검사, 매개변수 바인딩, 출력 인코딩, 경로 경계 검사, 내부 요청 제한.
종합 미션은 같은 모델을 연결한다. 새 주제마다 별도 세계 상태·별도 점수 엔진을 만들지 않는다.

## 9. 미션 판정과 선택 복습

캠페인 완료는 최종 목표 상태 AND 정상 서비스/대상 제약 AND `any_valid_evidence`로 평가한다. `used_tool`·특정 입력·힌트 확인·증거 pin·새 기술 사용을 필수 조건에 넣지 않는다.
P1은 회수 자료·대상과 관찰을 기록하고 현재 WorldState의 목표/제약을 재평가한다. 과거 성공 응답만으로 현재 권한/서비스 조건을 충족했다고 판정하지 않는다.
유효 근거는 목표와 관련된 요청 결과·로그·상태 조회·파일 관찰 등 어느 출처든 인정한다. 증거보드 pin은 정리 기능이며 자동 수집된 유효 관찰을 제출하려고 pin할 필요는 없다.
고정된 명령/도구/조사 순서를 강요하지 않는다. curl과 RequestLab의 동등한 요청, 로그와 파일 탐색의 동등한 단서 발견을 같은 의미의 근거로 평가한다.
위험 요청 거절만으로 성공하지 않는다. 서비스를 꺼서 모든 요청을 막았으면 정상 사용자의 성공 조건이 실패한다.
`allowed_repairs`는 구현된 정책 편집 범위를 제한하며 단일 정답 경로 목록이 아니다. 지원된 대안이 목표·대상 제약을 만족하면 통과한다. 임의의 전체 Linux 호환은 약속하지 않는다.
안내는 침투 흐름을 돕는 맥락 정보다. 퀴즈·원인 설명·분석 루브릭은 선택 복습이며 캠페인 통과 조건이 아니다. 새 기술을 쓰지 않고 해결해도 통과한다. P2의 간단한 기록이나 MVP의 상세 학습 기록을 도입하면 그 기술은 `not_assessed`로 남기고, 기록 기능이 없을 때 숙달을 추정해 표시하지 않는다.
튜토리얼·힌트·이미 아는 기능의 소개를 건너뛸 수 있다. 학습 체크 미충족이 캠페인 다음 사건이나 지원 기능 사용을 영구 잠그지 않는다.
서사와 회고는 커밋된 Action 효과의 풀이 경로 요약을 사용한다. 계정/시스템 경로로 해결한 사용자에게 고정 문구로 ‘SQLi를 사용했다’고 말하지 않는다.

### 관찰 보존 원칙과 고급 증거 추적의 도입 조건

P1부터 전역 revision 차이·연속 읽기·무관한 로그 추가·창 조작만으로 기존 관찰을 폐기하지 않는다. 관찰은 과거 사실로 보존하고 ‘현재 충족’은 지금의 목표/제약 평가로 확인한다. 같은 정책 상태에서 얻은 타인403과 소유자200 관찰도 서로 무효화하지 않는다.
`dependency_versions`·`claim_phase`는 P2/MVP 이후 여러 정책·세션·경로가 독립적으로 바뀌고 단순 현재 상태 재평가만으로 설명하기 어려운 사건이 생겼을 때만 도입한다. 관련 대상의 현재 조건 주장만 재검증하고 과거 침해 사실은 보존한다. 세부 버전 벡터/증거 엔진은 P1 필수가 아니다.

| 확장 계약 | 도입할 실제 필요 |
|---|---|
| 상세 LearningState/분석 루브릭 | MVP 이후 선택 복습의 힌트·재학습 기록을 제공할 때; 캠페인과 분리하고 재시작/저장에 기존 기록 보존 |
| 사건 간 world_effects/이월 | P2 이후 둘 이상의 사건·같은 서버 재방문에서 과거 선택을 실제로 반영할 때 |
| pending_jobs/실행 세대 | P2/MVP 이후 실제 비동기 효과·취소가 필요할 때; 결과 표시 progress만으로 도입하지 않음 |
| content_hash/호환표/migration | MVP 이후 배포한 콘텐츠/저장 버전이 여러 개 생겨 업그레이드 호환을 지원할 때 |

## 10. 저장·불러오기·재시작

P1부터 UI 장면/Node를 직렬화하지 않고 검증 가능한 값만 기록한다. `save_version`이 현재 지원 버전과 일치하는지 확인하며 불일치는 명시적 오류와 원본 보존으로 처리한다. 위치·크기는 선택적 편의 정보다.
저장 위치는 `user://saves/slot_01.json`, 임시 `.tmp`, 마지막 정상 `.bak`으로 고정하고 사용자 입력을 파일 경로에 붙이지 않는다.
저장 순서는 스냅샷 검증→tmp 쓰기·flush·닫기→다시 읽기/검증→현재 정상본의 backup 갱신→tmp를 본 파일로 교체다.
각 I/O 오류를 확인하고 기존 정상본을 먼저 삭제하지 않는다. rename 지원과 오류 반환은 Godot API에서 제공하지만 전원 차단 내구성은 플랫폼별 실험이 필요하다. [Godot 저장 안내](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html), [DirAccess rename](https://docs.godotengine.org/en/stable/classes/class_diraccess.html#class-diraccess-method-rename-absolute)
불러오기는 크기 상한·JSON·형식·범위·참조·미션/세션 불변식을 검증한 새 상태를 만든 뒤 한 번에 교체한다.
저장 왕복에서 S는 **스키마가 정의한 권위 있는 지속 상태의 값 스냅샷**이다. 계정/권한·가상 파일 원본 데이터와 ID/출처·현재 세션의 게임 ID/cwd·경보·완료 표시·회수 자료·답장/후일담·다음 단서를 포함한다. Node·UI 객체·콜백·실행 핸들·복원 때 새로 만드는 실행 세대는 재구성 대상이며 이 비교에서 제외한다.
`normalize(snapshot(load(save(S))))`를 저장 전에 독립적으로 준비한 기대 스냅샷과 깊은 값 비교한다. normalize는 위 스키마 검증과 의미 보존 숫자 정규화만 하며 필드 누락을 기본값으로 덮지 않는다. 테스트의 기대값을 저장기와 같은 필드 추출 함수로 만들면 양쪽에서 빠진 필드를 놓칠 수 있으므로, 비기본 중첩 값을 가진 독립 fixture로 누락·키 오타·중첩 변경을 검출한다. 새 지속 필드는 스키마와 기대 fixture에도 함께 반영한다. [Godot 저장 안내](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html), [Dictionary 값 비교](https://docs.godotengine.org/en/stable/classes/class_dictionary.html)
P1은 동기 처리이므로 pending job 복원이나 비동기 콜백 세대 관리가 없다. 실제 지연 효과를 도입하는 단계부터 저장된 작업만 새 실행 세대에 연결하고 이전 콜백을 무효화한다.
MVP 이후 호환 지원이 필요할 때 `schema_version`(콘텐츠 계약), `content_hash`(정렬된 콘텐츠 경로+바이트), 순차 migration/호환표를 추가한다. 빌드 버전과 저장 형식 번호를 혼용하지 않고 해시는 변경 감지용으로 사용한다.
호환 기능 도입 후에도 매핑 없는 저장의 원본·캠페인·학습 기록은 보존한다. 필요하면 사본 슬롯에서 사건을 새 번들+이월 효과로 재시작할 선택을 제공하고 미지원 자료/효과를 조용히 삭제하지 않는다.
손상 원본을 자동 덮어쓰거나 삭제하지 않는다. `.bak` 검증 성공 시 복구 후보를 보여주고, 둘 다 실패하면 새 슬롯으로 시작할 수 있다.
자동저장은 Action 커밋 후·미션 완료 후 실행한다. 저장 실패는 화면에 알리고 현재 메모리 진행을 유지한다.
P1 재시작은 사건 초기 상태/체크포인트에서 WorldState·해당 세션·사건 내 자료를 다시 구성한다. 설정·기존 완료·보존 기록을 지우지 않는다. P2 이후 이월 사실과 실제 도입한 학습 기록도 캠페인 수명으로 유지한다.
상세 LearningState가 도입돼도 재시작이 소개/힌트/시도 기록을 지우거나 기존 숙달을 낮추지 않는다. 디버그 재생은 일반 완료/학습 기록에 합치지 않는다.

## 11. 제안 파일 구조와 테스트 접점

아래는 최종 역할 지도다. P1은 한 사건에 필요한 파일만 만들고 room/브라우저 완제품/오디오/locale/고급 저장 기능은 해당 단계로 넘긴다. 단계별 생성 범위는 [ROADMAP_AND_QA.md](ROADMAP_AND_QA.md)를 따른다.

| 경로 | 책임 / 가장 작은 검증 접점 |
|---|---|
| `godot/project.godot` | 시작 장면·입력·임베드 설정·렌더러 / 실제 창 스파이크 |
| `godot/scenes/room.tscn` | 작은 Node3D 작업실·컴퓨터 상호작용 / OS 진입·복귀·입력 수명 |
| `godot/scenes/desktop.tscn` | Desktop·Taskbar·앱 생성 / 다중 창·포커스 수동 확인 |
| `godot/scenes/apps/*.tscn` | 터미널·브라우저·도구·메일·맵·증거 화면 / 각 앱 smoke |
| `godot/scripts/core/world_state.gd` | 유일한 실행 상태와 불변식 / 초기 상태·복사·세션 격리 |
| `godot/scripts/core/action_dispatcher.gd` | validate·변경안·커밋·event·논리 시간 / 실패 원자성·작업 무효화 |
| `godot/scripts/core/command_parser.gd` | 인용·옵션·지원 파이프 파싱 / 정상·오류·경계 입력 |
| `godot/scripts/core/command_registry.gd` | P1부터 등록 명령·지원 옵션만 실행 / 미등록 명령 거절 |
| `godot/scripts/core/virtual_fs.gd` | P1부터 가상 경로·권한·회수 자료 / 실제 host 경로 접근 차단 |
| `godot/scripts/core/commands/*.gd` | 파일/네트워크/웹 명령 핸들러 / UI와 무관한 입출력 fixture |
| `godot/scripts/core/virtual_web.gd` | 내부 URL·세션·route·request/response / 권한·라우팅·외부 주소 거절 |
| `godot/scripts/core/mission_evaluator.gd` | 유한 goal 평가·증거 유효성 / 다중 경로·거짓 완료 방지 |
| `godot/scripts/core/content_loader.gd` | 콘텐츠·참조 검증 / 누락·오타·충돌 fixture |
| `godot/scripts/core/save_store.gd` | 저장 어댑터·migration·복구 / 손상·write/rename 실패 주입 |
| `godot/scripts/apps/*.gd` | 화면 입력→Action / 공유 handler 호출·재렌더 |
| `godot/scripts/room/room_controller.gd` | 작업실 이동·컴퓨터 사용·입력 전환 / 터미널 단축키와 충돌 없음 |
| `godot/scripts/audio/audio_director.gd` | 버스 라우팅·음악 전환·설정 적용 / 중복 재생·mute·복귀 |
| `godot/data/{hosts,sites,missions,tools,tutorials}/` | 가상 세계·페이지·목표·도구·안내 JSON / 콘텐츠 검증 |
| `godot/locale/*.po`, `godot/locale/messages.pot` | 메시지 키·번역·문맥 / 누락·placeholder·지원 언어 검사 |
| `godot/default_bus_layout.tres`, `godot/audio/` | Master/Music/SFX/UI/Ambience와 음원 / export 포함·출처·음량 검사 |
| `godot/tests/headless/run_all.gd` | assert 기반 코어·콘텐츠·해결 재생 실행, 실패 시 비정상 종료 |
| `godot/tools/validate_content.gd` | 빌드 전 JSON 계약·교차 참조·콘텐츠 manifest 검증 |
| `tools/gate.sh` | P1 첫 제품 소스와 함께 도입할 콘텐츠 검증+실제 headless runner+지원 경계 검사 / 하나라도 누락·실패하면 merge 차단 |

역할 파일 수는 분리 필요가 생길 때 늘린다. 첫 시제품부터 범용 플러그인 시스템·추상 저장소·미션 DSL을 만들지 않는다.
P1 첫 제품 소스를 추가할 때 `tools/gate.sh`와 실제 검사 코드를 함께 만든다. 빈 성공 스크립트·누락 시 skip·grep만으로 경계가 증명됐다는 판정은 허용하지 않는다. 현재 문서 작업에서 gate 파일을 대신 만들지 않는다.
예정 headless 진입점은 `godot --headless --path godot --script res://tests/headless/run_all.gd`다. gate는 콘텐츠 검증과 이 runner의 비영 종료를 전달하고, 가상 URL/FS 경계 거절의 동적 사례와 외부 API 사용의 정적 검사를 함께 실행한다. [Godot CLI](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
P1은 M01 초기 미달→`guest` 거부→재접속→지정 자료 회수→후일담·재개, 실패 상태 불변·가상 host 경계·현재 목표 재평가·기록 ID+원본 데이터/출처 판정·완료 효과1회·학습/pin 비강제·세션 재열기·관찰 상호 보존·저장 왕복(deep-equal)/손상/쓰기 실패, 빈 goals·미등록 goal kind 거절을 검사한다.
P2부터 브라우저/curl/RequestLab 일치·다중 세션 격리·M05/M09 대안 풀이를 추가한다. M05 선택 복구의 타인403/소유자200과 M09 정상 검색 보존은 해당 선택 연습을 구현할 때 추가한다.
작업 큐·이월·상세 학습·호환표 회귀는 해당 기능의 도입 단계에서 추가한다. export 뒤 콘텐츠 포함 여부는 빌드 단계에서 별도로 확인한다.
headless 통과로 한글 IME·렌더·드래그·키보드 접근성·배포 실행을 입증하지 않는다. 실제 창과 설치형 산출물에서 확인한다.

## 12. 제작용 디버그와 구현 실패 조건

P1 디버그는 현재 사건 리셋·상태 조회·지원 경로 Action 재생부터 시작한다. 다중 사건 선택은 P2, 논리 tick 진행은 실제 tick 기반 기능을 도입할 때 추가한다. 별도 편집기는 만들지 않는다.
정답 재생은 실제 플레이 Action을 사용한다. 성공 플래그 직접 설정은 evaluator 테스트의 정상 해결 증거로 쓰지 않는다.
디버그 실행은 별도 저장 namespace와 `debug_run` 표시를 사용하고 출시 빌드에서는 정답 재생을 노출하지 않는다.
상태 조회는 계정·세션·정책·경로·목표별 실패 이유를 보여준다. 거대한 범용 인스펙터나 시각 미션 에디터는 만들지 않는다.
새 미션 제작 시간을 기록하고 동일 분기 복제가 반복되는 두 사례가 나타날 때만 공통 모델을 확장한다.

| 관찰된 실패 | 구현 결정 |
|---|---|
| 임베드 창의 IME/포커스/배율 결함이 스파이크에서 지속 | 앱 내용은 유지하고 Control 창틀로 전환 |
| 브라우저와 터미널 결과가 다르거나 한 창의 상태가 뒤처짐 | UI별 우회 변경 제거, 공유 dispatcher와 조회 경로 수정 |
| 세 미션에 임의 스크립트/전체 SQL/JS 실행이 필요해짐 | 미션 요구를 작은 상태 모델로 다시 표현, 실행 엔진 도입 보류 |
| 명령 문자열을 외워야만 완료되거나 정상 서비스 파괴로 통과 | goal·증거·정상 이용자 회귀 조건 수정 |
| 재시작/불러오기 후 이전 세션·지연 효과가 섞임 | run_id·참조·작업 수명 검증을 먼저 수정 |
| 손상 저장을 덮어쓰거나 검증 실패를 조용히 무시 | 콘텐츠 확대 중단, 저장 복구·실패 경로부터 수정 |
| 새 미션마다 코어 수정이 계속 필요 | 3미션 완주 후 계약 재검토, 24미션 일괄 제작 보류 |

## 13. 3D 작업실과 2D OS 전환

P2 graybox부터 검증하고 이후 미술/연출을 채운다. 아래 전환 계약은 P0/P1 필수 구현이 아니다.

작업실은 한 방의 분위기·인물 메시지·컴퓨터 사용 맥락을 제공한다. 핵심 과제는 전체화면 OS 안에서 수행하고 3D 화면의 작은 모니터에 글을 읽게 하지 않는다.
컴퓨터 상호작용→작업실 이동/시선 입력 중지→마우스 표시→Desktop 표시→직전 앱의 입력 포커스 복원의 순서로 전환한다.
OS 나가기→IME/모달 처리→앱 창 표시 상태 보관·숨김→Desktop 숨김→이동 입력/마우스 상태 복원으로 돌아간다. OS를 닫아도 미션/세션은 유지한다.
임베드 Window는 CanvasItem과 표시 수명이 다르므로 CanvasLayer 하나를 숨기는 것으로 처리하지 않는다. 앱 창 목록을 통해 개별 창도 숨기고 원래 최소화 여부대로 복원한다.
전역 SceneTree pause로 코어·UI를 함께 멈추지 않는다. 작업실 제어만 중지하고 게임 논리 시간은 앞서 정한 Action 규칙을 유지한다.
임베드 창의 layer 1024와 작업 표시줄·모달의 겹침을 스파이크에서 확인한다. 필요한 작은 UI 레이어만 그 위에 두고 전체 배경으로 창을 덮지 않는다. [Godot CanvasLayer](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html)
장면 재진입 때 WorldState를 새로 만들지 않는다. 입력이 터미널과 작업실에 동시에 도달하거나 숨긴 창이 입력을 받으면 전환 검증 실패다.
단순 조명·작은 자산·절제한 효과로 시작한다. 작업실 표현 때문에 OS 가독성·반응성·저사양 설치형 실행을 희생하지 않는다.

## 14. 다국어와 세 플랫폼

P0/P1은 번역 가능한 안정 ID/문자열 키의 접점만 둔다. P2에서 ko/en 문자열·폰트와 세 OS 초기 export smoke를 시험하고, P3 이후 실제 완주·번역 검수로 넓힌다.

MVP 목표 언어는 ko/en, 출시 목표는 ko/en/ja/zh-Hans/es/de다. 번역 준비와 해당 언어의 사람 검수를 구분하고 미완료 번역을 지원 완료로 표시하지 않는다.
Godot의 `TranslationServer`와 PO 파일을 사용한다. 제품의 `zh-Hans` 표기는 엔진의 locale 표준화 결과로 매핑하고 PO의 Language 값과 일치시킨다. [TranslationServer](https://docs.godotengine.org/en/stable/classes/class_translationserver.html), [Godot PO 안내](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_gettext.html)
서사·메일·도움말·오류·페이지 텍스트는 안정적인 메시지 키를 가진다. `{host}` 같은 이름 있는 placeholder와 번역 문맥을 유지하고 문자열 조각을 이어 문장을 만들지 않는다.
JSON의 번역 키는 장면/스크립트 자동 추출에만 기대지 않는다. 콘텐츠 검증기가 키 목록을 POT와 대조하고 누락·타입·placeholder 불일치를 차단한다.
명령명·가상 경로·host/객체 ID·기계 설정 값·미션 판정은 언어와 독립이다. 서사 파일의 표시 언어가 바뀌어도 의미 증거와 목표 ID는 바뀌지 않는다.
사용자가 입력한 값과 기계 로그는 자동 번역하지 않는다. 언어 변경 시 창·폼·메일을 다시 렌더하되 쿠키·명령 기록·월드 상태는 유지한다.
라틴 기본 글꼴에 한글·일본어·간체 중국어용 Font fallback을 둔다. 배포 글꼴 라이선스와 실제 글리프 포함을 확인한다. [Godot Font](https://docs.godotengine.org/en/stable/classes/class_font.html#class-font-property-fallbacks)
긴 독일어·스페인어 문장, CJK 줄바꿈·한글 IME·입력 커서·폰트 확대를 검사한다. 번역 키가 그대로 노출되거나 목표 문자열이 언어에 종속되면 실패다.
Windows/macOS/Linux는 같은 Godot 프로젝트를 별도 export한다. 각 플랫폼의 실제 실행·입력·저장·창 복원·오디오를 검증하며 한 플랫폼의 headless 통과를 세 플랫폼 지원 증거로 쓰지 않는다.
macOS 서명/공증, Windows 배포 경고·서명, Linux 배포 환경은 P5에서 각각 결정·확인한다.

## 15. OST·오디오·사용자 설정

P0/P1은 오디오 자산·버스 완제품을 요구하지 않는다. 버스/전환 구현은 재미를 확인한 P2 이후, MVP 오디오 3큐와 출시 OST 7큐는 별도 제작·검수 대상으로 둔다.

버스는 Master 아래 Music/SFX/UI/Ambience를 두고 이름을 고정한다. 플레이어는 범주별 음량과 mute를 조절한다. [Godot 오디오 버스](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html)
Music은 AudioStreamPlayer 두 개를 교대로 사용해 짧게 교차 전환한다. 작업실·조사·긴장·해결의 상태가 바뀔 때만 전환하고 요청마다 곡을 다시 시작하지 않는다.
전환 중 새 요청은 기존 fade를 정리한 뒤 새 목표 곡으로 수렴한다. 음량 설정은 사용자 bus gain과 트랙 fade gain을 분리해 적용한다.
UI 입력음·서비스 알림·환경음은 개별 이벤트로 재생하고 연속 입력 시 과도한 중첩을 제한한다. 음소거해도 모든 정보가 화면에 남아야 한다.
OST는 허용된 원본/라이선스 자산만 사용하고 출처·루프 지점·음량을 기록한다. 작곡·녹음·실제 음원 제작은 이번 문서 납품에 포함하지 않는다.
사용자 설정은 locale, 글자 배율, 창/화면 모드, 접근성, 버스별 음량/mute를 저장한다. 미션 리셋과 디버그 저장 격리에도 유지한다.
설정은 미션 상태와 수명을 분리한 `user://settings.cfg`에 저장한다. SaveEnvelope.settings_ref에는 형식 버전/참조만 두어 서로 다른 설정 사본이 경쟁하지 않게 한다.
설정 범위·유효 locale·음량을 검증하고 잘못된 필드만 기본값으로 복구한다. 실패한 저장으로 정상 설정을 먼저 지우지 않는 원칙은 미션 저장과 같다.
세 플랫폼에서 실행 직후/언어 변경/OS 복귀/미션 재시작/재기동 후 설정 유지, 음악 중복·클리핑·지연을 확인한다.

## 독립 검토 후 추가한 회귀 계약

P1부터 창 닫기/재열기는 동일 세션·cwd를 보존하고 exit만 해당 연결을 바꾼다. 학습 여부는 통과 판정과 분리하고, 연속 관찰·무관한 로그 추가가 기존 관찰을 무효화하지 않아야 한다. P2 이후 브라우저 쿠키/이력과 사건 간 선택 효과를 보존하며, 상세 학습을 도입하면 저장·재시작에도 기록을 유지한다. 정책 변경 뒤 현재 조건은 다시 평가하되 과거 관찰은 삭제하지 않는다.
