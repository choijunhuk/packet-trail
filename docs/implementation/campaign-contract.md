# 전체 캠페인 계약 v1

작업 경로 `/Users/choi/Documents/packet-trail-full`, 기반 `939bbcc`. 기존 M01 코어는 수정하지 않는다.

## 콘텐츠 번들

`res://data/campaign/campaign.json`은 `{schema_version:1, content_version:1, campaign_id:"midnight", start_mission:"M01", mission_order:[IDs], missions:{ID:Mission}, endings:[Ending]}`다.
Mission은 기존 M01 JSON의 `schema_version:1,mission_id,title,alert_max,initial_web_url,goal,goals,records,hosts,pages,mail`을 유지하고 `chapter:int, optional:bool, prerequisites:[ID], policies:{ID:value}, challenges:{ID:Challenge}, hints:[text_key]`를 추가한다.
`goal`은 `{record_id,destination:"/home/player/archive"}`, records는 `{ID:{content:canonical_payload,allowed_sources:[source],display_content_key?:key}}`다.
hosts는 기존 name/domain/address/accounts/files 구조에 `services:{"22":{protocol:"ssh",state:"open"}}, via:["local"|hostID]`를 추가한다. 기본 SSH는 명시적 22/open 서비스가 있어야 한다.
files는 기존 kind/owner/group/mode/content/record_id를 사용한다. source는 생략 시 `hostID:path`, 명시하면 records.allowed_sources에 일치해야 한다. 경로·계정·서비스·목표 참조를 검증한다.
pages는 내부 URL→`{title,body,links:[{label,url}],record_id?,source?,filename?,host_id?,challenge_id?}`다. query는 URL 본문과 분리하며 request/브라우저가 같은 handler를 사용한다.
`goals`의 등록 종류는 `record_acquired{record_id}`, `sources_preserved`, `fact{id}`, `policy{id,value}`, `session{host_id,account_id}`, `service{host_id,port,state}`다. 여러 목표는 AND이며 도구명/명령/퀴즈는 목표가 아니다.
Ending은 `{id,title,text,requires_facts:[factID]}`다. 기본 결말 하나는 requires_facts 빈 배열로 제공하고 최종 M24 뒤 선택한다.

## 표시와 무결성

title/name/goal_text/mail sender·subject·body/hints/tutorial/explain은 안정 문자열 키다. 표시 시 `TranslationServer.translate(key)`를 사용하며 키가 없으면 원문을 표시한다.
canonical content/record ID/source/URL/명령/계정/가상 암호/정답 토큰은 번역하지 않는다. `display_content_key`는 표시 전용이고 자료 무결성은 canonical content로 판정한다. locale별 JSON은 콘텐츠 제작 참고용이며 런타임 번역은 별도 .po 담당과 합친다.

## Challenge와 실제 행동 primitive

Challenge 공통은 `{kind,record_id,source,fact_id?,explain?,policy_id?}`다. 성공한 모델 결과는 canonical record를 회수하고 fact를 남긴다. 빈 입력/버튼 클릭만으로 성공시키지 않는다. 일반 파일/웹 사본 경로도 동일 목표에 도달할 수 있다.
`requires_facts:[ID]`, `requires_session:{host_id,account_id}`는 challenge/page에 선택적으로 둔다. records의 `grants_facts:[ID]`만 동일 canonical 자료의 다른 유효 회수 경로에도 적용한다. challenge.fact_id는 해당 모델의 후조건을 실제로 검증한 관찰에서 발급한다. 복구의 현재 policy 목표도 별도로 검사하므로 정책만 켜고 사본을 회수하는 것으로 차단/정상 검증을 우회하지 못한다.

