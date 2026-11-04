# Hacknet·해킹 시뮬레이터 조사와 제작 권고

조사일: 2026-11-04. 공개 자료, 사용자 제공 정적 분석, 제한적인 설치본 식별 대조, 새 설계 추론을 구분한다. 현재 제품/구현 상태는 [README](../README.md#현재-상태)에 모은다.

## 결론

**심야접속은 Godot 4+GDScript의 작은 3D 작업실+가상 OS를 최종 형태로 삼되, P0/P1은 2D OS와 한 회수 의뢰부터 만든다.** 컴퓨터를 사용하면 화면 전체를 쓰는 2D 데스크톱으로 전환한다. 네트워크 침투 사건을 이야기의 뼈대로 삼고, 터미널·가상 브라우저·도구가 같은 상태를 조작하게 한다.

제작 순서는 ‘개발 OS 입력 검증 → 한 침투/회수 사건 완주 → 3미션·3D 회색상자·초기 플랫폼 시험 → 미션 팩 확장’이다. 아래 자료가 도구 기능과 선례를 제공하지만 이 게임의 개발 기간이나 재미를 보장하지는 않는다.

## 1. Hacknet은 무엇을 어떻게 공개했는가

| 근거 | 확인한 내용 | 해석의 한계 |
|---|---|---|
| [공식 사이트](https://hacknet-os.com/) | 터미널 중심 진행과 일관된 내부 네트워크 시뮬레이션 | 실제 OS·실전 교육 효과의 증거는 아님 |
| [공식 Extensions 가이드](https://steamcommunity.com/sharedfiles/filedetails/?id=914587661) | 컴퓨터·파일·포트·daemon·목표·분기·웹페이지·검증/디버그를 콘텐츠로 정의 | 확장 인터페이스이며 모든 내부 클래스를 공개한 자료는 아님 |
| [개발자 지원 글](https://steamcommunity.com/app/365450/discussions/0/451850849198782888/) | Windows XNA 분기와 웹 렌더러 호환성 문제를 설명 | 모든 플랫폼·시기의 구성은 이 글만으로 확정 못 함 |
| [포팅 담당 Ethan Lee의 포트폴리오](https://www.flibitijibibo.com/index.php?page=Portfolio%2FTools) | FNA 적용 게임 목록에 Hacknet 포함 | MonoGame 사용 근거로 바꾸어 인용하면 안 됨 |
| [퍼블리셔 press kit](https://www.fellowtravellerpresskit.com/hacknet) | 터미널·가상 세계·메일 단서, 개발자의 C#/custom-engine 경력 | 경력 소개만으로 프로젝트 전체 언어·엔진을 단정 못 함 |
| [Matt Trobbiani 직접 인터뷰](https://geekoutsw.wordpress.com/2016/05/18/hacknet-developer-interview/) | 게임잼 출발, 직접 만든 UI, 장기간 개발 회고 | 개발자 직접 발언이지만 매체 인터뷰. 우리 일정의 근거가 아님 |

**공개 자료의 기술 판단:** XNA/FNA 계열 사용 근거가 있다. 사용자가 추가 제공한 설치본 정적 보고서는 Mono 런처와 FNA 참조 관리형 게임 어셈블리, XML 노드/미션/저장 구조를 설명한다. 실행 파일 크기·해시·plist·주요 경로는 제한적으로 대조해 일치를 확인했다. IL 의미·참조 버전·전체 파일 수는 보고서의 관찰로 구분한다. [패키지 참고 기록](references/HACKNET_PACKAGE_NOTES_20261104.md)

MonoGame 사용이나 원본 C# 프로젝트 확보를 이 근거에서 도출하지 않는다. 원작을 실행하거나 비공식 디컴파일 저장소를 사용하지 않았다.

공개 콘텐츠 구조에서 얻을 핵심은 세 가지다.

1. 컴퓨터는 주소만 있는 점이 아니라 파일·계정·서비스·보안·연결을 가진 객체다.
2. 미션은 시스템의 변화와 사실을 판정하며, 파일·웹사이트·메일이 다음 조사의 근거가 된다.
3. 검증·빠른 재시작·디버그 기능을 콘텐츠 제작 과정에 포함한다.

Hacknet의 필요한 포트 개수와 `PortHack` 규칙은 게임적 추상화다. 실제 서비스 취약점·메모리 손상 분석과 같은 것으로 가르치지 않는다. 메모리 분석 요소가 있다는 사실도 모든 게임플레이가 실제 리버싱이라는 뜻은 아니다.

## 2. 여러 게임에서 가져올 원리

| 게임·공식 자료 | 확인된 특징 | 가져올 것 | 초기 범위에서 제외할 것 |
|---|---|---|---|
| [Anonymous Hacker Simulator](https://store.steampowered.com/app/2487060/) | 아파트 거점, 간소화한 도구, 음모 서사, 도구 해금 | 공간에 들어와 컴퓨터로 사건을 시작하는 몰입감 | 여러 주거지·생활 시뮬레이션 |
| [Grey Hack](https://store.steampowered.com/app/605230/Grey_Hack/?l=english) | 터미널·파일·도구·UNIX 계열 명령, 스크립트, 네트워크 샌드박스 | 같은 상태를 여러 도구로 조작하는 자유 | MMO·무한 절차 생성·새 범용 언어 |
| [Hacknet](https://store.steampowered.com/app/365450/Hacknet/?l=english) | 메일·파일 단서·가상 세계·도구 확장·OST | 행동으로 이야기의 진실을 알아내는 흐름 | 원작의 자산·문장·사건 복제 |
| [NITE Team 4](https://store.steampowered.com/app/544390/) | 도구·정찰·포렌식 Boot Camp와 캠페인 | 안내받은 연습을 실제 사건에 재사용 | 현실 웹 ARG·실시간 운영 의뢰 |

상점 설명은 개발사·퍼블리셔의 제품 설명이다. 교육 효과·사용자 만족도의 검증 자료로 취급하지 않는다. 각 게임의 엔진은 추가 원저자 근거 없이 추측하지 않는다.

**설계 추론:** 공간 몰입감은 Anonymous, 도구와 상태의 일관성은 Grey Hack, 서사는 Hacknet, 단계적 학습은 NITE의 장점을 조합한다. 네 게임의 전체 분량을 합치는 것이 목표가 아니다.

## 3. 새 게임의 엔진 선택

| 선택지 | 적합한 점 | 비용·판단 |
|---|---|---|
| Godot 4+GDScript | 3D 방과 2D GUI를 같은 프로젝트로 구성, 내장 UI·오디오·번역·PC export | 권고. IME·창 포커스·3OS 실제 실행을 먼저 검증 |
| Unity+C# | 풍부한 3D 제작·배포 생태계 | 가능하지만 작은 방과 데스크톱 UI에 필요한 최소 구성보다 관리 범위가 커질 수 있음. 현재는 도입하지 않음 |
| C#+XNA/FNA 계열 | Hacknet 선례, 직접 UI·렌더 제어 | 프레임워크 선례를 재현하는 것보다 게임 콘텐츠와 입력 검증에 투자하는 편을 권고 |
| 웹 DOM+TypeScript | 텍스트·폼 중심 UI의 검증 속도 | 사용자의 설치형 게임·3D 공간 방향에 따라 본편 후보에서 제외 |

이 표는 비교 실험의 실측치가 아니라 요구와 도구 기능에 따른 판단이다. 이미 설치된 Godot는 `4.7.stable`로 확인했다. 구현 시작 시 공식 안정판·내보내기 템플릿을 같은 버전으로 고정한다. 이번 기획 작업에서 엔진 설치·업그레이드는 하지 않았다.

관련 기능: [Control](https://docs.godotengine.org/en/stable/classes/class_control.html), [Window](https://docs.godotengine.org/en/stable/classes/class_window.html), [LineEdit](https://docs.godotengine.org/en/stable/classes/class_lineedit.html), [RichTextLabel](https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html).

## 4. 가상 브라우저와 OS를 싸게 만드는 방법

게임 속 브라우저는 주소창·검색·뒤로/앞으로·링크·탭·폼·로그인을 제공한다. 주소는 내부 라우터에서 페이지·서비스 데이터로 해석한다. 본문·이미지·링크는 RichTextLabel/Control로 렌더링한다. **RichTextLabel은 HTML/CSS 브라우저가 아니다.** 페이지 블록 계약으로 필요한 표현만 만든다.

일반 웹뷰·Chromium·외부 JavaScript 엔진을 넣으면 웹 호환성·배포·입력·보안 경계까지 검증해야 한다. 처음에는 내부 페이지 렌더러로 조사의 재미를 검증한다. 이는 Hacknet의 웹 렌더러 구현을 그대로 복사하는 안이 아니다.

창 관리도 우선 내장 임베디드 Window를 검증한다. 이동·크기·포커스·닫기·재열기를 재사용하고, 필요한 조작감이 나오지 않을 때 Control 창틀로 바꾼다. 처음부터 운영체제급 윈도 매니저를 만들지 않는다.

`.test`는 테스트용 예약 도메인이다. **그 자체가 통신 차단 장치는 아니다.** 게임이 내부 주소표만 조회해야 한다. [RFC 2606](https://www.rfc-editor.org/rfc/rfc2606.html)

## 5. 콘텐츠·학습 제작 효율

미션 데이터에 초기 월드, 사건 목표, 제약, 단서, 힌트, 후일담, 학습 메모를 넣는다. 첫 미션을 완주한 뒤 공통 구조를 추출한다. 모든 미래 기법을 지원하는 범용 DSL부터 만들지 않는다.

도구 설명은 ‘처음 배우기→같은 원리 재사용→다른 도구와 조합→도구를 스스로 선택’으로 줄어든다. [PortSwigger 학습 경로](https://portswigger.net/web-security/learning-paths), [Bandit](https://overthewire.org/wargames/bandit/)의 단계적 구성을 참고한다. 기존 문제를 복제하거나 공식 교육과정과 동일하다고 주장하지 않는다.

판정은 결과와 제약 중심이다. 새 도구를 쓰지 않아도 유효하게 사건을 해결하면 통과한다. 학습 목표를 경험하지 않았다면 해당 기술은 미평가로 남기고 선택 연습을 제안한다. 강제로 도구를 실행시켜 학습 체크를 채우지 않는다.

선택 복습에서 다루는 기술 정의·근거·영향·완화의 정확성은 [OWASP WSTG](https://owasp.org/www-project-web-security-testing-guide/)를 기준 자료로 삼는다. 사고 흐름과 분야 범위 판단은 [DOMAIN_SCOPE.md](DOMAIN_SCOPE.md)에 따로 정리한다.

## 6. 이번에 효율을 위해 생략한 것

실제 VM·Docker·실제 외부 공격, MMORPG·경제 서버, 무한 사건 생성, 풀 3D 도시, 범용 스크립트/디컴파일러, 런타임 LLM NPC, 커스텀 콘텐츠 에디터, 웹·네이티브 이중 구현은 초기 제작 대상이 아니다.

플레이어가 요청·명령 조합을 저장하고 다시 쓰는 정도로 자동화의 재미를 먼저 제공한다. 새 기능은 실제로 서로 다른 미션 두 개가 필요로 할 때 공통화한다.

## 7. 다음 검증

공개 선례나 패키지 식별은 새 게임의 재미·입력감·배포 품질을 증명하지 않는다. [개발 계획](ROADMAP_AND_QA.md)의 단계별 검증으로 판단한다.
