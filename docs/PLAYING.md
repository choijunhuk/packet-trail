# 심야접속 · MidnightAccess 실행 안내

설치형 오프라인 해킹 시뮬레이터, `1.0.0-rc1`. 게임 안의 서버·웹사이트·명령어는 가상 세계에서 동작한다. 별도의 Linux·VM·Docker·실제 해킹 도구 설치가 필요하지 않다.

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

메뉴의 **새 게임**으로 시작하면 첫 의뢰와 가상 OS가 열린다. 메일·사건 보드·도움말에서 목표와 도구 설명을 확인한다. 특정 힌트나 소개된 도구를 사용해야만 완료되는 구조는 아니다. 자료와 필요한 세계 상태를 만족하면 다른 유효 경로도 인정한다.

| 위치 | 조작 |
|---|---|
| 작업실 | WASD 이동, 마우스 오른쪽 버튼을 누른 채 시선 이동, 컴퓨터 가까이에서 E |
| 가상 OS | F10으로 작업실 복귀, F1 도움말 |
| 앱 | Ctrl/Cmd + 1–9, Ctrl/Cmd + Tab으로 창 순환 |
| 터미널 | Ctrl/Cmd + Shift + 1–4, 위/아래 기록, Tab 자동완성 |
| 접근성 | F6 작업 표시줄, Shift + F6 상단 글자 크기 버튼으로 포커스 이동 |
| 일시정지 | Pause 키 또는 일시정지 버튼. Esc는 입력칸에서 입력 지우기·인증 취소를 먼저 처리 |

터미널 입력칸에서 Ctrl/Cmd + L은 출력 화면을 비운다. 암호 입력 중에는 비밀 기록·자동완성이 동작하지 않는다. 창을 닫는 행동과 원격 연결을 종료하는 행동은 다르다. 단축키를 OS가 먼저 처리하면 화면 버튼으로 같은 기능을 사용할 수 있다.

설정에서 6개 언어, 글자 크기, 전체 화면, 모션 감소, 작업실 편의 모드, 배경 재생과 음량을 조절한다. 키보드·도구·알림 소리도 별도로 조절할 수 있다. 한국어·영어·일본어·간체 중국어·스페인어·독일어 번역이 포함돼 있다.

## 저장과 업데이트

캠페인은 자동 저장과 화면의 저장 버튼을 사용한다. 저장 실패 메시지가 보이면 성공으로 간주하지 말고 안내를 확인한다. **새 게임**과 **구버전 M01 가져오기**는 확인창을 거쳐 현재 캠페인 슬롯을 교체하고 기존 진행을 백업한다. 구버전 M01 원본은 유지된다.

저장 파일은 게임 설치 폴더와 분리돼 있다.

| OS | 사용자 데이터 폴더 |
|---|---|
| macOS | `~/Library/Application Support/MidnightAccess/` |
| Windows | `%APPDATA%/MidnightAccess/` |
| Linux | `$XDG_DATA_HOME/MidnightAccess/`, 미설정 시 `~/.local/share/MidnightAccess/` |

프로젝트의 custom user directory 설정에 따른 경로다. [Godot 데이터 경로 문서](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)의 기본 prototype 경로와 구분한다.

진행은 `saves/campaign_01.json`, 설정은 `settings.json`, 구버전은 `saves/slot_01.json`이다. 백업하려면 게임을 종료한 뒤 사용자 데이터 폴더 전체를 복사한다. 업데이트할 때는 새 배포 폴더를 사용하고 사용자 데이터는 유지한다. 동시에 여러 게임 인스턴스에서 같은 저장 슬롯에 쓰지 않는다.

## 버전 범위

메인24·선택4 사건과 결말3개, 3D 작업실, 가상 OS, OST7큐와 인물 초상16장을 포함한다. 방어자·추적자 이야기는 별도 후속 캠페인 기획이다. 이번 버전에 포함된 이야기로 표시하지 않는다.

8–12시간은 분량 설계 목표이며 사람의 실측 결과가 아니다. 원어민 번역, 실제 OS별 IME·장치, 장시간 청취·난이도 평가는 추가 피드백 대상이다. 터미널은 게임이 지원하는 Linux식 명령 부분집합이며 실제 Linux 셸 전체를 구현하지 않는다. 메모·핀은 현재 세션용이다.

## English quick start

Extract the entire ZIP, then launch the file for your OS shown above. Keep the executable and `.pck` together on Windows/Linux. Godot, Linux, containers and real security tools are not required. All targets and websites are fictional and offline.

Choose **Settings** to select English, then **New Game**. Read Mail and the Case Board; F1 opens Help. In the room use WASD, hold right mouse to look, and press E near the computer. F10 returns to the room. Use the on-screen Pause button if your keyboard has no Pause key.

Use Save before leaving. New Game and legacy import require confirmation and replace the current campaign after preserving a backup. Your saves live outside the installation directory, at the OS-specific location above. Quit before backing up that folder or installing an update. Do not run multiple writers against the same save.

This release candidate includes 24 main and four optional cases, three endings, six languages and seven original music cues. Human pacing, native-language quality, physical IME/audio-device acceptance and Windows GUI play remain separate validation work. macOS is ad-hoc signed without notarization; Windows is unsigned. Package hashes and source/build evidence accompany the release.
