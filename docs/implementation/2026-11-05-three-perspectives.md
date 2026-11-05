# 심야접속 1.1 · 결함 수정과 세 관점 확장

상태: **통합 검증 중**. 이 문서는 구현 결정과 실제 실행 증거를 순서대로 보존한다. 최종 배포·수락은 마지막 완료 절에만 기록하며, 아래의 중간 GREEN을 전체 제품 완료로 해석하지 않는다.

## 실행 요청과 기준

사용자는 읽기 전용 감사 뒤 “수정 ㄱㄱ”, “게임성 더 높여주고 … 확장까지 계속 ㄱㄱ”라고 요청했다. 이어 나온 포기 관련 메시지는 다른 작업에 보낸 오입력이라고 명시적으로 철회했다. 따라서 게임의 수정·확장은 계속하며, 피드백·단계 승인 대기에서 멈추지 않는다.

- 기준: `0565166817a73fd073f2baaf6eabe5e0865249b6`.
- 작업: `packet-trail-expansion`, `feat/three-perspectives`.
- 목표 버전: `1.1.0-rc1`, Godot4.7/GDScript, 원래 비공개 저장소 유지.
- 실행 계약: [DESIGN](../../DESIGN.md), [코어 계약](three-perspectives-contract.md), [콘텐츠 재설계](campaign-redesign-brief.md).
- 감사 기준: [Claude 전체 읽기 전용 검사](../reviews/CLAUDE_FULL_AUDIT_20261105.md).

침투24+선택4는 유지하고 방어·추적은 각각 자기 온보딩·위기·종결을 갖는8사건으로 제작한다. 새두편의8이라는 수는 사용자의 원문 숫자가 아니라 이번 제작자가 정한 규모다. 공개44사건을 세 편으로 나눠 독립 진입하며 다른 편의 진도·학습 시험으로 잠그지 않는다. 침투8~12시간은 실측 전 설계 목표이며 세 편 합계로 바꾸지 않는다.

## 보존과 최소 구조

기존 VFS·Parser·Store·Runtime·가상OS·4터미널·3D작업실을 재사용한다. 외부OS 실행·실네트워크·VM·새 런타임 의존성·상시 공격AI·범용3진영 프레임워크는 추가하지 않는다.

기존 내용은 SHA256 `51699e38f77e1cf1caa01eaa2617587e9e668261c82373cb77d7ad5b0c74d9b8`의 `legacy_v1.json`으로 동결한다. 기존 생성자 첫save_path 인자와 legacy 기본 동작을 보존하고 새 UI는 선택pack을 명시한다. 구판 자료를 새 M24·분기·방어·추적 성취로 자동 변환하지 않는다.

| 편 | 정의 | 기본 쓰기 슬롯 |
|---|---|---|
| 개선 침투 | `packs/intruder_v2.json` | `intruder_v2_01.json` |
| 방어 | `packs/defender_v1.json` | `defender_01.json` |
| 추적 | `packs/tracker_v1.json` | `tracker_01.json` |
| 숨김 이전판 계속 | `legacy_v1.json` | `legacy_continue_01.json` |

원래 `campaign_01.json`과 `slot_01.json`은 고정 읽기 원본이다. continuation이 있으면 최신 사본을 우선하고, 손상 사본 대신 원본으로 몰래 돌아가지 않는다. 유효한 원본은 검증 후 별도 사본으로 이어가며 source/main/bak를 유지한다. 리소스·슬롯은 catalog allowlist이고 저장 헤더가 경로를 지정하지 않는다.

## 구현한 플레이 구조

- 새 침투편에서는 공통 exhibit66개에 붙은 필수5행동 체인을 제거한다. 필수 정보를 이름만 바꿔 다시 회수시키지 않는다. M24는 현재 웹·라우팅·서비스 범위, R01은 작은 실제 분기·CALL/RET 실행과 정상/반례 출력으로 판정한다.
- 방어의 `response_lab`은 실제 actor·정책·서비스·경로에서 정상/위협 요청과 업무 결과를 계산한다. 기대 class/status를 그대로 반환하지 않는다. 전체 차단은 정상 업무를 깨면 실패하고 부분 rollback은 폐기 세션·수집 이력을 부활시키지 않는다.
- 추적의 `observation_case`는 허가된 위치·시간 구간·출처의 수집 사본과 가설을 구분한다. 공개 관측만으로 지원/반박/부족을 평가하며 숨은 행위자 ID로 즉시 정답률을 주지 않는다.
- 세 새 모형은 기본 폼·선택·관측표·분기/호출 trace로 조작한다. 저자용 JSON을 기본 플레이 입력으로 요구하지 않는다. 같은 요청과 상태는 터미널·Browser·RequestLab·도구가 공유한다.
- 캠페인별 UI 인스턴스·저장·메모리 진행을 구분하고, 숨은 팩의 신호가 현재 음악/화면을 덮지 않게 한다.

