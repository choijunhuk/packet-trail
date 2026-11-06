# 심야접속 · MidnightAccess 실행 안내

설치형 오프라인 해킹 시뮬레이터, `1.3.1-rc1`. 게임 안의 서버·웹사이트·명령어는 가상 세계에서 동작한다. 별도의 Linux·VM·Docker·실제 해킹 도구 설치가 필요하지 않다.

## 압축을 풀고 실행

ZIP 전체를 압축 해제한 뒤 `MidnightAccess/` 폴더 안에서 실행한다. 실행 파일만 다른 곳으로 옮기지 않는다.

| OS | 실행 파일 | 대상 |
|---|---|---|
| macOS | `MidnightAccess.app` | Apple Silicon / Intel Universal 2 |
| Windows | `MidnightAccess.exe` | x86_64, 같은 폴더의 `MidnightAccess.pck` 필요 |
| Linux | `MidnightAccess.x86_64` | x86_64, 같은 폴더의 `MidnightAccess.pck` 필요 |

Godot를 따로 설치할 필요는 없다. macOS 앱은 ad-hoc 서명이며 Apple 공증을 받지 않았다. Windows 실행 파일도 상용 인증서 서명 전이다. OS가 출처를 묻는 경우 내려받은 저장소·버전·체크섬을 확인한다. 보안 기능 전체를 끄는 방법은 필요하지 않다.

Linux에서 압축 해제 도구가 실행 권한을 보존하지 않았다면 해당 파일에만 실행 권한을 부여한다.

```sh
chmod +x MidnightAccess.x86_64
./MidnightAccess.x86_64
```

## 첫 실행과 조작

시작 화면의 **침투자·방어자·추적자·종합 도전** 선택 행에서 이야기와 저장 진행을 확인한다. **플레이 지원**을 선택하고 **새 게임** 또는 **계속하기**를 누른다. 새 게임 확인은 선택한 편의 슬롯과 지원을 캡처하며, 취소하면 기존 진행·선호를 바꾸지 않는다. 각 선택은 자기 안내·결말·저장을 가지며 다른 편을 먼저 끝낼 필요가 없다.

지원은 **가이드·표준·자율**의 안내/힌트량이다. 가이드는 새 의뢰와 첫 방향을 보여 주고, 표준은 필요할 때 단계 힌트를 요청하며, 자율은 자동 안내를 줄인다. 모든 수준에서 수동 도움을 사용할 수 있다. 목표·경보·허용 해법을 바꾸는 압박 난이도는 현재 구현하지 않았다. 각 편의 지원은 설정에서 따로 바꿀 수 있다.

게임 안에서는 **Midnight OS 바탕화면의 아이콘**이나 왼쪽 아래 **런처**로 앱을 연다. 런처는 앱 이름·기능을 검색할 수 있다. 작업표시줄에는 실행 중 앱만 표시되고, 전경 앱 버튼을 다시 누르면 최소화하며 다시 누르면 복원한다. 제목줄로 이동·최대화/복원·닫기, 창 모서리로 크기를 조절한다. 표준/자율은 메일·터미널·사건 보드를 한꺼번에 강제로 열지 않는다. 창을 모두 닫은 상태도 작업실 왕복 후 유지된다.

메일·사건 보드·도움말에서 목표와 도구 설명을 확인한다. 특정 힌트나 소개된 도구를 사용해야만 완료되는 구조는 아니다. 자료와 필요한 세계 상태를 만족하면 다른 유효 경로도 인정한다.

| 편 | 첫 판단과 주요 행동 |
|---|---|
| 침투자 | 거부되는 이유와 다른 접근 경로를 조사하고, 현재 권한·서비스·네트워크 경계를 확인해 필요한 자료만 회수 |
| 방어자 | 정상 업무와 의심 요청을 함께 검사하고, 정밀 정책·승인 경로·격리·부분 되돌리기로 피해를 줄이며 업무 복구 |
| 추적자 | 허가된 위치의 기록을 수집하고, 시각·출처·연결로 가설을 지원/반박하며 다음 관찰과 인계 범위를 선택 |
| 종합 도전 | 정상 업무와 접근 통제·실제 파일 갱신과 통지 범위·복합 관측과 반례를 함께 판단하는 독립3사건 |

