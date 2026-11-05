# 1.1 다국어 확장 구현·검증

> I4 후속 최종본은2,574키/locale, 총15,444항목이다. 아래1차2,489키 검증과 source/PO SHA는 수정 전 기준으로 보존하며, 최종 검증은 마지막 절에 따로 기록한다.

기준 `0565166`, 작업 경로 `packet-trail-expansion`. 6언어 `ko/en/ja/zh_Hans/es/de`에 **2,489키씩, 총14,934개 번역 항목**을 병합했다. 이는 번역 초안의 구현·표적 검증 결과이며 원어민 검수나 전체 게임의 native 검증을 뜻하지 않는다.

## 1차2,489키 원문 동결 범위

| 원문 묶음 | 키 수 | locale 원고 |
|---|---:|---|
| 동결 legacy | 826 | `locales/ko.json`, `en.json` |
| 침투자 | 508 | `locales/intruder_v2.{ko,en}.json` · `IN2_` |
| 방어자 | 193 | `locales/defender_v1.{ko,en}.json` · `DF1_` |
| 추적자 | 131 | `locales/tracker_v1.{ko,en}.json` · `TR1_` |
| 공용 UI | 635 | `assets/ui/strings_{ko,en}.json` |

공용 메뉴·결과·도움말·도구 문구를 더하고 같은 6언어 행은 한 번만 출력한다. 값이 다른 동일 키는 PO를 쓰기 전에 거절한다. 각 한영 원문의 정확한 경로와 SHA256은 [source-revisions.json](../../godot/locales/source-revisions.json)에 따로 기록했다. 콘텐츠 담당과 R01 한국어 주석, D03의 세션 거부 표현, D07 초기 baseline label을 포함한 `508/193/131` snapshot을 맞췄다. 이후 원문 값 변경은 재검토 전까지 실패한다.

소유 밖의 콘텐츠 JSON·생성기·해법 fixture·UI 원문 자산·폰트/OFL 원본은 이 레인에서 편집하지 않았다. 기존 `campaign.json` SHA256은 `51699e38f77e1cf1caa01eaa2617587e9e668261c82373cb77d7ad5b0c74d9b8`, 기존 KO/EN 원문 SHA도 그대로다.

## R3 · 한국어 교육 문단

수정 전 알려진 영어 교육 문단이 한국어 표시 **26개 값에32회** 남았다. `operational-prose.json`의 기존 네 번역 앞에 KO 열을 추가해 `ko/ja/zh_Hans/es/de` 순서의16문단 registry로 두었다.

원문 JSON과 `.source.json`의 원문 열은 보존하며, PO 생성 시 **정확한 전체 교육 문단만** 표시 언어로 바꾼다. 같은 변환을 원문 동기화 검사에도 적용한다. 수정 후 한국어 PO의 잔존은0회다. 영어라는 이유로 주소·계정·암호·명령·로그 행·가상 식별값을 치환하는 검사는 만들지 않았다.

부정/양성 회귀는 원문 문단 잔존, KO 열 누락, machine 자료 불변, 부분 문장 비치환을 확인한다. 격리된 Godot TranslationServer에서 `M06_CONTEXT`가 한국어 교육 문장을 반환하고 `00:46 account=staff origin=unknown outcome=failed` 행을 그대로 남기는 것도 확인했다.

## 번역 이력과 의미 보존

- 침투자508키: 정확한 기존 한영/KO표시 재사용347키, 본문/목표/원리 변경을 대조한 재사용74키, 새 의미·절차87키다. 제거된66필수 수집 체인의 설명을 새 목표/힌트에 다시 넣지 않았다.
- R01은 XOR 단어 복원이 아닌 분기·호출·정상 입력·범위 밖 반례로 번역했다. pseudocode의 함수·변수·분기 식별자는 유지하고 주석만 번역했다.
- M17은 실제 가상 계정 인증과 제한 파일 권한을 구분한다. XOR/실제 암호 해시 크래킹 성능 모형으로 설명하지 않았다.
- M24는 과거 완료·수집 사본과 현재 web/route/service 결과를 구분한다.
- 방어·추적 고정 서사48키는 별도6열 초안으로 작성한 뒤 실제 source와 대조했다. 계정 부록은 원형 보존했다. 반복 설명·조치·사례 이름은 같은 번역을 재사용한다.
- D03 후일담은 특정 폐기 동작을 했다고 단정하지 않고 실제 ‘옛 세션의 거부’를 설명한다. D07 baseline은 고의 오조치를 강요하는 표현 없이 검증된 인계 시점의 가용성으로 번역했다.
- supported는 근거의 지지, refuted는 반증, underdetermined는 근거 부족/판단 유보다. 숨은 정답이나 사람의 신원 확정으로 표현하지 않았다.
- 새3모형의 표시명/절차·동작19종·관계3종·출처/표본/평문 한계·VM 상태/예산/호출 주체를 번역했다. 실행 종료를 사건 해결로 표현하지 않았다.
- 저장/모델 결과는 `{detail}`를 보존하되 고정된 성공 행동을 가정하지 않는 표제를 사용했다. 다른 캠페인/버전 저장은 손상으로 단정하거나 교체했다고 안내하지 않는다.