## 처음 확인한 수정 회귀

| 묶음 | 실제 결과 |
|---|---|
| 수정 전 경계/인증/UI | mutation_limits 1,148항목/25FAIL, parse·Script ERROR0 |
| 역순환·등록 배열 수정 | 열린4창 양방향 도달,40갱신 sized267→267/dead0 |
| 공통 경계 수정 후 | 기존336, legacy31,717, mutation1,217 모두 실패0 |
| 공개팩 첫 통합 | 10,940항목/88경로에서7FAIL → 실제vantage 수리와 잘못된 관찰자 중계 재생 교정 뒤 실패0 |
| 강화 오디오 | 기존 RED123/28 → Audio147/0, ending edit 실제 one-shot 종료·재진입 검증 |

저장 경계는 최종경로1024·Campaign항목512·필수사본 여유·빈 로컬dir 제거·전체2MiB 후보 상태를 적용 전에 검사한다. 기존 v1의128 한도는 유지한다. 실제 인증·cookie·counter/cooldown과 보상 eligibility는 분리하고 행동 재생에서도 같은 의미를 보존한다. 엄격한 저장 검증을 완화해 통과시키지 않는다.

한국어의 사람용 교육 문단32회 잔류는0으로 교정했다. 명령·계정·주소·원자료 canonical 내용과 frozen legacy 정의는 그대로다. 언어 카탈로그 수치는 새 대안 원고의 최종 동결 뒤 확정한다.

## 오디오 적용과 신호 검증

검토용 강한 편곡을 실제 개발본에 반영했다.7곡+엔딩 편집,112~148BPM, 킥·스네어·베이스·arp·break/return을 갖는다. 기존 SFX12개는 바이트를 보존했다. [오디오 상세](audio-upgrade-20261105.md)에서 원본/변경 통계·생성기·SHA를 확인한다.

양끝25ms를0으로 누르는 방식 대신 순환 합성 길이를64sample로 정렬해 Vorbis tail padding을 제거하고, rain은 원본 샘플·스펙트럼을 보존하는 자연 phase 회전을 적용했다.1/2차 미분의 근방 분포와 짧은 RMS·실제 디코드로 검증했다. raw 끝/처음 한 샘플 차이만으로 click을 판정하지 않는다. 인간 청취·장시간 피로도는 자동 검사의 증거가 아니다.

## 실제 native 중간 결과와 실패 분리

새 smoke는 M01 실제1/44·9행동·3편 선택·D01/T01 기본 enum폼 보기·6locale1280large·15PNG·459검사항목/0FAIL,8.076초였다. 기본28경로 bytes와 제품33파일 SHA가 전후 같았다. 엔진 오류·경고·잔류0이다. 모델 Run과 나머지43사건·세 결말 GUI는 이 프로필의 NOT_RUN이다.

처음 popup 선택 실패는 helper가 PopupMenu 내부viewport에 Enter를 직접 주입해 Window의 `_input_from_window` 경로를 놓친 문제였다. embedder root에 실제 Enter를 주입해 id_pressed0/1/2와 popup 닫힘을 확인했다. metadata 기반 focus 선택은 setup API로 구분했고 버튼 activation 신호 직접 emit·실제OS 포인터 warp는 사용하지 않았다. 제품 picker를 바꿔 통과시키지 않았다.

첫 full은26/44·1,906검사/2FAIL로 중단했다. M01~M24·S01/S02와 response 기본폼 Run10회는 실제 통과했으나 R01 backend의 `inspect.section`이 공개 기본 폼에 없어 실패했다. 남은18사건·세 결말은 NOT_RUN으로 보존했다. 공개 폼과 backend를 정합시키며, tracker fixture의 backend 미소비 빈handoff 키32개도 제거했다. 이 제거는 목표·원고·팩 JSON을 바꾸지 않는다.