방어편에서 모든 서비스를 끄면 정상 업무도 실패할 수 있다. 조치 전후의 실제 요청 결과를 함께 확인한다. 저장된 업로드는 **수락 당시**와 **현재**의 실행 허용을 구분하고, 격리할 때 정상 사진까지 막지 않는지 확인한다. 추적편의 **근거 부족**은 틀렸다는 판정과 다르다. 새 관측으로 가설을 바꾸는 것도 진전이며, 같은 IP 하나로 사람을 확정하지 않는다.

| 위치 | 조작 |
|---|---|
| 작업실 | WASD 이동, 마우스 오른쪽 버튼을 누른 채 시선 이동, 컴퓨터 가까이에서 E |
| 가상 OS | 아이콘/런처에서 앱 열기, F10 작업실 복귀, F1 도움말 |
| 앱 | Ctrl/Cmd + 1–9, Ctrl + Tab 창 순환, Shift를 함께 누르면 역순환 |
| 터미널 | Ctrl/Cmd + Shift + 1–4, 위/아래 기록(입력 중이면 같은 접두어만), Tab 자동완성 |
| 새 터미널 | 제목줄의 + 버튼으로 최대4개의 실제 독립 세션 창 열기 |
| Nightfox | 주소·뒤/앞·새로고침·홈, Ctrl/Cmd + T 새 탭, W 탭 닫기, L 주소 선택, Alt + ←/→ 뒤/앞, Ctrl/Cmd + R 또는 F5 새로고침(브라우저 활성 시) |
| 접근성 | F6 런처, Shift + F6 글자 크기 버튼으로 포커스 이동 |
| 일시정지 | Pause 키 또는 일시정지 버튼. Esc는 입력칸에서 입력 지우기·인증 취소를 먼저 처리 |

터미널 입력칸에서 Ctrl/Cmd + L은 출력 화면을 비운다. 위/아래 기록은 터미널마다 독립적이며, 가장 최근 기록에서 아래를 누르면 원래 작성하던 입력으로 돌아온다. 기록을 불러온 뒤 수정하면 그 입력으로 새 접두어 검색을 시작한다. 암호 입력 중에는 비밀 기록·자동완성이 동작하지 않는다. Nightfox 뒤/앞·새로고침 단축키는 암호 입력칸, 글자 조합, 확인창·일시정지 중에는 동작하지 않는다. 창을 닫는 행동과 원격 연결을 종료하는 행동은 다르다. 단축키를 OS가 먼저 처리하면 화면 버튼으로 같은 기능을 사용할 수 있다.

설정은 **플레이 지원·화면·음향·조작** 네 카테고리다. 6개 언어, 글자 크기, 전체 화면, 모션 감소, 작업실 편의 모드, 배경 재생과 음량을 조절한다. 키보드·도구·알림 소리도 별도로 조절할 수 있다. 적용하고 저장을 누르기 전에는 선호 파일을 바꾸지 않으며 취소하면 유지된다. 카테고리 헤더에도 Tab으로 이동해 방향키로 전환할 수 있다.

Nightfox는 실제 Firefox/Chrome을 실행하는 프로그램이 아니라 **게임 내부 브라우저**다. 탭8개까지 주소·이력·폼·최근 응답을 따로 보관하며, 탭 전환으로 비밀번호 입력은 지운다. 현재 요청 터미널과 과거 응답의 주체를 따로 표시한다. 과거 응답 경고는 새 주체의 권한을 준다는 뜻이 아니며 현재 결과는 새 요청으로 확인한다.

입력 중 자동 알림은 작업표시줄에 축약해 명령칸을 가리지 않는다. 알림 버튼으로 내용을 열고 다시 입력칸을 누르면 접힌다. 알림을 읽으려고 연 상태와 자동 알림을 구분한다.

## 분석 도구 작업대

관찰과 행동·결과 영역을 따로 스크롤할 수 있다. +/−가 있는 관측 구역은 펼치거나 접고, 표의 행을 선택하면 모든 공개 필드를 상세로 볼 수 있다. 도구를 실행하거나 바꿔도 사용자가 선택한 펼침 상태를 유지하며, 바뀐 기록을 이전 내용으로 표시하지 않는다. 상단 목표 버튼은 현재 사건 보드를 연다. 처음 안내 중 일반 저장 알림은 작업표시줄에 모으고, 벨을 누르면 전체 알림을 읽을 수 있다. 중요한 저장 실패는 안내 카드 옆에서도 표시된다.