일본어·간체·스페인어·독일어는 AI 작성 번역 초안이다. source의 서사 품질 검토와 이 번역의 원어민 검수는 별개다.

## 파이프라인과 단순화

- `import_campaign_locales.py`: 고정 source 경로·팩·언어별 SHA, namespace, 한영 키 일치와 완전한6열 원고를 검증한다. frozen legacy를 다시 옛 생성기의 AST/영문 문장 구조로 재생성하지 않는다. 이 단순화 전후 legacy 원고2개와 PO6개 해시는 같았다.
- `import_ui_locales.py`: 검토한 UI source snapshot과 기존/신규 원고를 병합한다. 의미가 바뀐 VALUE/LEFT/RIGHT 필드도 교정했다.
- `build_locales.py`: 기존 표준 Godot PO/TranslationServer 경로를 유지한다. 새 runtime 의존성·번역 SDK는 없다.
- `check_locales.py`: 6언어 parity/빈 문자열/보간/printf/경로·URL·IP·역할 계정·암호/교육 문단/원문 SHA·키 동기화/CJK glyph·기존 폰트 manifest를 검사한다. 가상 프로그램의 instruction label/opcode는 canonical로 유지한다.

```sh
python3 tools/import_campaign_locales.py
python3 tools/import_ui_locales.py
python3 tools/build_locales.py
python3 tools/test_check_locales.py
python3 tools/check_locales.py
```

## 1차2,489키 검증 증거

PASS:

- Python 회귀27개: R3, 보간·canonical 변형, 등록 경로·독립 pack SHA·namespace·한영 불일치, 공용 키 충돌, 빈 번역·옛 생성기 없는 import, canonical program label 등을 검사했다.
- 최종 원문4묶음과 UI635키 동기화, 2,489키/locale의 PO 구문·parity·보간·토큰·glyph 검사.
- Python compile, `git diff --check`.
- 격리 임시 Godot4.7 프로젝트에6PO·localization API·기존 네 폰트만 복사해 실제 `--editor --import` 후 실행했다. 6언어 전환, **14,934항목 실제 로드**, 새3팩 대표 키, VM named 보간, canonical 계정 부록, R3를 확인했다.
- 위 Godot probe는 사용된 **1,975개 고유 glyph**를 일반 UI 폰트와 Mono 폰트 양쪽에서 검사했고 실패0개였다. 원래 사용자 저장·설정을 읽거나 쓰지 않았다.

NOT_RUN:

- 전체 게임 gate/legacy31k·공개88·mutation/audio와 native GUI는 리더의 큰 묶음 검증 범위다.
- 전편6언어 줄바꿈·잘림·조작, 실제 Windows/macOS/Linux IME, 보조기술, 원어민 문체·용어 검수.
- export/PCK/서명/설치/배포는 이 레인의 검증으로 주장하지 않는다.

## I4 변경 전 2,489키 snapshot 보존

이하 값은 I4 대안 경로/현재 상태 수정 전의 검토 snapshot이다. 위27회귀·Godot 실제14,934항목 로드·1,975glyph 검증은 이 버전에 대한 기록으로 보존한다. 후속 변경의 검증으로 재사용하지 않는다.

