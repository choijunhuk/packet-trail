# 1.1 세 관점 확장 독립 QA

기반 `0565166`, 작업트리 `packet-trail-expansion/feat/three-perspectives`. 제품 구현과 분리한 QA 레인이다. 기존 runner/gate/CI/core/UI/data는 수정하지 않는다. 현재 독립 headless 회귀와 추가 리뷰 수리 검증은 통과했으며, 아래의 실행 시점·범위를 전체 제품 검증과 구별한다.

## 소유와 실행 경계

- `godot/tests/headless/test_mutation_limits.gd`: 기존 실제 action fixture를 통한 mutation/auth 및 headless UI 수명 회귀.
- `tools/test_mutation_limits.py`: 실제 Godot 실행의 외부120초 deadline, 종료코드·엔진 오류·고유 suite report를 검사한다.
- `godot/tests/headless/test_perspectives.gd`: 공개3팩/44사건·각2경로, 독립 부정/정상업무/관측·저장·결말 검증. mutation의 실제 API/IO 도우미를 상속해 재사용한다.
- `tools/test_perspectives.py`: 외부240초 deadline으로 실제 실행을 감싸며 정수 checks·엔진 오류/종료코드·44사건×2의 실제 완료88행·고유 경로ID·팩별 결말 기록을 fail-closed 검사한다.
- `godot/tools/inspect_package.gd`: 빈 별도 프로젝트에서 실제 PCK 로드·포함/제외 검증. 최종 source658ecf2의 macOS/Windows/Linux 실제 PCK 각각398검사 PASS다.

원본 `user://saves/{campaign_01,slot_01}.json`과 bak, `settings.json`/bak/tmp는 검사 전후 SHA256 또는 부재를 비교한다. 쓰기는 시간/인스턴스로 유일한 `user://tests/mutation_limits_*` 아래로 제한하고 자기 테스트 폴더만 정리한다. UI 검사는 private UI 메서드의 headless 기능 호출이며 native 렌더·물리 입력·장치 IME 증거가 아니다. 공개 도메인 상태는 실제 코어 API와 원본 fixture로만 바꾸며 완료/fact/session을 주입하지 않는다.

## 첫 RED — 실제 확인된 기존 결함

새 작업트리에 필요한 최초 Godot import 1회 뒤 아래 표적만 실행했다. 전체 gate/export/CI는 실행하지 않았다.

```sh
python3 tools/test_mutation_limits.py
```

결과: **RED, 1,148검사항목 중25실패**, Python wrapper 실행4.275초. Godot `4.7.stable.official.5b4e0cb0f`, headless. 로그 `.omx/artifacts/expansion-qa/mutation-first-red.log`.

| 회귀 | 첫 결과와 의미 |
|---|---|
| UI512자 이내 상대 경로5명령 | 최종1024초과 경로가 허용되어 저장/검증 실패. 변경 거절·원복 및 저장 가능성 기대가 RED |
| 완료 전/후 reset·저장·영수증 | 미완료 reset 저장은 정상. 완료 뒤 잘못된 영수증을 만든 후 reset 저장은 실패하여 회귀로 구별 |
| cp/mv/원본 보존 | 정상 remote→local cp, local mv와 canonical `handoff-47` 보존, remote 변경 거절은 PASS. empty rmdir 미지원은 RED |
| 디렉터리·공유 보관 예산 | mkdir516개가 전부 허용되어 초기4→520항목. bounded/saveable 한계·rmdir 회수·회수 후 archive는 RED |
| 모델 receipt 총량 | 큰 관측251개 수락 뒤 직렬화2,103,618바이트, 실제 `SAVE_SIZE_LIMIT`. 수락 상태가 저장 예산을 넘지 않는다는 기대 RED |
| M06/M23 일반 HTTP·근거 credit | 실제200/401/401/429·정상 쿠키·유효 replay는 PASS. 선행 exhibit 없이 fact/자료가 생기지 않아야 한다는 기대는 각각 RED |
| 역방향 창 순환 | 4개 창 중 help/term0만 반복하여 RED. 정방향은 전체 도달 |
| 크기 등록 수명 | 같은 상태40회 refresh에서312→1512, 해제 객체1245개가 남아 RED |
| 원본 저장/설정 보호 | 전후 지문 동일 PASS. 실패 시 기존 **고유 테스트 슬롯** 바이트 보존도 PASS |