| kind | 정의 필드 | use_tool params의 input |
|---|---|---|
| query | `parameter:"q"`, `policy_id?` | 작은 조건식/검색 문자열; 취약 정책에서 OR 동일값 비교를 구조적으로 처리 |
| render | `marker:string`, `policy_id?` | `signal:marker` 가상 표시 동작. JS 실행 없음 |
| path | `base_path:string,target_path:string,policy_id?` | 상대 경로를 정규화해 target_path에 도달하는 입력 |
| exec | `marker:string,policy_id?,run_as?:accountID` | `diagnose;inspect:marker`의 등록된 두 가상 작업과 인자 배열 정책을 비교; caller와 service execution account/groups를 구분, 추가/파괴 작업·OS 실행 없음 |
| fetch | `target_url:string,policy_id?` | 등록된 내부 target_url; 실제 네트워크 요청 없음 |
| permission | `group:string,host_id:string,account_id:string` | 노출된 group 이름. 해당 계정 세션에서만 허용 |
| audit | `encoded:Array[int],xor_key:int` | 주어진 가상 바이트를 xor로 해독한 문자열 |
| reverse | `encoded:Array[int],xor_key:int` | 바이트/문자열 실행 흐름의 계산 결과 |
| memory | `buffer_size:int,flag_offset:int,expected_byte:int,memory_size:int` | hex byte 문자열; 제한된 가상 메모리에 쓰고 flag 위치의 값을 확인 |
| packet | `rows:Array[Dictionary],field:string,value:string` | `field=value` 필터로 실제 rows의 관련 패킷을 선택 |
| trace | `rows:Array[Dictionary],field:string,value:string` | `field=value`로 실제 로그/경로 기록을 연결 |
| compare | `left:string,right:string` | `{left:값,right:값}` 또는 `left|right`; 두 관찰의 지정 차이를 확인 |
| token | `token:string` | 승인된 허구 토큰 값; 실제 자격 정보 사용 없음 |
| policy | `policy_id:string,values:Array` | 허용 값 하나. 정책 변경은 goals와 현재 서비스 상태로 재평가 |
| idor | `host_id,objects:{ID:{owner,record_id,source?}},policy_id` | `{object_id}`; 현재 인증 계정과 객체 owner, enforce-owner 정책으로 응답 결정 |
| auth | `host_id,account_id,policy_id,limit:2,cooldown:2` | `{action:login,username,password}` 또는 `{action:wait,username?,ticks:2}`; 계정별 반복 실패 차단→논리 대기→정상 로그인 성공 쌍 |
| session | `host_id,account_id,stale_token,policy_id` | `{action:issue/reuse/revoke,token?}`; 발급/폐기 상태, stale 거절과 새 토큰 성공 쌍 |
| csrf | `origin,csrf_token,policy_id` | `{origin,token,value}`; 상태 변경의 origin/토큰 검사, 차단/정상 변경 쌍 |
| upload | `policy_id` | `{filename,mime,signature}`; jpg/jpeg·image/jpeg·JPEG 조합과 실행 불가, 가짜 차단/정상 허용 쌍 |

request(method,url,body,headers)는 page.challenge_id가 있으면 body/query의 `input`(또는 challenge.parameter)을 같은 Challenge 모델에 전달한다. 성공 결과는 자료/근거를 회수한다. POST `/login`은 `{username,password}`로 해당 host 가상 웹 인증을 처리한다.
정책의 초기 취약 값은 `false`, 수정 값은 `true`를 기본으로 하며 policy challenge values에서 명시한 값도 허용한다. 모델의 policy_id가 true면 취약 동작을 막는다.

## API와 UI 읽기 모델

