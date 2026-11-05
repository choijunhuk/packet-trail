# 전체 게임 읽기 전용 Claude 검사 · 2026-11-05

**최종 판정: REVISE.** Claude 원문은 Critical0·Important6을 제시했다. 소스 대조와 격리 재현으로 재판정한 우선 항목은 **Important3·Medium3**, 추가 재현한 UI 경미 결함2개다. 기존 자동 검사 통과와 현재 미해결 결함을 구분한다. 이번 과제에서는 **게임 코드·콘텐츠·음원·앱·저장·설정·릴리스를 수정하지 않았다.** 부모가 이 보고서·README·모델 기록만 작성한다. OST 강화본은 별도 검토용 산출물이다.

## 사용자 요청과 검사 범위

요청: “게임 ost가 너무 잔잔하다 그리고 클로드한테 전체 검사 시켜봐 코드 바꾸진 말게 하고”. 기준은 `main a70e3bcc15bb56c2e9719db9fc0eeaf33dc3ea46`, 실행판은 `1.0.0-rc1`이다.

Claude에 실행 소스·설정55개를 빠짐없이 세 분야에 배정해 전달했다. 실제 캠페인 JSON·28사건/56경로 fixture·KO/EN 서사·관련 계약/기획·제작/검증/패키징/CI도 포함했다. 전체 tracked260파일의 SHA256 인벤토리와 검토 전후 원본 해시를 보존했다. 코드 제공 범위와 정독/경로 추적 깊이는 별개다. 코어 응답은 56경로 구조를 읽고 그중6사건을 단계별 대조했다고 명시했으며, 레거시 UI는 가볍게 검토했다고 밝혔다.

6개 PO와 음원·폰트·초상 바이너리는 인벤토리/검사 코드의 대상이며, Claude가 원어민 원문 전수 교정·실제 청취·실제 게임 실행을 했다는 뜻이 아니다. 8~12시간과 재미도 실측하지 않았다. Claude가 못 받은 인접 파일은 부모/독립 검토자가 대조했다.

## 수정 금지를 강제한 방법과 실제 모델

로컬 `Claude Code2.1.311`의 `--print --tools "" --safe-mode --restricted --strict-mcp-config --mcp-config '{"mcpServers":{}}' --permission-mode dontAsk --permission-prompts none --disable-slash-commands --no-chrome --no-session-persistence --output-format json`을 사용했다. 파일 읽기·편집·명령 실행·MCP 도구가 없는 상태에서 동결된 본문만 stdin으로 전달했다. 전역 설정/인증은 바꾸지 않았다.

| ID·분야 | 요청 모델·수준 | 실제 modelUsage | 결과 |
|---|---|---|---|
| C18 코어·저장·네트워크/모델·목표 | `claude-opus-5-5` / `xhigh` | `claude-opus-5-5` | exit0, is_error=false, Important2 |
| C19 화면·입력·3D·설정·현지화/오디오 | `claude-opus-5-5` / `xhigh` | **`claude-opus-5-5`와 `claude-opus-4-8`** | exit0, is_error=false, Important0, 경미/후보 별도 |
| C20 제작·콘텐츠·검사·내보내기/패키징/CI | `claude-opus-5-5` / `xhigh` | `claude-opus-5-5` | exit0, is_error=false, Important4 |

C19의 최종 화자별 귀속과 두 모델을 사용한 원인은 응답에 노출되지 않았다. 호출자가4.8 fallback을 선택한 것은 아니며, 단독5.5 검토로 표시하지 않는다. 세 응답 모두 permission_denials는 빈 배열이다. 모든 원본260파일의 전후 SHA가 같았고 그 뒤 부모가 보고 문서만 작성했다.

별도 `gpt-6.1-sol/xhigh` 검토자는 Claude 주장과 실제 소스·데이터를 읽기 전용으로 대조했다. 부모는 Godot/FFmpeg를 이용해 임시 진단 파일과 고유 테스트 슬롯에서 아래 현상을 재현했다. 모델의 동의를 실행 증거로 대신하지 않았다.

## Important — 우선 해결할 세 항목

### R1. 유효한 파일 명령으로 저장할 수 없는 상태가 만들어짐

**채택·격리 실행 재현.** [경로 정규화](../../godot/scripts/core/virtual_fs.gd)의 `normalize`는 입력 인자 길이를 제한하지만 cwd와 합친 최종 경로는 다시 제한하지 않는다. [파일 명령과 저장 검증](../../godot/scripts/core/campaign_runtime.gd)의 `_file_command`/`validate_world` 사이에도 항목 수·경로 한계가 일치하지 않는다. 보관은 [기존 Game의 `_archive`](../../godot/scripts/core/game.gd)에서 디렉터리를 포함한 총128항목으로 막힌다.