```json
{
  "sources": {
    "campaigns": {
      "legacy_intruder": {
        "ko": {
          "path": "godot/data/campaign/locales/ko.json",
          "sha256": "99ba19e3aadd6f17cd983004815f6e1f67bc3d0299ad6f779b778432006faec7"
        },
        "en": {
          "path": "godot/data/campaign/locales/en.json",
          "sha256": "5b9fb00531baa378f16477cf619b2658fae4ddf0ed9d2f6d2f2ba4dbec785ffd"
        }
      },
      "defender": {
        "ko": {
          "path": "godot/data/campaign/locales/defender_v1.ko.json",
          "sha256": "2c56eb3d6baf4dc05398f9c6ffd3293b99b65528bf21f7b16cba51b2f234ee82"
        },
        "en": {
          "path": "godot/data/campaign/locales/defender_v1.en.json",
          "sha256": "7baad13f5ef504ef1c479e136b643d1103054e667126e96ad2208221e7a48a54"
        }
      },
      "tracker": {
        "ko": {
          "path": "godot/data/campaign/locales/tracker_v1.ko.json",
          "sha256": "268f5e117c681f230b35cf18227bb7d55b4cd3e70aabb5d9a14b8f02b94035e5"
        },
        "en": {
          "path": "godot/data/campaign/locales/tracker_v1.en.json",
          "sha256": "34c48024406b213ae936f67e2c8b446ef2306ab4306bc307df0fae954eac685c"
        }
      },
      "intruder": {
        "ko": {
          "path": "godot/data/campaign/locales/intruder_v2.ko.json",
          "sha256": "0d1723991570f160c30e96a5062a8623f3eb501f3bd9934e0ee28f2a326eea82"
        },
        "en": {
          "path": "godot/data/campaign/locales/intruder_v2.en.json",
          "sha256": "7c03ce8894323747dc64d09474a0e65b5d692a15cf9af0aecf0505f188f4e814"
        }
      }
    },
    "ui": {
      "ko": {
        "path": "godot/assets/ui/strings_ko.json",
        "sha256": "c141c7b7db3e34fe21ae6732eb95473cfc21fc6c83a4919e481c86461d35d0cf"
      },
      "en": {
        "path": "godot/assets/ui/strings_en.json",
        "sha256": "916aa8e95001014c7fe4897f6e665bc2dd8a6c3b10d065496042a11f783133b4"
      }
    }
  },
  "po_sha256": {
    "de": "6fcc4e042312428b4cb5c7c9719fe9585a0fa1e55b5a2b0937d2814f8ec8eba9",
    "en": "b256fa2668b0cd131fd74efa87938baca6de06d63dfd68286e043a6056394e7b",
    "es": "e5bf13507e66c6bfa34f91128b66f906d6fd889c879ca5ced2c3cccd5e115558",
    "ja": "4d9f3310c7ea98a0689d5e5f0fe020c0d4af3e0f12089898bf8d4737afde0db6",
    "ko": "43fbab2f23f426345a3ccc21c903c5b5d93b856521c011fc9b980dfca822b7c5",
    "zh_Hans": "c0b2c7d1ec56a7f2e9316ecfceb037b6b3757642b0fe86da86d6167d82228e04"
  }
}
```

## I4 후속 변경 작업

기존2,489키 원문/PO SHA와 검증 결과는 위 snapshot으로 보존한다. 현재 UI651키의 추가16키를 번역해2,505키/locale를 생성했다. 이 숫자는 후속 Data 원문 번역을 마치기 전의 작업 상태다.

D04의 업무 객체·업로드 저장 객체·업로드/격리 이력은 읽기 전용 표제로 번역했다. `execution_allowed`는 현재 허용, `execution_allowed_at_upload`는 수락 당시 허용으로 구분하고, `accepted`는 업로드 수락일 뿐 실제 실행 완료로 표현하지 않았다. 격리 상태 변경은 false일 때 해제하는 의미도 유지한다. R01의 listing/call_graph/trace는 기존 번역을 재사용한다.

M06/07/08/12/23의 실제 대안 경로와 목표가 바뀌는 원문은 콘텐츠 담당의 확정 snapshot을 받은 뒤 변경 키만 번역하고 pack별 source SHA를 갱신한다. legacy 원문과66필수 수집 제거는 유지한다.

## I4 최종 원문 동결·검증

최종 원문은 Intruder577 / Defender193 / Tracker131 / UI651키다. 침투자는 기존508키에서 신규71키를 더하고 더 이상 참조하지 않는 공개 tool명2키를 제거했다. 기존50키의 문장 변경도 검토했다. legacy826키와 원문/월드 SHA는 그대로 유지했다. 최종 한영 SHA는 `source-revisions.json`에 고정했으며, 이전 snapshot은 위 JSON으로 보존했다.

수정된 M06/07/08/12/23는 현재 actor·대상·provider·route의 실제 결과를 설명한다. 같은 동작을 다른 입력 표면에서 호출한 것만으로 별도 전략이라고 설명하지 않는다. 원래 서비스의 정밀 제어와 별도 제한·권한 범위를 가진 승인 경로의 차이를 번역했다. 기존 본문·canonical 계정은 유지하고 변경된 경로 설명만 덧붙였다. 후일담/인계는 특정 policy·route를 사용했다고 단정하지 않는다. 기존66필수 수집은 복귀시키지 않았다.