`CampaignGame.new(save_path="user://saves/campaign_01.json")`.
`execute(line,terminal_id=0)`, `submit_password(pw,terminal_id=0)`, `cancel_authentication(terminal_id=0)`, `get_view(terminal_id=0)`, `autocomplete(input,terminal_id=0)`.
`browse(url)`, `collect_web(url)`, `request(method,url,body={},headers={},terminal_id=0)`, `use_tool(tool_id,params={})`, `choose_mission(id)`, `advance()`, `choose_ending(choice)`.
`save_game/load_game/recover_save/start_new_save/export_snapshot/restore_snapshot`와 명시적 `import_m01(raw)`를 제공한다. 공통 반환은 기존 `{ok,code,text,changed,needs_password,event}`와 호환된다.
get_view는 기존 필드 전부와 `mission_id,missions:[{id,title,chapter,optional,available,completed}],tools:[{id,name,description}],hints:[text],hint_level,terminal_id,terminals,policies,facts,can_advance,endings:[{id,title,available}],ending`을 추가한다. `get_hint(level)`은 0~2 안내 표시만 바꾸며 통과 조건이 아니다.
터미널은 0~3의 독립 연결 스택·cwd·인증 입력을 가진다. 닫기는 보기만 닫는다. 파일·정책·자료·웹 세션은 동일 권위 세계를 사용한다.
지원 명령은 기존8개+man/whoami/id/grep/find/mkdir/cp/mv/rm/nmap(scan)/dig/ping/traceroute/route(pivot)/curl/wget/sudo -l/strings/xxd/decode/configure/tool이다. `tool challengeID '입력 또는 JSON'`과 `configure policyID true`를 제공한다. 파이프·eval·OS 실행은 지원하지 않는다.

## 저장과 검증

저장은 정확히 save_version(2), campaign_id,content_version,current_mission,current_world,completed,mission_states,decisions,ending의 9개 필드다. mission_states는 완료 당시 유효 상태 영수증/미완료 체크포인트이고 current_world는 현재 재방문·재시도 상태다. pending 암호·GUI 객체는 저장하지 않는다. 기존 v1 M01 저장은 자동 덮어쓰지 않고 import_m01에서 기존 Game의 검증 후 명시적으로 가져온다.
자료 본문·ID·출처, 파일 구조/계정/세션 경로, 정책 허용값·fact 출처, 목표/완료 일치와 선수 관계를 검사한 뒤 한 번에 적용한다. Store의 tmp/bak/손상 원본 보존 동작을 그대로 사용한다.
솔루션 fixture는 각 미션에 paths 배열을 두고 `{kind:"command",line,terminal_id?}`, `{kind:"password",value,terminal_id?}`, `{kind:"browse",url}`, `{kind:"collect_web",url}`, `{kind:"request",method,url,body?,headers?}`, `{kind:"tool",tool_id,params}` action을 사용한다.
콘텐츠·UI·테스트와의 계약 변경은 먼저 공유한다. 전체 gate는 root 통합 묶음에서 실행하며 기존 336 회귀를 유지한다.

## UI 통합과 저장 수명