이 숫자는 독립 사용 행동 수가 아니며 실제 오류·회귀 전제를 합친 assertion 수다. 원본 진단의 실패를 복사한 것이 아니라 추적되는 새 테스트로 다시 실행한 결과다. 모델의 정상업무·쿠키/제한은 살리고 근거 credit만 계약에 맞추어야 하며, validator를 완화해 통과시키지 않는다.

## UI 회귀 수정 확인

UI 소유자의 창 순환·등록 수명 수정 후 같은 표적을 한 번 재실행했다. 로그 `mutation-ui-fixed.log`: **1,148검사/22실패**이며 남은 실패는 코어 회귀다. UI의 양방향4창 전체 도달, 40회 refresh의 `sized 267→267 / dead0`, 기본 저장·설정 보존이 모두 PASS이고 엔진 오류0이다. 첫 RED25개 중 UI3개만 해결됐다는 범위로 기록하며 native 입력/렌더 PASS로 확대하지 않는다.

이후 테스트에는 archive/cp의 파일명 조합·mv의 상대 최종 경로 거절과 실제 손상 테스트 슬롯의 backup 복구·활성 상태/손상 원본 보존을 추가했다. 새 assertion의 실행 결과는 다음 코어 통합 표적에서 갱신한다.

## 기존 결함 묶음 GREEN

공통 코어 수정 뒤 **독립 재실행 1,217검사/0실패**, 외부 wrapper 11.660초, Script ERROR/Parse Error/ERROR 없음으로 통과했다. 로그 mutation-core-green.log. 최초 RED와 UI 수정 로그는 유지했다.

이 결과에는 최종 경로의 쓰기 전 거절/원복, 통합512 항목 예산과 필수 자료 공간 회수, 이전 유효512항목 snapshot의 관찰/삭제/저장/정상 완료, receipt 전체2MiB 예산, 손상 테스트 슬롯의 backup 복구와 원본 보존, 미완료/완료 후 reset·영수증, 일반 로그인 cookie/counter와 근거 credit·저장 replay의 분리, 양방향 창 순환/등록 수명이 포함된다. 구판512 fixture는 호환 신뢰 경계 입력이며 새 게임 해법/성취로 세지 않는다.

새 공개44사건·88경로와 새 세 모형·실제 확장 PCK는 아직 위 수치에 포함되지 않는다. 새 VM 공개 호출 그래프가 CALL의 target을 현재 함수명으로 덮는 표시 문제를 독립 소스 대조에서 발견해 구현 담당자에게 전달하고 공개 listing/graph 회귀를 추가했다. 그 수정 결과는 신규 모형 통합 실행에서 판정한다.

## 남은 통합 검증

### 공개·의미 통합 RED와 GREEN

perspectives-first-integration.log는 **10,940검사·88/88경로 완료행·7실패**, wrapper27.867초의 실제 RED다. M24의4개 assertion은 승인된 테스트 persona의 관측위치 대신 현재 operator 터미널을 HTTP service origin으로 사용한 제품 원인이었다. 정상/거절 응답만 맞는 것으로 다른 출발점의 실제 경로까지 검증했다고 읽지 않으며, 관측 origin과 현재 via/service 결과를 대조한다.

나머지 D06의3개 assertion은 QA observer가 승인된 desk 중계 세션을 버리고 local에서 직접 gateway로 접속한 harness 원인이었다. 기존 유효 완료 snapshot의 desk 경로를 유지하도록 QA만 교정했고 제품 via/권한/data 기대값은 열지 않았다. 이 최초 RED는 유지했다.

수정 뒤 perspectives-second-integration.log는 **GREEN 10,940검사/0실패·44사건88경로**, wrapper28.392초·실제 종료0·엔진 오류0으로 통과했다. Python wrapper는 정확한 팩/사건 집합마다 completed=true·고유route ID2개·양의 실제 action 수와 팩별 결말 기록까지 확인했다. 로그 SHA256은 df7443226d2aaca68fb162a3b7cc478620bb22b4668318f4977487ce03a860d6이다.

실행 전후 runtime/pack/test 32개 SHA는 perspectives-second-source.json과 모두 동일했다. 테스트 슬롯에는 PID도 넣어 병렬 프로세스 사이의 충돌을 피한다. 모든 기본 구판·신규팩·preferences와 sidecar 지문 보존 검사가 통과했다.

검증 내용은 실제 선수를 재생한 fresh88경로의 목표·canonical 자료/출처·정상업무·권한·관측·중간 저장→새 Game 재개→완료 저장, 각 팩의 모든 결말, 타편 잠금/진도 주입 거절, 이전판 원본 fork·최신 continuation 우선·손상 시 비fallback·원본/bak 보존·명시적 v1 import다. D06의 쓰기는 완료된 유효 상태의 별도 실제 SSH 관찰자로 파일 내용을 읽어 확인했다. M24는 qualified case ID별 실제 handler trace/actor/origin과 현재 service/via의 허용·불가, web/service의 정상·비인가 결과를 확인했다.