D04의 현재 실행 허용과 수락 당시 허용은 별도 표제이며, 업로드 수락은 실제 실행 완료로 번역하지 않았다. `quarantine_changed`는 격리 해제도 포함하는 상태 변경으로 두었다. R01의 세 inspect 구간은 기존 listing/call_graph/trace 번역을 유지한다.

최종 PASS:

- 2,574키/locale ×6 = **15,444항목**의 PO 구문·parity·보간·canonical 토큰·교육 문단·최종 source SHA·glyph 검사.
- Python 회귀27개, `git diff --check`, legacy world/source SHA 보존 확인.
- 허용된 locale 최종 검사만 별도 임시 Godot4.7 프로젝트에서 실행했다. 실제 `--editor --import` 뒤6PO를 로드하고6언어 전환, 수정5사건·격리/이력 표제·VM named 보간·canonical 계정·R3를 확인했다.
- **1,977개 고유 glyph**가 일반 UI/Mono 양쪽에서 표시 가능했고 전체 probe 실패0개다. 현재/수락 당시 허용 표제가 다르고 업로드 수락과 프로그램 실행 종료가 다른 번역임도 확인했다.

Root에 최종 native/직렬 wholeGate 가능 신호를 전달했고 이 레인의 Godot 프로세스는 모두 종료했다. 전체 게임 gate·native GUI·OS별 입력·원어민·export/배포 검증은 여전히 이 번역 레인의 증거와 구분한다. 이후 제품 변경은 추가 원문 검토가 필요할 때만 반영한다.

## 직렬 gate가 검출한 최종 사람용 원문 수정

`.omx/artifacts/integration-final-first.log`의 실패는 source SHA 보호가 마지막 문구 변경을 검출한 결과다. 이를 비활성화하지 않고 실제 원문을 대조했다. Intruder 키 수577은 같으며 변경된 기존 키는40개다.

- 15키: KO만 바뀐 provider/processor/gateway/standby 표현을 인증 서비스·처리 서비스·게이트웨이·대기 경로 등으로 정리했다. 기존4번역은 이미 해당 의미를 표현하므로 의미를 유지했다.
- 25키: M06은 설정명보다 정상 인증/반복 실패의 실제 응답을 확인하도록 수정했다. M08은 원래 폼의 Origin 검사 단정을 제거하고 계정별 nonce 검증으로 맞췄다.5개 HINT_3는 정상 요청을 대상으로 표현하고,5개 PRINCIPLE은 설계 비평 대신 현재 업무 권한과 새 경로의 재검증을 설명한다.
- 위25키 중5개 AUDIT는 기존 goal과 완전히 번역된 중립 인계문만 표시한다. 이전의 영어 canonical 기록 본문을 표시 문구에 복사하지 않는다. 팩 내부 canonical data는 그대로다.

이전 Intruder 검토 SHA는 KO `9f8ced948f473d7ded3543cf88831d345e1988e105cc5789b5b2d4cade7a3da7`, EN `a77972e1735322d24fa00920c2d890e6972f41f3f53c5d25de99771837d7fbd2`다. 최종 source SHA는 아래로 갱신했다.

| 언어 | SHA256 |
|---|---|
| KO | `12690c759065b3c21339cd1daa67490b768bccabcb5b2fc3426b461c696ddc97` |
| EN | `c63347ee0b45d41ffcf2a580000a7c80078fda6bae461ba39be0d8d9cd9a358d` |

Defender/Tracker/UI/legacy source SHA는 유지됨을 확인했다. 제품 코드·Data·UI 원문·helper는 이번 재동결에서 수정하지 않았다. Intruder 번역 원고·공유 번역 원고·source revision·6PO와 이 문서만 갱신했다.

새 revision 검증:2,574키/locale·source SHA·보간·토큰·교육 문단·CJK glyph 검사, Python27회귀, diff 검사가 PASS다. 별도 임시 프로젝트의 단일 Godot headless process에서6PO **15,444항목** 실제 ResourceLoader 로드·언어전환·VM 보간·canonical 계정·5개 AUDIT의 영어 기록 본문 제거를 확인했고 실패0개였다. 첫 임시 probe의 loop 변수 타입 추론 오류는 명시적 String으로 수정했으며, Godot exit code만 믿지 않고 유일한 성공 JSON과 Script Error 부재를 확인했다.

앞선1,977glyph/에디터 import 증거는 그 당시 revision의 기록으로 유지한다. 이번에는 새 revision의 정적 glyph 검사와 단일 PO ResourceLoader 검증을 새로 수행했다. 전체 gate/native/export/commit은 실행하지 않았으며 Root에 재동결 완료와 gate 재실행 가능 신호를 전달했다.