첫 전체 gate는3/336/81/31,717단계를 통과한 뒤 presentation의 res script를 한 번 열지 못했다. 물리 파일·권한은 정상이었고 같은 명령을 별도로 실행하면275/0이었다. 원인은 확정하지 않았다. 공식 export source는 source root가 아닌 EditorPaths tempdir에 tmpproject.binary를 만들고 pack에 `res://project.binary` 이름으로 추가한다. 따라서 export가 원본 script를 삭제했다는 가설은 기각한다. 공유 `.godot/exported`/import cache 가설만 남겨, 이후 Godot gate·native·export를 프로젝트별로 직렬 실행한다. 실패를 성공 로그로 교체하지 않는다.

## 추가 독립 검토와 수리 묶음

fresh `gpt-6.1-sol/xhigh` 독립 검토는 Critical0/Important4를 제시했다. 제안은 소스 도출이었고 별도 QA가 재현했다.

1. D02가 정상 계정의 현재 잠금을 보지 않고 과거200 영수증을 유지했다. 현재 정상 가용성과 역사적 실패 sequence 증거를 구분한다.
2. D04에서 취약 업로드를 먼저 관찰하면 정상 수리 뒤 숨은 stored execution flag가 완료를 막았다. 현재 실행 정책과 수락 당시 이력을 분리하고 보이는 artifact·개별 격리·정상 사진 보존으로 복구 가능하게 한다.
3. 침투 M06/M07/M08/M12/M23의 A/B는 같은 조건을 다른 표면으로 호출할 뿐이었다. 실제 다른 서비스/제어/경로로 같은 정상/위협 결과를 달성하는 대안을 보강한다. A-only booltrue 하나를 유일한 목표로 강제하지 않는다.
4. 다른 편의 정상 backup만 남은 슬롯에서 새 save/start/recover가 그 자료를 덮거나 손상본으로 분류할 수 있었다. main/bak/tmp/bak.tmp identity를 쓰기 전에 확인한다.

추가 실제 RED는11,223검사/38FAIL이었다. 처음 세 기능 수리와 VM 기본폼 정합 뒤11,228검사/88경로/0FAIL,27.347초·엔진0·소스20SHA 불변이었다. 콘텐츠5사건의 새 독립 대안은 다음 동결·실행 묶음에서 별도로 확인한다. C21 Opus5.5/xhigh 요청의 tools빈목록 읽기 전용 Core 검토도 병행하며 실제 응답 모델/성공 여부는 완료 후 기록한다.

## 재현 가능한 실제 PCK 검사