campaign_desktop은 `@export save_slot_path`를 두고 CampaignGame 생성자에 정확히 전달한다. 테스트는 고유 user://tests/ 경로를 주입한다.
start_session(new)은 확인 뒤 새 CampaignGame(save_slot_path)의 초기 진행을 save_game으로 기록한다. 정상 기존 v2 슬롯은 Store의 검증된 bak 후 교체하며 기존 v1 슬롯은 유지한다.
continue는 이미 활성화된 UI의 메모리를 resume하고 첫 진입만 load_game 한다. load는 명시적 디스크 재읽기다. 손상 load는 정상 새 상태처럼 autosave하지 않고 recover_save 또는 손상 원본 보존 start_new_save의 선택을 표시한다.
`import_legacy_save()`만 고정 user://saves/slot_01.json을 읽어 기존 Game 검증 후 import_m01을 호출한다. UI가 FileAccess를 직접 사용하지 않는다. 원본 v1에는 쓰지 않고 새 v2 디스크 저장은 별도 명시적 save다.
`get_save_status()`는 검증된 저장 경로에서 `{exists,valid,backup_available,legacy_available}`만 반환한다. 허용 밖 경로이면 파일 stat/읽기를 하지 않는다. legacy_available은 고정 v1 파일의 실제 검증 결과다.
`get_view().characters`는 이미 만난 C01(M01)/C02(M02)/C03(M09)/C04(M15)에 한해 `{id,name,face_revealed,can_reveal,expression}`를 제공한다. C01은 M12, C03은 M16 완료 후 reveal_contact(id)의 명시적 선택으로 얼굴을 공개한다. C02는 소개 후, C04는 M20 완료 후 자동 공개다. decisions의 허용 키는 ending/reveal:C01/reveal:C03이며 공개 선수 완료를 저장 복원 때도 검증한다. 이 선택은 목표·권한과 무관하다.
tools.id는 challengeID, kind는 모델 종류다. use_tool(challengeID,{input}) 또는 use_tool(alias,{challenge_id,input})를 지원한다. typed 필드가 직접 params에 있으면 input Dictionary로 처리한다. input_schema는 문자열 필드 목록이며 data에는 rows/encoded/xor_key/buffer_size/memory_size/base_path/origin 등 공개 관찰 정보만 제공한다.
공용 netprobe(scan/target), traceroute(route/target), filelens(file/path), loglens(log/path)도 tools에 포함한다. 이들의 data 후보는 이미 발견된 network와 현재 계정이 열람 가능한 cwd 목록뿐이다. 모든 use_tool은 params.terminal_id(생략 시 0)를 명시적으로 선택한다. get_view(0~3)는 현재 명령/인증 주체와 지속 세계를 바꾸지 않는 읽기다.
request 응답은 기존 browse fields에 status/headers/text/changed/trace/actor/source_origin/route/cookie_preview를 더한다. 도메인 차단 관찰은 ok:true+status403/415/429이고, 입력/권한 전제 실패는 ok:false다. HTTP actor는 유효 웹 세션의 계정이며 실제 외부 통신은 없다.
request/curl의 RequestLab 컨텍스트는 해당 host의 현재 SSH 계정을 actor_context:terminal로 명시해 실험할 수 있고, browse는 actor_context:web로 실제 웹 세션만 사용한다. SSH에서 로그인했다고 브라우저 쿠키가 생성되지는 않는다. Origin 헤더가 있으면 CSRF 본문의 origin 주장보다 우선한다. 업로드 정상 생성은 status201이다.
request의 다섯 번째 terminal_id는 기본0이고 명시 검증/선택한다. 브라우저 컨텍스트는 로컬 출발, RequestLab/원격 curl은 지정한 터미널의 실제 연결 호스트에서 출발한다. invalid ID/구조/실패 요청은 선택 이전 상태를 보존하고 자동완성도 지속 세계·현재 주체를 바꾸지 않는다.
일반 /login과 인증 모형은 계정별 실패/차단/회복 상태를 공유한다. 관리형 웹 토큰은 발급 기록과 현재 철회/논리 만료를 확인한 뒤에만 주체로 사용한다. 원격 chmod는 지원하지 않으므로 저장의 원격 mode를 포함한 원본 메타데이터도 변경할 수 없다.
업로드 보호를 잠깐 껐을 때 실행 가능 상태가 남으면 과거 완료 근거를 보존하되 현재 안전 목표는 미충족이다. 보호를 켜는 것만으로 이미 저장된 위험 파일이 사라졌다고 주장하지 않고, 정상/차단 재검증으로 실행 금지 상태를 확인한다.
model_states는 model_actions의 입력/당시 정책/행동 주체를 재계산한 결과와 비교한다. 사실과 완료 표시는 모델 후조건·canonical 자료·현재 목표로 다시 계산한다. 암호 입력 대기는 저장하지 않으며, 모델 관찰에 들어가는 자격 값은 작성된 허구 실습 계정의 값뿐이다.
완료 시점에 보존한 유효 mission_states/_completed는 재방문 실험과 분리한다. view.completion_recorded와 can_advance는 과거 완료 영수증, view.current_goals_met와 completed는 현재 재검증 상태다. 현재 정책을 깨뜨린 상태를 새 안전 상태라고 안내하지 않으며 ‘완료기록으로 계속’은 이전 사건 완료를 사용한다. 저장 9키는 바꾸지 않는다.
