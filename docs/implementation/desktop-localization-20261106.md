# 1.2 데스크톱 경험 · 다국어 문구

작업 경로 `packet-trail-desktop`, `feat/desktop-experience`. UI KO/EN master와 locale 원고/PO/검토 SHA만 이 레인에서 편집한다. UI/Core/packs와 기존 캠페인 원문은 각 담당자 소유를 유지한다.

## 현재 문구 묶음

- `flow.json`24키와 `desktop.json`48키를 제품 UI master에 우선 병합했다. 기존651키와 충돌/값 수정 없이723키가 됐다.
- Desktop48키는 UI 담당자에게 최종 동결 확인을 받았다. Flow24키도 Root에게 artifact/master 그대로 최종 동결 확인을 받았다. 두 묶음의 마지막 동결 뒤 source SHA를 갱신했다.
- 신규72키의 ja/zh_Hans/es/de 초안은 `ui-desktop-drafts.json`에 작성했다. 보간·canonical 토큰·glyph 표적 검사는 통과했다. Root의 직렬 import 완료 뒤 허용된 단일 Godot 검사를 수행했다. 실제 렌더 GUI와는 구분한다.

## 의미와 보존 경계

Guided/Standard/Independent는 **도움 강도와 자동 안내·힌트 표시량**이다. 난이도, 경보 규칙, 목표 또는 허용 해법을 바꾸는 모드로 번역하지 않는다. 자율에서도 도움말과 수동 힌트를 사용할 수 있다고 명시한다. 설정에서 바뀌는 것은 지원 선택임을 분명히 한다.

세 시나리오는 역할과 할 일로 소개한다. 앱이 없는 바탕화면/검색 결과 없음은 실제 빈 상태로 설명한다. Nightfox는 고유 브랜드명을 그대로 둔다. 실행 중/최소화/복원, 현재 요청 주체와 표시 중인 과거 응답을 구분하고 새로고침 후에만 현재 서버 상태를 확인한다는 뜻을 유지한다.

명령·계정·호스트·경로·canonical 자료와 `{name}` 형식의 자리표시자는 보존한다. 기존 legacy와3팩 원문/번역은 유지한다. 일본어·간체·스페인어·독일어는 작성된 번역 초안이며 원어민 문체/용어 검수 결과가 아니다.

## 검증 구분

Python source/PO/token/glyph 검사는 이 레인의 표적 범위다. Godot import는 Root의 직렬 slot 신호 뒤에만 수행한다. whole gate·native·export·commit은 실행하지 않는다. 실제6언어 줄바꿈·잘림·키보드/IME·게임 조작은 별도 증거로 구분한다.

## Python 검증 완료 snapshot

- KO/EN master723키, 신규72키 ×6언어를 병합한 전체 PO2,646키/locale(15,876항목).
- Flow24/desktop48의 최종 값과 제품 master가 정확히 일치한다. 기존651키 값 수정/충돌은0건이다.
- 캠페인 원문과 legacy/3팩 source SHA는 모두 불변이다. UI source SHA만 최종 master로 갱신했다.
- `import_campaign_locales.py`, `import_ui_locales.py`, PO builder와 checker가 PASS다. Python 회귀27개, 보간·canonical 토큰·교육 문단·glyph 검사, diff 검사도 PASS다.

| 동결 입력 | SHA256 |
|---|---|
| flow.json | `282414296aa0733af84c47700f899fa1d7b39fd8cabc02c3b55f2b334e750e36` |
| desktop.json | `5cf1836738a1fb3cbbd9855a4f6407ed045359a4eb11b8f6d86c2990e61d14a0` |
| 제품 UI KO | `83587dd82dfda63b33822abe98a982c41c09e38137d1e02d71c55812e8907695` |
| 제품 UI EN | `d4e5d88ab767dc39cd28b7d61436e6b42ecb779a4dc6facf352309cc8aa23055` |

같은 source SHA는 `godot/locales/source-revisions.json`에 고정한다. Root가 source UI와 두 artifact를 마지막 동결한 다음에만 갱신하여1.1의 마지막 문구 수정 뒤 stale hash가 남는 문제를 피했다. Godot/native/원어민 검증은 이 Python PASS에 포함하지 않는다.

## Root 직렬 import 뒤 실제 Godot 로드

Root가 새31SVG와6PO를 실제 import해 exit0/Script Error0을 확인한 다음, 이 레인에 단일 프로세스 slot을 넘겼다. 기존 제품 asset/locale/import cache를 읽고 project/user 경로만 고유한 임시 경로로 분리해 검사했다. 다른 UI/Core/시나리오 장면을 생성하거나 실제 사용자 save/settings를 읽지 않았다.

Godot4.7 PASS:

- 실제6PO **15,876항목** 로드, 언어당2,646키,6언어 전환.
- support3방식/설명·settings4카테고리·Nightfox 탭/과거 응답 문구가 번역 키 대신 실제 문장으로 반환됨.
- Nightfox 고유 브랜드 유지, `{goal}/{hint}`와 실제 개행, 요청 터미널 `{n}/{user}/{host}`, 현재/과거 응답 보간.
- 사용된 **1,989개 고유 glyph**를 일반 UI와 Mono 폰트 양쪽에서 확인, 실패0개.

이는 resource-string/폰트 smoke다. 설정 동작·지원 방식이 게임 규칙을 바꾸지 않는지·창/탭 실제 조작·줄바꿈/잘림을 렌더 GUI로 검증한 결과는 아니다. 이 레인의 Godot는 종료했고 Root에 NativeQA slot을 반환했다. whole gate/native/export/commit은 이 레인에서 수행하지 않았다.

최종 동결: UI723키, 신규72키 ×6언어, 전체 PO2,646키/locale. 위두 UI source SHA와 두 copy SHA는 최종 master 값이며 후속 문구 수정은 재검토 전까지 실패하도록 유지한다. 원어민 문체·용어 검수는 미실행이다.
