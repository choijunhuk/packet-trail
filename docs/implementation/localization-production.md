# 다국어 제작·검증 기록

작업 경로: `packet-trail-full`, `feat/full-campaign`. 리더 지정 제작 정책은 Codex 6.1 / high다. 이 문서는 번역 초안·자동 검증과 원어민 검수·실제 OS 검증을 구분한다.

## 구현 범위

현재 `ko/en/ja/zh_Hans/es/de`의 표준 Godot PO 카탈로그를 제공한다. 캠페인 826키와 공통/작업실/설정 66키, runtime 결과 62키와 도움말 2키, 공용 도구 12키, 데스크톱 UI 475키로 언어당 1,443키(전체 8,658개 항목)다. 28사건의 제목·의뢰·후속 답신 84키, 목표·힌트·교육 해설·관찰 자료·인계 경로·독립 보관 자료·진행 단계·세 결말을 포함한다. 475개 UI 키는 창·터미널·메일·연락처·브라우저·RequestLab·23종 도구 설명·파일·자료 비교·목표·저장 복구·결말·전체 도움말까지 포함한다.

일본어·간체 중국어·스페인어·독일어는 이번 작업에서 작성한 번역 초안이다. 한국어 복사나 원문 fallback을 번역 완료로 계산하지 않는다. 원어민이 전편을 검수한 결과는 아니다.

`PacketLocalization`은 `RefCounted` 정적 API다.

```gdscript
const Localization = preload("res://scripts/presentation/localization.gd")
Localization.configure("ko")
Localization.set_locale("de")
var text = Localization.tr_key("MISSION_PROGRESS", {"current": 2, "total": 28})
var font = Localization.get_font()
```

`configure`가 6개 `.po`를 `TranslationServer`에 등록하며, 언어 전환은 Godot의 번역 알림을 사용한다. `get_locale()`도 제공한다. `get_font()`는 KR 본문 폰트와 JP·SC fallback을 보유하는 동일 Font 참조를 반환한다. 자체 폰트가 필요한 호출자는 `install_font_fallbacks(font)`의 반환값을 보유한다. 실제 Godot 4.7 확인 중 상수 폰트 참조의 다른 평가에서 fallback 수정이 유지되지 않는 현상을 관찰하여, 다른 `preload` 상수가 바뀔 것이라고 가정하지 않았다.

명령·옵션·경로·가상 계정·암호·URL·IP·레코드/저장 ID·JSON 관찰 필드는 번역하지 않는다. `CAMPAIGN_RESULT_<code>` 62키는 뜻을 각 언어로 표시하고 `{detail}`에 가상 기술 관찰값을 보존한다. 자료 표시 문자열만 번역하며 무결성 판정은 캠페인의 canonical 본문으로 유지한다. `NEW_GAME_CONFIRM`과 `IMPORT_CONFIRM`은 새 진행/가져오기가 기존 캠페인을 백업 후 대체하고 구버전 M01 저장은 유지한다는 실제 정책을 안내한다.

## 제작 소스와 재생성

- `godot/locales/common.json`: 언어 순서 `ko/en/ja/zh_Hans/es/de`의 공통 문자열.
- `narrative.source.json`: 28사건의 독립 서사 번역.
- `guidance-drafts.json`, `campaign-static.json`, `proofs-drafts.json`, `operational-prose.json`: 고유 목표·원리, 공통/첫 사건/결말, 66개 독립 근거의 제목·발견 설명, 운영 자료의 교육 문단 번역 원고.
- `tools/import_campaign_locales.py`: 콘텐츠 담당의 `godot/data/campaign/locales/ko.json`, `en.json`과 원고를 합쳐 `campaign.source.json` 생성. 정형 인계/해설 문장은 언어별로 작성한 문장 틀을 사용하고, 관찰된 로그·테이블·가상 계정·비밀·경로는 그대로 삽입한다. 로그에 덧붙인 교육 문단 16종은 각 언어로 번역한다. 새 키에 원고가 없거나 검토한 한영 원문 SHA256이 바뀌면 실패한다. 원문 변경 시 네 번역을 검토하고 helper의 검토 해시를 갱신한 뒤 다시 생성해야 한다.
- `tools/import_ui_locales.py`: UI 한영 카탈로그 475키와 원고를 병합한다. 같은 원문은 공통 번역을 재사용하고, canonical 이름·JSON 예시·순수 보간만 원형으로 둔다. 검토한 UI 원문 해시가 달라지면 재검토를 요구한다.
- `tools/build_locales.py`: `.source.json`과 공통 소스로 6개 표준 `.po` 및 pseudo fixture 생성.