독립 의미 회귀는 class/expect 변경이 handler status/business를 만들지 못함, 과잉차단 실패·부분 rollback/폐기 세션 비부활, 공유 HTTP/VFS/실제권한·target-host cookie와 다른 호스트 동명계정의 비상속, 관측시점 assessment gate/나중 inspect 비승격/valid replay, 관측 사본 SHA·보정 시각·공유IP/client tag 불확실·hidden actor 불변·반증/새 관측·오답 시도 없이 handoff, VM 실제분기/호출·step/run 동등·입력/step/stack/memory 예산 원복을 포함한다.

새 VM CALL 표시, observation handoff의 before left/right 미대조, 첫 VM run의 비HALT 예산 소진 처리 세 문제는 구현 중 **소스 대조**로 발견해 소유자에게 전달했다. 이 세 건을 실행 RED였다고 주장하지 않으며 수리 후 위 독립 실행에서 회귀가 통과했다.

headless/core 표적의 최초 RED와 후속 GREEN 로그를 보존했다. root의 전체 gate/3OS CI/native/PCK/최종 ZIP 검증은 별도다. 의미 없는 action 순서 변경이나 challenge kind 수, assertion 수만으로 게임성 PASS를 만들지 않는다.

실제 PCK 검사는 새 공개44사건과 구판28사건 보존 정의를 별도로 확인하고, 6PO·7음악·16초상·폰트/고지/결말 로드 및 테스트/도구/해법/작성 자료 제외를 검사한다. 패키지 생성·PCK 읽기와 각 OS 제품 GUI 실행은 별개다.

## 데이터 PCK와 inspector 호출 계약

### 마지막 nested snapshot 후보의 좁은 진단

root 요청으로 ignored nested_snapshot_probe.gd를 각 외부10초 deadline으로 실행했다. 유효 D03 및 legacy M07의 tokens를 Array로 바꾼 입력은 모두 INVALID_SNAPSHOT·세계 불변·기본28경로 SHA 보존·Script ERROR0으로 거절돼 그 후보를 기각했다.

같은 유효 legacy session snapshot의 terminal0 원소를 int42 또는 빈 Dictionary로 바꾼 두 입력만 _session → _model_wire_context → validate_world의 Script ERROR를 출력했다. 최종 API는 두 경우 모두 INVALID_SNAPSHOT을 반환했고 세계·기본파일은 불변이며 timeout도 없었다. 따라서 저장 우회/손실/영구 불능으로 확대하지 않고 **Medium 입력검증 순서·오류처리**로 제한한다.

nested-snapshot-results-red.json 및 nested-terminal_*-red.log를 보존했고 소유 suite에는 재현된 terminal 두 형태만 좁혀 추가했다. 외부 wrapper의 엔진 오류 거절도 유지한다. token 구현 확대나 임의 fuzz framework는 추가하지 않았다.

Core가 기존 terminal stack/Dictionary shape 검사를 apply_world와 model context보다 앞으로 이동한 뒤, QA가 두 ignored probe를 **독립 재실행해 모두 GREEN**으로 확인했다. 각각 외부10초 안 실제 종료0·INVALID_SNAPSHOT·엔진 오류0·세계 불변·기본28경로 bytes 보존이다. nested-snapshot-results-green.json 및 nested-terminal_*-green.log를 보존했고 core/pack18개 시작/종료 SHA도 동일하다.

이후 Core 소유자의 같은 source 묶음 실행은 새 두 형태를 포함한 공개 wrapper **14,110검사/0실패·88경로**, 기존 campaign31,717/0과 first-playable336/0으로 통과했다. 이는 Core 실행 근거 /private/tmp/packet-terminal-shape-public.log를 전달받아 기록한 수치이며 QA의 앞선 독립14,004 실행과 구별한다. QA가 직접 재실행한 마지막 검증은 위 두 입력의 clean reject다.

### 추가 독립 리뷰 회귀 — 수정 전 RED

독립 리뷰의 D02 현재 정상업무 가용성, D04 취약상태 선관찰 후 보이는 회복/이력, foreign backup-only 및 tmp 정체성 보존, VM inspect 기본 폼을 새 회귀로 추가했다. review-regressions-red.log는 **11,223검사·88경로·38실패**, wrapper26.683초, 엔진 오류0의 실제 RED다. 시작 core/pack/fixture/test SHA는 review-red-source.json에 기록했고 종료 때 모두 동일했다. 제품 파일은 QA가 바꾸지 않았다.