소스에 추적되는 `godot/tools/inspect_package.gd`와 CI를 추가했다. `--export-pack`은 Godot의 save_pack 경로를 사용해 실행 바이너리 템플릿 없이 리소스팩을 만든다. [공식 CLI](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html#exporting), [4.7 editor 분기](https://github.com/godotengine/godot/blob/4.7-stable/editor/editor_node.cpp#L1268).

```sh
godot --headless --path godot --export-pack Linux /absolute/output/MidnightAccess.pck
godot --headless --path /absolute/empty-project --script /absolute/repo/godot/tools/inspect_package.gd -- /absolute/output/MidnightAccess.pck
```

출력 부모 폴더는 미리 만들고 empty-project에는 최소project.godot만 둔다. 원본 프로젝트에서 검사해 빠진 리소스를 source에서 대신 읽는 경로는 거절한다. 현재 CI는 public28/8/8과legacy28을 실제 보고서에서 확인하고 Script ERROR/누락/0checks/실패를 건너뛰지 않는다.

추가 수리 **전** 데이터팩 표적은398항목/0FAIL·inventory177, 실제44+legacy28·6PO·7음악+edit·16초상·4font·15고지와 작성자료 제외를 확인했다. 이는 최종 새 소스/3OS 실행파일·GUI의 증거가 아니므로 최종 export 뒤 다시 검사한다.

## 마지막 코어·콘텐츠·UI 통합

다섯 복구 사건의 실제 대안은 `A`의 직접 보호를 켜는 해법과, 그 보호를 끈 상태에서 취약한 직접 경로를 제한하고 승인된 provider/gateway/processor/standby로 정상 업무를 살리는 `B`를 각각 실행했다. 각 대안의 고유 제어를 깨면 위협 결과와 현재 목표가 달라지고 정상 업무는 보존되는 반례도 검사했다. 이 묶음은14,004검사/88경로/0실패였다. 서로 다른 표면의 동일 정답만 검사한 결과로 표시하지 않는다.

이후 terminal snapshot의 첫 항목이 수·빈 Dictionary인 두 입력에서 거절은 됐지만 Script ERROR가 출력됐다. 기존 형식 검사를 모델 접근보다 앞으로 이동해 clean reject·세계/원본 보존을 확인했고, 공개 묶음은14,110/88/0으로 통과했다. 잘못된 tokens 배열 후보2개는 처음부터 정상 거절됐으므로 무관한 토큰 로직을 변경하지 않았다.

C21은 Core 정적 READY C0/I0, C22는 UI/콘텐츠 정적 REVISE C0/I2였다. 요청은 둘 다 Opus5.5/xhigh이며, 실제 사용 이력은 C21의5.5+4.8과 C22의5.5로 구분한다. 도구 없는 고정 source snapshot 검토이며 모델의 “재현” 표현을 실행 증거로 사용하지 않는다. [모델 기록](../AI_WORKFLOW.md)에 입력 범위·호출 조건·실제 결과를 남겼다.

C22의 활성 legacy 재입장과 과거 결말의 음악 고정, 추가로 실제 확인된 메뉴 Load의 미저장 상태 교체와 오래된 modal callback을 묶어 수리했다. UI 회귀는 실제 RED33/16에서GREEN37/0으로 바뀌었고, 기존 mutation1,217/0·sized267→267/dead0도 유지했다. 역사적 완료/결말과 현재 실행 상태·전경 음악 문맥을 분리했다.

마지막 번역 동결 뒤40개 Intruder 원문이 바뀌어 source revision gate가 실제 실패했다. 표현 정리15개는 의미를 유지하고, 안내·힌트·nonce·중립 인계문 등25개의 의미 수정은4번역에 반영했다. 키수2,574×6=15,444는 같고, 기준 SHA·PO를 다시 만들었다. 검사를 끄거나 새 hash만 맹목적으로 승인하지 않았다. Python27회귀와 실제 Godot6PO 로드·전환·보간 검사가 통과했다.

## 최종 전체 headless gate

첫 통합 `.omx/artifacts/integration-final.log`는 종료0,120.196초·Godot247SHA 불변이었다. 이후 정상 종료 수리와 CI preview 교정을 포함한 마지막 `.omx/artifacts/release-1.1-final/gate-final.log`는 **종료0,121.648초**였다. 기존249파일 SHA는 같고 editor가 새 종료 테스트의 UID2개를 생성해251파일이 됐다. 각 실행에서 source import/export/native를 병행하지 않았다.

| 범위 | 실제 결과 |
|---|---|
| content / 기존 첫 실행·저장 | 3 / 336, 실패0 |
| classic 콘텐츠 / 캠페인 | 81 / 31,717, 실패0 |
| presentation / 강화audio / UI문맥 / 초상 | 275 / 147 / 37 / 36, 실패0 |
| 저장·인증·창 회귀 | mutation1,217, 실패0 |
| 공개3편 | 14,110검사,44사건×2=88해법, 실패0 |
| 문서·번역·Python | 48문서/213로컬링크/17앵커/6JSON·6언어·Python48테스트 PASS |
| 정상 메뉴·창 종료 | 각각8 / 6검사·실제 종료0·마지막 로그까지 경고/오류0 |
| 실행 경계 | 검사기 자체5테스트와 runtime24스크립트, 오류0 |

검사항목 수에는 선수 사건 재생·반복 assert가 포함된다. 별개의 사용자 수·독립 퍼즐 수·실제 플레이 시간으로 바꾸지 않는다. 실제 렌더·OS·패키지·CI는 아래 최종 배포 절에서 별도로 기록한다.

## 최종 Mac 렌더·엔진 입력

R01의 기본 폼 누락을 고치고 마지막 번역/UI 문맥과 helper 기대값을 정합시킨 뒤, `native-full-final.log/.json`은 **5,390검사/0실패, 실제44사건·세 결말,85.728초**였다. 실제347fixture행동·47암호 입력 경로, 새 모형의 기본 폼 Run(response134/VM6/observation55),41PNG를 기록했다. 기본28경로 bytes/존재 상태와 제품33파일 SHA가 전후 같고 엔진 오류·경고·ObjectDB 잔류는0이다.

배포 직전 정상 종료 수리와 preview 교정까지 반영한 마지막 `native-full-release-final.log/.json`도 **5,390/0·44/44·세 결말,84.961초**였다.347행동·47암호·세 모형195회 Run·41PNG가 같고, 새 제품33SHA/보호28경로 불변·엔진 오류/경고/잔류0을 확인했다. 수리 전 PNG는 `full-before-shutdown/` 사본으로 보존하고 최신 `full/` 및 별도 실행 JSON/SHA를 남겼다.

이는 실제 M3 Max/OpenGL 렌더와 Godot InputEvent의 실행 근거다. 폼의 값·metadata 선택은 setup API, Run·새 진행·저장·확인은 엔진 입력으로 구분한다. 완료 flag를 주입하거나 BaseButton 신호를 직접 emit하지 않았다. GUI는 각 사건의 A경로를 완주했고 B경로는 headless에서 검증했다. [렌더 상세](perspectives-render-qa-20261105.md)가 보존·입력·음악의 정확한 범위를 설명한다.

부모는 실제 report의44/3·실패0·보호true·소스 SHA 동등을 다시 확인하고 대표8PNG를 육안 검토했다. 기존 smoke의 메뉴·도구 레이아웃을 기준으로 한 qualitative visual verdict는92/PASS였다. 외부 reference에 대한 pixel 일치나 사람의 재미 평가가 아니다. 큰 일본어/독일어의 조밀한 title/taskbar 축약, 언어 전환 전 출력된 console/toast 이력의 기존 언어 유지는 보이는 제한이다.

CUA는 문서 재로드 뒤 inventory 두 시도에서 native pipe startup failed/browser host unavailable을 반환했다. 따라서 이번 버전의 실제 OS 포인터·물리IME·오디오 장치 수락은 아직 NOT_RUN이다. 이 도구의 실패를 게임 실행 실패로 보거나, 엔진 입력 검증을 OS 조작 성공으로 대체하지 않는다.

## 배포 직전 추가 검증과 교정

첫 소스 `658ecf2`의 hosted CI에서 Windows/macOS는 전체 gate와 실제 PCK 검사까지 성공했다. Linux의 실제 renderer도458검사/0실패·M01 1/44·세 편 선택·15PNG·90.836초·기본 자료 불변이었다. 다만 D01에 새 quarantine 행동이 앞에 들어가면서 “첫 매개변수 행동”을 고르던 helper가 CI에서 요구한 `set_control` 대신 그것을 표시했다. CI는 이를 정상 거절했다. 제품이나 CI 조건을 바꾸지 않고 대표 공개 행동을 `set_control`/`collect`로 명시했고, 로컬 smoke는459/0·6.951초·동일 metadata 판정과 제품33SHA/보호28경로 불변으로 통과했다.

최종 Mac ZIP의 첫 외부 QA 명령은 release template에서 지원하지 않는 `--script`를 사용해 검사 스크립트가 실행되지 않았다. 실제 `--help`와 프로세스 stack/verbose로 정상 게임이 계속 실행됐음을 확인했다. 지원하는 `--write-movie`와 `--quit-after`로 실제 배포 바이너리의 메뉴·3D8PNG와 종료0을 확인했지만, 그 강제 종료에서 Ogg 자원 정리 경고도 관찰했다. 이 잘못된 검사 명령이나 종료0을 전체 성공으로 표시하지 않는다.

별도 source-engine 프로세스의 **실제 메뉴 버튼 Enter 활성화**에서도 같은8ObjectDB/2resources 경고가 재현됐다. 따라서 강제 CLI만의 문제로 기각하지 않고 메뉴 Quit·표준 WM close를 `FullGame.request_shutdown` 하나로 연결했다. 중복 요청을 막고 재생 중지→프레임 대기→stream 해제·Score 정리→짧은 drain→종료 순서로 처리한다. 특정 검사 CLI를 감지하는 제품 분기는 넣지 않았다.

수정 후 native 메뉴8/0·창 알림6/0, headless 두 경로도 같은 수치로 실제 종료0·마지막 로그까지 경고/오류0이었다. 창 테스트는 표준 WM notification을 두 번 전달한 기능 검사이며 물리 OS 창 닫기가 아니다. 실제 프로세스 종료 뒤에도 기본28경로 SHA가 같았다. Python 외부30초 deadline·실제 종료코드·마지막 stderr·단일 JSON·mode/stage·양수 checks를 확인하는 [종료 회귀](../../tools/test_shutdown.py)를 whole gate에 연결했다. source와 테스트 UID까지 동결한 뒤 재export하며 첫 미공개 ZIP은 `builds/provisional/658ecf2-1.1.0-rc1/`에 보존했다.

## 최종 완료 기록

진행 중: 전체gate·44native·읽기 전용 검토 후 수리는 통과했다. 실제 세OS export/PCK/서명/ZIP·서버SHA, main 반영·비공개릴리스는 후속 통합 단계다.

실측8~12시간·재미/난이도·원어민·물리IME/장치·장시간청취·Apple공증·Windows실물GUI는 실행 증거가 없으면 NOT_RUN으로 남긴다. 예정 기능과 실제 완료를 혼합하지 않는다.