종합 도전에서는 먼저 조사한 뒤 설정을 바꿔도 복구할 수 있다. 배포 파일의 실제 내용까지 확인하고, 권한만 되돌렸다고 정상 작업이 복구됐다고 가정하지 않는다. 추적 도구가 제공하는 보정된 시간 구간과 출처를 비교한다. 각 사건에는 서로 다른 유효 해법이 있으며 특정 힌트·명령을 따라 할 의무는 없다.

## 저장과 업데이트

캠페인은 자동 저장과 화면의 저장 버튼을 사용한다. 저장 실패 메시지가 보이면 성공으로 간주하지 말고 안내를 확인한다. **새 게임**은 선택한 편의 슬롯만 확인 후 교체·백업한다. 같은 실행 안에서 다른 편으로 바꾸어도 각 편의 진행과 터미널은 섞이지 않는다.

이전판 진행이 있으면 **이전판 계속**을 제공한다. 유효한 구판 진행을 검증해 별도 이어하기 사본으로 옮기고, 이후에는 그 최신 사본을 사용한다. 원본 `campaign_01.json`과 구버전 M01 `slot_01.json`은 덮어쓰지 않는다. 이어하기 사본이 손상됐을 때는 복구 선택지를 표시하며, 원본으로 몰래 돌아가 최신 진행을 숨기지 않는다. 구버전 M01 가져오기는 이전판 안의 명시적인 선택이며, 새 침투편이나 방어·추적의 완료를 만들어 주지 않는다.

저장 파일은 게임 설치 폴더와 분리돼 있다.

| OS | 사용자 데이터 폴더 |
|---|---|
| macOS | `~/Library/Application Support/MidnightAccess/` |
| Windows | `%APPDATA%/MidnightAccess/` |
| Linux | `$XDG_DATA_HOME/MidnightAccess/`, 미설정 시 `~/.local/share/MidnightAccess/` |

프로젝트의 custom user directory 설정에 따른 경로다. [Godot 데이터 경로 문서](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)의 기본 prototype 경로와 구분한다.

| 진행 | `saves/` 아래 파일 |
|---|---|
| 개선 침투자 | `intruder_v2_01.json` |
| 방어자 | `defender_01.json` |
| 추적자 | `tracker_01.json` |
| 종합 도전 | `challenge_01.json` |
| 이전판 이어하기 사본 | `legacy_continue_01.json` |
| 이전판 읽기 원본 | `campaign_01.json`, `slot_01.json` |

설정은 `settings.json`이다. 백업하려면 게임을 종료한 뒤 사용자 데이터 폴더 전체를 복사한다. 업데이트할 때는 새 배포 폴더를 사용하고 사용자 데이터는 유지한다. 동시에 여러 게임 인스턴스에서 같은 저장 슬롯에 쓰지 않는다. 이전 완료는 그때의 기록이며, 현재 사건을 다시 실험해 조건이 달라졌을 때는 현재 충족 상태와 구분해 표시한다.

기존 설정에 지원 값이 없으면 표준으로 읽는다. 설정 파일을 읽지 못했을 때 로비의 지원 선택이 원본·정상 백업을 기본값으로 덮어쓰지 않는다. 저장 실패 알림이 있어도 이번 세션의 선택은 유지되며 설정 화면에도 현재 적용값을 보여 준다.1.2.1 또는 그 이전으로 다시 내려가면 새 지원 키를 이전 설정 검증기가 거절해 기본 설정으로 표시할 수 있다. 캠페인 v2 저장과 선호 파일의 버전 호환은 다르다.

## 버전 범위

침투자 메인24·선택4, 독립 방어자8·추적자8과 종합 도전3의 공개47사건, 3D 작업실, 가상 OS, 강화 OST7큐·엔딩 편집본과 인물 초상16장을 포함한다. 이전판 이어하기는 별도 호환 경로다. 선택 R01은 작은 분기·호출 흐름을 읽고 정상 입력과 반례를 실행하는 퍼즐이며 실제 CPU나 임의 코드를 실행하지 않는다.