실패 범주는 VM inspect selector1, D02 cached200/실제429 currentness1, D04 A/B의 retained event/public artifact/관찰먼저 정상회복6, foreign main/bak/tmp/bak.tmp의 저장·새시작·복구 정체성/경로·bytes30이다. 정상 로그인 관측은 별도 유효 snapshot의 실제 요청으로 429를 확인해 본래 historical200을 덮어 실패를 숨기지 않는다. 6개 sidecar layout의 각 저장2회/새시작/복구는 서로 다른 테스트 경로에서 독립 실행한다.

D04는 처음 raw execution flag를 취약 업로드 수락 당시 확인에만 쓰며, 회복 뒤에는 공개 artifacts의 current execution/격리와 accepted-at-upload 이력, artifact_events의 append-only prefix를 검증한다. B의 bounded quarantine와 정상사진 격리 시 업무 실패도 공개 artifact_id와 기본 action을 통해 검사하도록 준비했다. 후속 GREEN과 5회복사건의 실제 경로 대안 witness는 source/data 수리 뒤 별도 기록한다.

수리 뒤 같은 현재 Data 기준 review-regressions-green.log는 **11,228검사/0실패·88경로**, wrapper27.347초·종료0·엔진 오류0으로 통과했다. 새 공개 artifact/selector 때문에 기존에 조건부로 건너뛴5개 assertion도 실제 실행됐다. core/pack/fixture/test20 SHA는 시작/종료 동일했고 기대값은 완화하지 않았다.

### 5회복 사건의 실제 대안 witness

R2 Data 재생성 뒤 recovery-alternatives-integration.log는 **14,004검사/0실패·44사건88경로**, wrapper42.094초·종료0·엔진 오류0이다. recovery-alternatives-source.json의 core/pack/fixture/test20 SHA도 전후 동일하다.

M06/M07/M08/M12/M23의 각 A는 원제공자의 직접 보호를 실제 적용한다. 각 B는 그 A-only 정책이 실제 false인 채 원제공자에서 normal0·승인된 다른 제공자에서 실제 정상업무를 수행한다. 단순 다른 tool/HTTP 표면을 두 해법으로 세지 않았다. 각 A의 핵심 보호를 해제하거나 각 B의 격리한 원진입을 다시 열면 실제 direct_break_case가 허용되어서는 안 되는 status를 받고 current goal이 실패한다. 동시에 원래 선택한 정상 업무 route는 유지되고, 깨진 현재 상태와 이전의 유효 완료 영수증도 실제 저장 재개된다.

이 값은 새로운 독립 진입/대응·출처와 반례의 기계적 검증 범위이며, 사람의 재미·분량·학습 효과 측정으로 읽지 않는다. 소유 QA 코드는 root의 직렬 통합 검증용으로 고정했고, 추가 리뷰 수리 후 최종 새 PCK도 아래 범위로 따로 검사했다.

### 추가 리뷰 전 실제 데이터 PCK

기존 Godot --export-pack Linux 실행은 실제 종료0으로 68,469,132바이트 qa-data.pck를 만들었다. SHA256은 0c0808241e1fd7f2372e69e5cf8f80cc26e1cd71024037215f09d3955a244f51이다. 빈 임시 project에서 이 PCK만 mount한 inspector는 **398검사/0실패·실제 종료0·엔진 오류0·inventory177**로 통과했다. actual_public_counts는 intruder28/defender8/tracker8, legacy_case_count는28이다.

각 팩 정의/결말·6PO·7음악+ending edit·16초상·4폰트·15고지와 작성/테스트/해법 제외를 실제로 확인했다. 로그 export-data-pack.log/inspect-data-pack.log를 보존했다. 이 패킷은 추가 리뷰 수리 전 source 범위이며 최종 새 패킷 검증으로 전용하지 않는다. 이후 export/import/native는 root의 프로젝트별 직렬 통합 신호에 맞춘다.

추적 검사기 `godot/tools/inspect_package.gd`는 작성 및 Godot4.7 check-only 컴파일 PASS다. catalog/loader 계약에 따라 공개 intruder28·defender8·tracker8과 hidden legacy28을 구별하고 전체 packed 파일 경로의 테스트/해법/작성 자료 제외, 실제 리소스·각 팩 결말 번역을 검사한다. 첫 실제 PCK와 추가 리뷰 수리 후 최종3OS 패킷의 근거는 구분해 보존했다.