실제 UI 입력 한도512자 안의 명령5개(길이408/405/406/403/226)로 각각400자·400자·220자 디렉터리를 상대 경로로 중첩했다. 모두 정상 처리됐으나 이후 저장은 `SAVE_INVALID_SNAPSHOT / Invalid local file entry`로 거절됐다. 최초1000자 인자라는 Claude 예시는 UI512 제한과 맞지 않아 그대로 재현 근거로 쓰지 않았다.

- 기존 정상 테스트 슬롯의 파일 SHA는 유지됐다. **디스크 세이브가 덮어써져 파괴된 것은 아니다.** 현재 메모리 진행을 저장할 수 없는 문제다.
- 미완료 현재 사건은 reset 후 저장이 성공했다.
- 이미 완료한 사건의 영수증이 잘못된 세계로 교체된 경우는 reset 후에도 저장 거절이 남았다. 정상 저장 불러오기 또는 해당 사건 재완료가 필요하다.
- 로컬 초기4항목에 디렉터리124개를 추가한128항목 상태에서는 정상 자료를 `scp`해도 `ARCHIVE_LIMIT`로 막혔다. 이 포화와512항목/2MiB 저장 한계는 구분한다.

**수정 방향만 제안:** 최종 경로·항목·스냅샷 예산을 쓰기 경계에서 일관되게 확인하고, 거절한 행동은 적용하지 않는다. 검증기를 느슨하게 바꿔 저장시키는 방법은 권하지 않는다. 현재 코드에는 적용하지 않았다.

### R2. 필수 근거 수집의 반복과 최종 종합 사건의 계약 격차

**부분 채택·중요 콘텐츠/학습 계약 문제.** [콘텐츠 생성기](../../tools/build_campaign_content.py)의 `strengthen_case`와 [판정 모형](../../godot/scripts/core/tool_runtime.gd), 실제 캠페인/fixture를 대조했다.

- 자료 목표89개 중66개가 공통 exhibit 판정 틀을 사용한다. A는 문서의 left/right를 compare에 입력하고, B는 관측 행에서 참조값으로 선택하는 trace/packet 계열이다. 표준 경로에서 이 부분만66×5=330행동이 반복된다.
- “56개 실행 경로가 존재하며 재생된다”는 사실과 “56개의 독립적인 추론 퍼즐”이라는 주장은 다르다. 구조적으로 다른 JSON 경로만으로 의미 다양성을 증명하지 못한다.
- [CURRICULUM](../CURRICULUM.md)과 [QA 계약](../implementation/full-qa-contract.md)의 M24 웹·네트워크·시스템 종합 적용 약속과 달리, 현재 M24 자체 판정은 compare/trace와 자료/fact/원본 보존 중심이다. 선행 사건 완료가 M24 안의 새 경계 검증을 대신하지는 않는다.
- R01의 `reverse`는 실제로 XOR 후보 판정이며 [분야 계약](../DOMAIN_SCOPE.md)의 작은 의사코드·분기/호출 관계 해석까지 구현한 것은 아니다.

**과장으로 기각한 부분:** 모든 경로가 동일하거나 접근권 판정이 전혀 없는 것은 아니다. 실제 인증·출처·정책·내부망 경로·M15/M22 관리 세션 제약과 유효한 대안이 있다. 하나의 코어 판정기를 UI와 RequestLab이 함께 쓰는 것 자체는 결함이 아니다. 재미 실패나 실제 플레이타임도 아직 측정하지 않았다.

**수정 방향만 제안:** 반복 필수 근거를 줄이고 관계 해석·현재 상태 변화·서로 다른 경계 근거를 사용하는 사건과 M24를 보강한다. 특정 도구 이름이나 명령 횟수를 필수 목표로 강제하거나, 도구 종류가 다르다는 형식 검사만 추가하는 방법은 권하지 않는다. README에서는 검증 fixture 수와 독립 퍼즐 다양성의 주장을 구분했다. 게임 데이터는 수정하지 않았다.

### R3. 한국어의 사람용 교육 문단에 영어가 남음

