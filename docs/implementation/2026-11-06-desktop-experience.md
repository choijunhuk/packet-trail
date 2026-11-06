# 1.2 데스크톱·첫 플레이 개선 실행

상태: 구현 중. 사용자1.1 UI 피드백을 실제 동작과 대조하고 수정한다. 이후 완료·배포는 마지막 절에만 기록한다.

## 현재 사실

시작 메뉴·세 공개 캠페인 선택·일반 설정15개는 구현됐다. 난이도/지원 선택과 브라우저 탭은 없다. 앱을 모두 닫은 재개에서도 메일/보드/터미널을 자동으로 다시 여는 동작과 모든 앱의 텍스트 작업표시줄이 OS 경험을 방해한다. 기존 판정·저장·앱 기능의 자동 통과와 사람의 UI 품질 평가는 다른 주장이다.

기준 main/tagb4ef8ce, 기존 실행소스508b7e0. 별도 worktree packet-trail-desktop / feat/desktop-experience. 원본.serena/사용자진행/1.1출시물은 보존한다.

## 설계 선택과 대안

사용자가 든 Windows/Kali를 참고해 짙은 Midnight OS 바탕화면과 익숙한 런처/작업표시줄/창을 택한다. 이는 제작자 권고다. 원래 패널의 색만 바꾸는 방안은 앱 발견/초기 동작을 고치지 못한다. 진짜 OS·CEF/브라우저를 내장하는 방안은 가상 상태를 분리하고 설치/외부 효과를 늘리므로 이번 계약에 맞지 않는다.

지원은 가이드/표준/자율의 도움 강도다. 실제 판정·경보·허용 해법·저장 세계를 변경하지 않으며 이를 hard mode라고 부르지 않는다. per-pack settings scalar enum은 구판 save를 변경하지 않고 표시 선호를 보존한다. 실제압박 난이도는 별도 결정으로 남긴다.

## 구현 범위·소유

1. 공통 Theme·시작/시나리오/지원·설정 UI/연결·문서/버전/CI는Root.
2. CampaignDesktop shell·아이콘/벽지·창·작업표시줄·탭 브라우저·사람용 목표 표시는UI소유.
3. SettingsStore의지원enum·안전한test경로주입과회귀는설정소유. core/mission/save판정은무수정.
4. 원문동결뒤6언어/검토SHA·키 검사는locale소유.
5. 초기desktop/런처/창/브라우저/시나리오/지원/설정·기존auth/save보존은분리QA/native소유.