Godot4.7의 `--export-pack Linux <absolute.pck>`는 이 프로젝트의 표준 리소스 팩을 만들 때 바이너리 export template 없이 사용할 수 있다. CLI의 pack-only 분기는 `export_pack`으로 직접 가고 일반 executable export의 `can_export`/template 검사를 거치지 않는다. 기본 `export_pack`은 `save_pack`을 호출하며 Linux/PC exporter는 이를 override하지 않는다. 공식 버전 소스의 실행 경로와 위 실제 데이터 PCK 생성을 함께 확인했다. [공식 CLI 문서](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html#exporting), [pack-only 분기](https://github.com/godotengine/godot/blob/4.7-stable/editor/editor_node.cpp#L1268), [기본 export_pack](https://github.com/godotengine/godot/blob/4.7-stable/editor/export/editor_export_platform.cpp#L2280).

root/CI 호출 형태는 다음과 같다. 출력 부모 폴더와 빈 검사 프로젝트를 먼저 만들고, `REPO`, `PACK`, `EMPTY`는 절대 경로를 사용한다. Godot 문서상 상대 export 출력 경로는 현재 shell 디렉터리가 아닌 `project.godot`의 디렉터리 기준이다.

```sh
"$GODOT_BIN" --headless --path "$REPO/godot" --export-pack Linux "$PACK"
"$GODOT_BIN" --headless --path "$EMPTY" --script "$REPO/godot/tools/inspect_package.gd" -- "$PACK"
```

빈 `EMPTY/project.godot`는 최소 `config_version=5`면 된다. inspector는 source-game 장면/코어가 처음부터 보이면 실패시켜 source fallback에 의한 가짜 packed PASS를 막는다. inspector 스크립트는 export에 넣지 않고 source 파일의 절대 경로로 실행한다. 성공은 종료0·엔진 오류0·고유 `suite:packed_perspectives`의 양의 checks·빈 failures로 판정한다. 새 SDK/Action/template 설치는 이 데이터팩 경로의 요구사항이 아니다. 실제 실행 binary의 세OS export/서명/실행 검증은 별도다.

### 최종 source의 실제3OS PCK 독립검사

root의 최종 wholeGate/native44 통과 및3OS export 종료 뒤, commit `658ecf296f9151ad543703ee0fcaec70b082cffc`의 최종 PCK를 각각 별도의 빈 임시 프로젝트에서 검사했다. committed inspector는 변경하지 않았고 source import/export, 전체 gate, native GUI 또는 commit을 수행하지 않았다. 각 검사에는 외부90초 deadline을 적용했다.

| 실제 패킷 | 결과 | 시간 | 엔진 오류/경고 |
|---|---|---|---|
| macOS 앱 Resources/MidnightAccess.pck | 398검사/0실패, 종료0 | 0.901초 | 0/0 |
| Windows MidnightAccess.pck | 398검사/0실패, 종료0 | 0.888초 | 0/0 |
| Linux MidnightAccess.pck | 398검사/0실패, 종료0 | 0.881초 | 0/0 |

세 패킷 모두68,579,900바이트, SHA256 `fe8f781851feb9441d86c09662ebee5aab852abfa6f1719691bb4a499b4a4689`이며 검사 전후 동일하다. 고유 JSON report의 `actual_public_counts={intruder:28,defender:8,tracker:8}`·`legacy_case_count=28` 및 각 팩의 실제 ending을 확인했다. 실제 packed loader/catalog·6언어/ending 번역·7곡+ending edit·4폰트·16초상·15고지 로드와 packed inventory177의 테스트/도구/해법/작성 자료 제외가 모두 통과했다.

Godot 추적파일247개의 시작/종료 SHA, 기본 보호28경로와 전체 기존 saves 트리의 파일 목록/bytes도 모두 불변이다. 실행별 log/JSON, source/protected 전후 지문, 종합 pck-final-summary.json은 `.omx/artifacts/release-1.1/pck-final-*`에 보존했다. 추가 리뷰 전 qa-data.pck의398 PASS와 최종 패킷의398×3 PASS를 다른 source 범위로 기록한다.

독립 QA 소유 구현·회귀·최종 패킷 검증은 완료했다. 사람 플레이타임·재미·원어민 의미 검수·가청 품질·실물 OS/IME는 이 headless/PCK 회귀의 PASS 범위가 아니다. root의 native 전체44/3ending 검증과 서명·ZIP·CI·릴리스 판정도 각 별도 근거를 따른다.