**채택·실제 표시 문자열 확인.** [생성기 `operational_rows`](../../tools/build_campaign_content.py)와 [locale importer](../../tools/import_campaign_locales.py)는 한국어 `_CONTEXT`/`_ROUTE`에 영어 교육 문단을 붙인 뒤 ja/zh/es/de에만 별도 치환한다. 실제 [ko PO](../../godot/locales/ko.po)1104/1182/1242행 등에 영어 문장이 남는다. 독립 대조에서는 교육 문단16종 중15종이26개 표시 값에 부분 문자열로 남는 것을 확인했다.

경로·계정·명령·원자료 표식을 번역하라는 뜻이 아니다. `Resolve the requested path ...`, `The first row must be refused ...`처럼 사람이 읽는 경계/절차 설명이 대상이다. M11/M12 파일과 workbench에서 이 번역 키를 보여 주므로 단순 작성용 잔재도 아니다.

**수정 방향만 제안:** canonical 토큰은 보존하고 교육 문단만 한국어로 옮긴다. 모든 영어를 금지하는 광범위한 검사는 피한다. 현재 번역 파일은 수정하지 않았다.

## Medium — 좁혀서 채택한 세 항목

| ID | 확인한 현상 | 교정한 과장·한계 |
|---|---|---|
| R4 · `/login` 보상 게이트 | [공유 로그인](../../godot/scripts/core/campaign_runtime.gd)의 모델 커밋에는 `use_challenge`의 선행 fact 검사가 없다. M06/M23 모두 직접 도구는 `MISSING_EVIDENCE`인데 HTTP200→401→401→429 뒤 관련 fact/자료가 먼저 생기며 정상 저장된다. | 최종 필수 자료는 여전히 남아 `completed=false`다. **사건 완료 우회는 아니다.** 로그인 전에 이미 로그인 세션을 요구하는 식으로 `_requirements` 전체를 붙이면 다른 흐름을 깨뜨릴 수 있다. 실제 인증 결과와 퍼즐 보상 조건을 구분할 문제다. |
| R5 · 루프 경계 감쇠 | [master](../../tools/generate_audio.py)는 양끝25ms를0 쪽으로 줄인다. 기존 OGG의 경계 중심5ms RMS는 주변2초 대비 rain −24.480dB, A03 −26.207dB였다. 현 검사는 이 짧은 dip을 검출하지 않는다. | 경계±25ms의 정확한 무음 프레임은 두 파일 모두0. **50ms 완전 무음이라는 표현은 틀리다.** 가청 끊김/거슬림은 실청 전이라 Important로 확정하지 않는다. fade를 무조건 삭제하면 click을 다시 만들 수 있다. |
| R6 · export/PCK 반복 검증 | 현재 추적 도구/CI에는 실제 export와 PCK 내부 검사 gate가 없다. 실제 사용한 inspector는 ignored 로컬 산출물이다. 향후 필터 변경 때 같은 검사가 반복된다는 보장은 부족하다. | 표준 Godot preset export가 재현 불가능한 것은 아니다. 실제 세 PCK 각47PASS 로그·소스/트리·해시 증거는 존재한다. **기존47PASS가 허위이거나 현재 PCK가 오염됐다는 주장은 기각한다.** 기존 inspector를 tracked 절차로 옮기는 것이 우선이다. |

## 추가 UI 재현과 기각한 후보

- [역방향 창 순환](../../godot/scripts/apps/campaign_desktop.gd)의 `_cycle_window(-1)`은 열린4창에서8번 호출해도 `help ↔ term0` 두 개만 오갔다. 정방향은4개 모두를 순환했다. 직접 단축키·작업 표시줄 우회가 있어 경미로 분류한다.
- 같은 파일 `_size`의 등록 배열은 `_refresh_all`40회 뒤312→1512개, 해제된 컨트롤 항목1245개가 남았다. 긴 세션의 누적 메모리/폰트 변경 비용 위험이다. 실제8시간의 메모리 크기나 프레임 지연까지 측정하지는 않았다.
- CREDITS_BODY 누락 후보는6개 PO 모두 키가 존재해 기각했다. 가정만 있는 메일 인물 ID/IME/Windows rename 등은 확정 결함으로 승격하지 않았다.
- 레거시 단일 UI의 reduced-motion 미지원은 제품 메인 경로와 구분한다. 자동 검사·실제 GUI·원어민·실기기·청취를 혼합하지 않는다.

이 UI 재현은 headless에서 실제 컨트롤/함수를 호출한 기능 진단이다. 실제 OS 키보드·마우스를 주입한 검증으로 표시하지 않는다.

## 새 검증 증거와 보존