8–12시간은 **침투자편**의 분량 설계 목표이며 사람의 실측 결과가 아니다. 새 두 편을 그 시간에서 나누어 센 것이 아니다. 원어민 번역, 실제 OS별 IME·장치, 장시간 청취·난이도 평가는 추가 피드백 대상이다. 터미널은 게임이 지원하는 Linux식 명령 부분집합이며 실제 Linux 셸 전체를 구현하지 않는다. 일반 메모·핀은 현재 세션용이며, 추적 사건의 수집 관측·가설·인계 상태는 해당 진행에 저장된다.

## English quick start

Extract the entire ZIP, then launch the file for your OS shown above. Keep the executable and `.pck` together on Windows/Linux. Godot, Linux, containers and real security tools are not required. All targets and websites are fictional and offline.

Choose **Settings** to select English. Select **Intruder**, **Defender**, **Tracker** or **Combined Challenge**, choose assistance and then **New Game** or **Continue**. Guided/Standard/Independent change guidance, not objective or alert rules. Each story has its own onboarding, ending and save; another campaign is not required.

Open apps from desktop icons or the lower-left launcher. The taskbar contains running apps; clicking the foreground app minimizes it, and clicking again restores it. Move/resize windows and use their title controls. The + button opens another terminal, up to four. Terminal Up/Down searches history by the current draft prefix; Down past the newest match restores that draft. An empty draft recalls all history. Nightfox supports eight separate tabs and is entirely fictional/offline. Browser Ctrl/Cmd+T/W/L opens/closes tabs or selects the address; Alt+Left/Right goes back/forward, and Ctrl/Cmd+R or F5 reloads the loaded page. Navigation/reload shortcuts wait while a password field, text composition, a modal or pause is active. Recorded response identity is separate from the current request identity.

Read Mail and the Case Board; F1 opens Help, F6 focuses the launcher. In the room use WASD, hold right mouse to look, and press E near the computer. F10 returns to the room. Use the on-screen Pause button if your keyboard has no Pause key. Settings has Play, Display, Audio and Controls categories, reachable by keyboard. Input-time automatic notifications stay compact; click the notification button to inspect and return to input to fold it away.

Defenders must preserve legitimate work while containing threats. Trackers evaluate collected observations, provenance and time ranges; insufficient evidence is different from a refuted hypothesis. Tools expose structured controls and observations rather than requiring authoring JSON. Observation and action/result panes scroll independently; use the +/− section controls and select a table row for all public fields. The current-objective button opens the Case Board. Combined Challenge has its own challenge_01.json slot and authored constraints; it does not change the existing campaigns through a difficulty multiplier. Verify the actual deployment file content and compare the tool-provided corrected time intervals and provenance.

Use Save before leaving. New Game replaces only the selected campaign after confirmation and backup. Old campaign saves remain read-only sources for a separate legacy continuation copy, using the old content; old progress does not certify the new objectives. Your saves live outside the installation directory, at the OS-specific location above. Quit before backing up that folder or installing an update. Do not run multiple writers against the same save. Missing old assistance preferences default to Standard; unreadable settings are preserved during automatic lobby selection. Older binaries, including1.2.1, may reject the new challenge preference key on downgrade, independently of campaign-save compatibility.

This release candidate includes 24 main and four optional intruder cases, eight defender cases, eight tracker cases and three combined challenge cases, independent endings, six languages and seven stronger original music cues. The 8–12-hour target belongs to the intruder story and is not measured human playtime. Native-language quality, physical IME/audio-device acceptance and Windows GUI play remain separate validation work. macOS is ad-hoc signed without notarization; Windows is unsigned. Package hashes and source/build evidence accompany the release.

## 경보와 도움 수준

가이드·표준·자율은 자동 안내와 힌트의 양을 조절한다. 자율에서도 수동 도움을 요청할 수 있다. 공통 경보 수치의 상한만으로 연결이 차단되지는 않으며, 개별 서비스의 인증 제한이나 정책은 해당 응답을 확인한다. 실제 시간 제한이나 실패 조건이 다른 난이도 모드로 해석하지 않는다.