서로의 파일을 되돌리지 않는다. UI KO/EN키는레인별 .omx/artifacts/desktop-copy/*.json에모아locale소유만합친다. 실행/import/native/export는source프로젝트별로직렬화한다.

## 회귀·수락 형태

- 기존 whole gate/88해법/legacy/저장·인증·UI문맥·오디오·정상종료를 보존한다.
- 첫 시나리오/지원의 실제 선택·취소·저장 후 재시작, 지원 설정만 바뀌고 세계/목표가 같음을 확인한다.
- 빈바탕화면/수동앱 실행/모두닫기후재개, 작업표시줄 전경·최소화·복원, 창드래그/크기/최대화와 네터미널 초안/세션을 확인한다.
- 탭별주소·이력·폼/결과, 내부링크·로그인·접근거절·터미널 주체 경계를 확인한다. 실제외부웹은열지않는다.
- 설정카테고리/실제값·적용/취소·키보드·언어/큰글씨·1280/1600에서필수조작을검증한다.
- 앱버튼신호직접emit/목표flag주입으로native성공을대체하지않는다. 메타데이터 선택은setup,활성화는실제engine InputEvent로구분한다.
- 기존v2와oldprefs누락지원값을읽는다. 테스트설정/캠페인은user://tests만쓰며원본설정/저장을SHA보호한다.
- 최종원본소스·실PCK/ZIP/서명·3OSCI·비공개RC·main/태그를대조한다. physicalOS/사람평가는별도다.

## 모델과 검토

기존Codex6.1 high/xhigh 세션을 소유에 맞게 재사용한다. Claude는필요한큰수정묶음의읽기전용최종검토만쓴다. 요청/실제응답/수준/범위는AI_WORKFLOW에기록한다. 웹용디자인탐지기가GodotControl을발견하지못하는것을UI없음/검증완료의근거로쓰지않고실제native렌더를본다.

## 최종 완료

아직 미완료. 실제구현/검증/배포뒤갱신한다.

## 첫 구현과 실제 검증 기록

- 기존 1.1은 일반 설정15개가 실제 동작했지만 지원 수준과 브라우저 탭은 없었다. 초기에 기능·시작 경험·시각 품질을 한 완료 주장으로 묶지 않는다.
- 세 편별 지원 선호3개는 SettingsStore에만 넣고 누락된 예전 선호를 표준으로 읽는다. 생성자 test-path와 sidecar/부모 링크 경계를 검사했다. clean RED4검사/3실패 → GREEN340/0/0skip, 기본28경로·v2/hint/목표/경보 불변이다. 구1.1 바이너리의 새 prefs 키 해석과 다중 프로세스 prefs 쓰기는 별도 한계다.
- 브라우저의 자료 회수 주체가 UI의 이전 호출 순서에 의존하지 않도록 `browse(url, terminal_id=0)`·`collect_web(url, terminal_id=-1)`를 보완했다. 무인자는 기존 의미를 유지한다. Runtime/판정/저장 스키마를 바꾸지 않고 clean RED13/2 → GREEN160/0으로 단말·권한·쿠키·예산을 검사했다.
- Root의 시작 화면은 시나리오 선택 행·고정 지원 선택·계속/새 게임을 제공하고 설정은 플레이/화면/음향/조작으로 나눴다. 테스트 FullGame의 캠페인 base에서 고유 prefs 경로도 파생해 실제 설정 파일을 쓰지 않는다.
- 직접 작성 SVG31개와 새72 UI키를 사용한다. KOEN723키, 전체6PO2,646×6=15,876,27회귀·source SHA·보간·token·실제6locale/1,989glyph 검사가 통과했다. 원어민·GUI 번역 검증과 resource-load 검사는 다르다.
- 첫 native preview는 실제 M01 1/44·세 편 선택·설정4탭·바탕/런처/터미널/2탭·29PNG였다.570/15실패에서 창 닫기 순서를 전경부터 처리하고 격리 prefs 신호 경로로 바꾸니591/1실패였다. 기본30경로/생산65SHA 불변·engine error/warning0이다. 남은 실제 회귀는 F10→Continue 뒤 입력 포커스가 런처로 이동한 것이다.
- Root는 settings signal의 수신 값을 보존하도록 presentation_settings(base_values)를 연결했다. 저장 Store만 다시 읽어 일시적인 UI값을 놓치는 의존을 제거했다.
- 새context Codex6.1/high가 실제35PNG와 source를 읽고84/fix를 반환했다. OS 구조는 요구에 맞지만 과거 응답 경고의10px 열, 제목/버튼을 덮는 toast, locale 전환 후 남은 transient가 material/low findings다. 수리 후 동일 viewports·같은 reviewer가 확인하며 자기 점수만으로 완료시키지 않는다.

이 절의 수치·첫 실패는 최종 완료 판정이 아니다. CUA는 오늘도 native host/pipe가 이용 불가여서 실제 OS 입력은 별도 NOT_RUN이다.

## C23 읽기 전용 검토와 후속 재현

로컬 Claude CLI2.1.311에293,987문자 고정 source/diff·새 회귀를 전달했다. 요청/실제 modelUsage 모두 `claude-opus-5-5`, effort `high`,375.486초·exit0·is_error=false·permission_denials=[]였다. safe-mode/restricted/tools빈목록·strict empty MCP·noChrome/noPersistence로 모델은 파일을 읽거나 바꾸지 않았고 제공한 본문만 검토했다. 결과는 정적 REVISE C0/I0/M3이며 실행 재현으로 주장하지 않는다. 원문·SHA·argv·완료 metadata는 `.omx/artifacts/desktop-advisor/`와 ask-claude Markdown에 있다.

- M1/M3: 손상/새버전 선호의 자동 기본값 덮어쓰기와 ephemeral 지원의 Panel/타편 저장 회귀는 실제101/10 RED로 확인했다. 원본/backup 보존·effective initialvalues 수리 뒤101/0. 카테고리 Tab keyboard 누락 질문도 실제102/1 RED에서수리해최종103/0으로통과했다.
- M2: 제목줄 최대화 pointer 클릭 후 focus가버튼에남아 문자/Space/Enter 의미가바뀌는실제12/4 RED를수리했다. pointer 뒤정확한입력복귀와FOCUS_ALL의명시keyboard버튼동작을함께보존해12/0으로통과했다.
- 독립pixel수정확인89/fix에서 남았던 최대화Terminal입력 위 toast는 자동알림을기존taskbar로축약하고명시열기/편집재진입을분리해표적13/0으로수리했다. 최종실제InputEvent bell/typing·픽셀수락은새native와review에서확인한다.

서버 재시작 뒤 네이티브 CUA host가 복구돼 inventory를 실제 확인했다. 이전 host unavailable 기록은 당시 한계이며, 최종 배포 앱의 실제 OS 수락은 패키지 검증 후 별도로 수행한다.

## 최종 소스 통합 검증

모든 실제 수리 뒤 `.omx/artifacts/desktop-experience/whole-gate-final.log`는 실제 종료0,130.722초였다. 기존331파일 SHA는 같고 editor가 새 lobby 테스트/runner의 UID2개를 생성해333파일이 됐다. 소스 프로젝트의 import/native/export를 병행하지 않았다.

| 검사 | 실제 결과 |
|---|---|
| 기존 content/첫 실행·저장/campaign 콘텐츠 | 3 / 336 / 81, 실패0 |
| 보존 캠페인/공개3편 | 31,717 / 14,110검사·88해법, 실패0 |
| presentation/audio/UI문맥/초상 | 275 / 147 / 37 / 36, 실패0 |
| 새 browser actor/지원prefs/desktop기능/lobby보존 | 414 / 340 / 141 / 103, 실패0 |
| mutation/정상종료 menu·WM | 1,217 / 8·6, 실패0 |
| Python/실행 경계 | 49테스트·자체5·runtime25스크립트 PASS |
| 최종 desktop preview | 824/0·11.430초·M01 1/44·세 role·45PNG·43reachability. 실제Source74/기본30 보존 |
| 최종 새UI 전편 native | 5,435/0·86.371초·44/44·세 결말·347fixture행동·47암호·195기본폼Run·41PNG. source74/기본30/preview45 보존·engine error/warning0 |
| 독립 UX 수정 확인 | ship93/100(qualitative scope). V1/V2/V3 해결,45PNG 해시/74소스 대조·26이미지 직접검토 |

Native window/PNG1280×720과 font1.6은 실제다. 프로젝트의 고정 logical canvas1600×900을 축소한 출력이며1280 logical reflow나 물리IME 성공으로 바꾸지 않는다. 전체 native는 A경로44건이며 B해법은 headless에서 검증한다. 이 절은 소스 완료 증거이고 실제3OS export·ZIP·서명·CI·최종 추출 OS 수락은 후속 배포 절에 기록한다.