현재 소스의 `bash tools/gate.sh`는 다시 exit0/PASS였다. 캠페인31,717항목·기존336·presentation/콘텐츠/locale·Python35·경계5 등의 기존 정상/부정 경로를 보존한다. 위 저장 경계와 UI 누적·역순환은 그 통과와 양립하는 커버리지 공백이다.

새 프로브는 `.omx/artifacts/claude-full-audit-20261105/`에만 작성했다. 고유 `user://tests/` 슬롯과 유한한 가상 상태만 사용했다. 기본 캠페인/구버전 저장/설정6경로의 SHA가 전후 동일했다. 최초 임시 프로브의 `sessions` 별칭 참조 오류는 실패 로그로 남기고 실제 snapshot의 `terminals["0"]`로 고쳐 exit0 재현한 뒤 위 결과를 채택했다. 이를 제품 오류로 세지 않았다.

원문·정확한 prompt·요청 argv·실제 모델·결과 JSON·SHA와 수정 금지 증거:

```text
.omx/artifacts/claude-full-audit-20261105/
  ask-claude-entire-game-20261105.md
  coverage.json / baseline-files.json / post-review-integrity.json
  {core,presentation,delivery}-{prompt.txt,result.json,invocation.json,completion.json,review.md}
  core-triage.md / delivery-triage.md
  baseline-gate.log / core-findings-measurements.json
  ui-findings-probe.log / audio-seam-measurements.json
```

## OST 피드백과 완성한 비교용 강화본

기존은72~104BPM이며7곡 중 조건부 킥이 들어가는 곡은2곡뿐이었다. [무드 선택](../../godot/scripts/full_game.gd)은 대부분 평상시 사건에 A03(76BPM)을 선택하고, 초반은 A02(84BPM)를 고른다. 기본 Master0.8×Music0.65와 음원 RMS를 합친 약 −28dBFS도 존재감을 줄인다. 이는 코드/메타데이터 근거이며 사람의 실제 음량 평가가 아니다.

`gpt-6.1-sol/high`가 기존 오리지널을 재편곡한 **검토용7곡+엔딩 편집본**을 별도 staging에 만들었다. 곡은112~148BPM, 킥·스네어·리듬 베이스·8/16분 arp·16마디 break/return을 포함한다. 총 작곡 길이는20분22.95초다. A02/A03/A05는 각각128/124/148BPM이다. 기존 SFX/환경음13개는 바이트가 같다. 이 강화본과 원본 게임은 서로 다른 산출물이며 앱에는 아직 적용하지 않았다.

전후 비교는 기존/강화A02, 기존/강화A03, 기존/강화A05 순서로 각30초+1초 간격, 총185초다. WAV는 −22.00~−21.99LUFS, AAC는 −22.02~−22.01LUFS로 맞춰 단순 음량 차이와 편곡 차이를 분리했다. 실제 청취·장시간 피로도·효과음과의 최종 믹스는 미검증이다.

```text
.omx/artifacts/ost-revision-20261105/
  A02_A03_A05_before_after_30s_level_matched.m4a
  MidnightAccess-OST-DriveMix-review-20261105.zip
  OST_REVISION_REPORT.md / analysis.json / preview_cue_sheet.json
```

검토 ZIP은23,520,280바이트,31항목이다. SHA256 `53e2da4d0fab59500ae06dad480b91ce2fea976c09ba02e757d24252bc48bc1c`. 전체 OGG21개의 실제 디코드·해시·클리핑 검사와 ZIP CRC/파일별 해시 대조를 수행했다. 이 검증을 무결점 가청 루프나 음악 취향의 증거로 확대하지 않는다. 큰 WAV masters는 제외하고 OGG·생성기·라이선스/manifest·비교M4A·보고서를 묶었다.

## 후속 우선순위 — 이번에는 미구현

1. 상태 변경과 저장 검증의 경계/예산 일치를 회귀로 고정한다. 기존 정상 저장 보존과 복구를 유지한다.
2. 필수 증거 반복을 줄이고 M24/R01의 실제 학습 계약을 보강한다. 단순 이름·키 변경으로 다양성을 주장하지 않는다.
3. 한국어 사람용 교육 문단을 정리한다. canonical 값은 보존한다.
4. 보상 게이트·역순환·UI 등록 배열·루프 품질·추적 가능한 PCK 검사 절차를 각각 좁은 변경으로 검증한다.

위는 검사 결과에 따른 제안이다. 이번 읽기 전용 과제에서 게임 코드나 콘텐츠를 자동으로 고치지 않았다.