```sh
python3 tools/import_campaign_locales.py
python3 tools/import_ui_locales.py
python3 tools/build_locales.py
python3 tools/test_check_locales.py
python3 tools/check_locales.py
```

## 폰트 출처와 배포

기존 `NotoSansKR.ttf`, `OFL.txt`, `SOURCE.json`은 변경하지 않았다. JP·SC 원본은 공식 Google Fonts 저장소의 commit `bbda7253fc363238b05d97515ca71f8ae49c4fa9`에서 그대로 받았다. 공식 메타데이터와 SIL Open Font License 1.1을 웹에서 확인한 뒤 다운로드했다. 원본·메타데이터·언어별 OFL·SOURCE JSON을 함께 보관한다.

| 자산 | 크기 | SHA256 |
|---|---:|---|
| NotoSansJP.ttf | 9,589,900 bytes | `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f` |
| NotoSansSC.ttf | 17,772,300 bytes | `a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da` |

두 OFL 파일 SHA256은 `1c05c68c34f9708415aada51f17e1b0092d2cea709bf4a94cd38114f9e73d7d9`다. 공식 출처: [JP 메타데이터](https://github.com/google/fonts/blob/bbda7253fc363238b05d97515ca71f8ae49c4fa9/ofl/notosansjp/METADATA.pb), [SC 메타데이터](https://github.com/google/fonts/blob/bbda7253fc363238b05d97515ca71f8ae49c4fa9/ofl/notosanssc/METADATA.pb), [JP OFL](https://github.com/google/fonts/blob/bbda7253fc363238b05d97515ca71f8ae49c4fa9/ofl/notosansjp/OFL.txt), [SC OFL](https://github.com/google/fonts/blob/bbda7253fc363238b05d97515ca71f8ae49c4fa9/ofl/notosanssc/OFL.txt).

표준 PO와 Font fallback 사용은 [Godot gettext 문서](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_gettext.html), [Font 문서](https://docs.godotengine.org/en/stable/classes/class_font.html#class-font-property-fallbacks)를 확인했다. 런타임에는 네트워크나 실제 셸을 사용하지 않는다.

## 검증 증거와 남은 범위

PASS:

- 콘텐츠 2차 번들의 신규 337키·변경 272키와 마지막 정합성 6키, 데스크톱 UI 475키를 반영하고 미사용 단계 162키를 제거했다.
- Python 회귀 17개: 누락 키, 중복/손상/fuzzy PO, 중복 placeholder, 번역된 canonical 경로, 한국어/영어 원문 passage 잔존, 필수 콘텐츠 키 누락, pseudo 보간 보존, 실제 Unicode cmap 파싱/손상 거절.
- 언어당 1,443개 PO의 구문, 비어 있지 않은 번역, 6언어 키 일치, 이름 있는 보간 및 printf 형식 개수, 경로·URL·IP·명시 코드 토큰 동일성, 콘텐츠 키 및 한영 원본 동기화.
- JP/SC 파일·OFL 해시와 공식 commit 고정, 네 폰트의 실제 cmap을 합쳐 모든 번역 문자열의 glyph 존재 확인.
- Godot 4.7 `--check-only`로 localization.gd 검사. 캠페인 번역 재생성을 두 번 실행한 뒤 소스 해시가 동일함을 확인하여 인가계정 부록 중복 추가를 방지했다.
- 별도 임시 SceneTree 검사에서 6언어 `CONTINUE`/locale 전환, `MISSION_PROGRESS`와 `UI_TERM_HEADER` 보간, 미지원 locale 거절, cached Font의 JP/SC fallback 2개 유지 확인. Godot가 8,658개 번역 항목을 실제로 읽고 6개 언어의 긴 UI 도움말을 반환했다. KR에 없는 314개 사용 문자를 확인했고, 이 중 CJK 표본을 Godot `Font.has_char`로도 검증했다. 기존 저장에 접근하지 않았다.

NOT_RUN 또는 별도 검증:

- 전체 gate와 export는 리더의 통합 단계에서 실행한다.
- `pseudo-layout.json`은 40% 확장 문자열과 1280×720/1600×900, 글자 배율 1.0/1.6의 렌더 계약이다. 데이터 통과만으로 실제 레이아웃 통과를 주장하지 않는다.
- 모든 언어의 전편 GUI 줄바꿈·잘림·상태 전환, 원어민 문체/용어 검수, 실제 Windows/macOS/Linux IME와 보조기술 검증은 별도다.
- 기존 M01 회귀용 `core/game.gd`의 한국어 문장을 임의로 전역 치환하지 않았다. 새 runtime은 안정 결과 키를 사용하고, 원문 기술 관찰값은 `{detail}`에 보존한다. 전체 실행판의 UI/결과 경계 검증은 리더가 통합한다.

작업실 담당의 별도 native 확인: 독일어 새 게임 확인·스페인어 가져오기 확인의 긴 본문/버튼이 좁은 뷰와 글자 배율 1.6에서 화면 안에 표시됨을 보고했다. 일본어 설정 하단의 스크롤·fallback도 확인했다. 증거는 `.omx/artifacts/full-room/new-game-de-large.png`, `import-es-large.png`, `settings-ja-large.png`, `settings-de-large.png`다. 이는 작업실 일부 화면의 증거이며 전편 6언어 GUI 검증과 구분한다.


## Latin 고정폭 후속 구현

`get_mono_font()`는 Noto Sans Mono 2.014를 캐시하고 `Mono → KR → JP/SC` fallback 체인을 반환한다. 일반 `get_font()`의 동작과 JP/SC fallback 2개는 유지한다. UI 파일은 이 작업에서 수정하지 않았으며, 리더가 터미널 텍스트·입력에만 전용 FontVariation을 연결한다.

Mono 역시 같은 Google Fonts commit `bbda7253fc363238b05d97515ca71f8ae49c4fa9`에서 가져왔다. [공식 메타데이터](https://github.com/google/fonts/blob/bbda7253fc363238b05d97515ca71f8ae49c4fa9/ofl/notosansmono/METADATA.pb)와 [OFL](https://github.com/google/fonts/blob/bbda7253fc363238b05d97515ca71f8ae49c4fa9/ofl/notosansmono/OFL.txt)을 확인했다. `NotoSansMono.ttf`는 1,708,408 bytes, SHA256 `2cb2adb378a8f574213e23df697050b83c54c27df465a2015552740b2769a081`이다. OFL-Mono.txt SHA256은 `cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a`이며, `SOURCE-Mono.json`·`METADATA-Mono.pb`·폰트 원본과 함께 보관한다.

프로젝트의 전체 gate/import/export를 실행하지 않고, 임시 프로젝트에 네 폰트와 localization.gd만 복사하여 Godot 4.7에서 검사했다. 기본 Font와 `wght=500/wdth=100` FontVariation 모두 아래 advance를 반환했다.

| 글자 크기 | i | W | 공백 | 0 |
|---:|---:|---:|---:|---:|
| 16 | 9.59375 | 9.59375 | 9.59375 | 9.59375 |
| 20 | 12 | 12 | 12 | 12 |
| 28 | 17 | 17 | 17 | 17 |

반복 호출 시 Mono 캐시 동일성, 일반 UI fallback 2개 유지, `한글日本語简体中文` glyph도 PASS다. 폰트 검사기에 Mono 출처·OFL·SHA256·glyph 검사를 추가했고 기존 Python 17개와 1,443키/locale 검사도 PASS다. `CREDITS_BODY`만 6언어 모두 `Noto Sans KR / JP / SC / Mono`로 갱신했다. 새 라이브러리나 번역 키는 추가하지 않았다.

Latin 고정폭을 검증한 결과이며 CJK 글자를 2칸 격자로 정렬한다는 주장은 아니다. 최종 실행판의 터미널 적용과 패키지 내 Mono/OFL/SOURCE 포함은 리더의 GUI·배포 검증 범위다.
