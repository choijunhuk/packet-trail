# 오리지널 OST·효과음 제작

## 제작 계약

작성·작곡·합성 코드: Codex `gpt-6.1-sol`, high. 2026-11-05.
기준: [플랫폼·언어·음향 계획](../PLATFORMS_LANGUAGES_AUDIO.md)의 A01–A07.
제작 방식은 별도 음악 서비스 없이 작성한 음계·화성·모티프·편곡을 오프라인 가산합성한다. 기존 음악·게임 음원·샘플·녹음·타사 음악 데이터는 사용하지 않는다.

작업 범위: `tools/generate_audio.py`, `godot/assets/audio/**`, `godot/scripts/presentation/audio_director.gd`, 이 문서. 다른 작업자의 게임·방·설정·저장은 변경하지 않는다.

각 곡은 장음 패드, 낮은 베이스, 서로 다른 모티프, 순환하는 편성으로 구성한다. 조사에서는 드럼을 줄이고 경보에서는 저음과 리듬 밀도를 높인다. 연주 끝의 잔향은 곡 처음으로 감싸고 1.8초 두 플레이어 크로스페이드로 전환한다. 목표는 피로가 적은 심야 조사 분위기이며 청취 평가는 통계 검사와 별개다.

## 완성 자산

7개 오리지널 작곡, 합계 **1,191.64초 / 19분 51.64초**. A07 엔딩 편집본은 같은 작곡의 별도 편집이며 곡 수·총 작곡 길이에 중복 합산하지 않는다.

| 큐 / mood | BPM·마디 | 길이 | 압축본 peak dBFS | RMS dBFS | loop 경계 차이 |
|---|---|---|---|---|---|
| A01 Signal Home / `home` | 80·48 | 2:24.00 | -8.521 | -22.157 | 0.0009637 |
| A02 First Connection / `intro` | 84·48 | 2:17.14 | -8.823 | -22.157 | 0.0012044 |
| A03 Hidden Route / `investigate` | 76·64 | 3:22.11 | -8.812 | -22.157 | 0.0001488 |
| A04 Packet Flow / `flow` | 92·80 | 3:28.70 | -8.024 | -22.156 | 0.0003349 |
| A05 Raised Alert / `alert` | 104·64 | 2:27.69 | -7.361 | -21.410 | 0.0001997 |
| A06 Broken Pattern / `reveal` | 72·48 | 2:40.00 | -8.293 | -22.158 | 0.0007379 |
| A07 Clear Channel / `ending` | 80·64 | 3:12.00 | -8.192 | -22.157 | 0.0004806 |

음악은 `godot/assets/audio/music/`의 `a01_signal_home.ogg`부터 `a07_clear_channel.ogg`. A07 일회성 편집본은 `a07_clear_channel_ending.ogg`: 시작 2초와 끝 14초 페이드, loop 없음. 일반 `ending` mood는 반복본을 사용한다.

`godot/assets/audio/sfx/`의 12개 효과음: `click`, `key`, `hover`, `notification`, `success`, `error`, `connect`, `disconnect`, `alert`, `tool`, `save`, `window`. 모두 오리지널 음표·엔벌로프로 합성한 절제된 전자음이다. 대형 축하음·보컬·외부 녹음은 없다.

`godot/assets/audio/ambience/night_rain_air.ogg`: 48초 반복, 순환 주파수 필터로 합성한 빗소리·공기음과 부드러운 작업실 저음. 실제 장소를 녹음하지 않았다. 런타임 Ambience 재생기는 추가 −7dB로 재생한다.

배포 Ogg **9,255,531 bytes**. WAV 원본 21개는 `builds/audio-masters/`에 보존하며 총 **253,745,460 bytes**, 기존 `builds/` ignore로 배포 대상에서 제외한다. 44,100Hz·stereo·16-bit PCM 원본과 native Vorbis nominal 112kbps 배포본을 구분한다. 실제 압축률은 신호에 따라 달라진다.

## 화성·편곡

| 큐 | 작곡·연출 |
|---|---|
| A01 | D minor의 따뜻한 sus·7·9 화음, 긴 패드와 유리 같은 응답 모티프 |
| A02 | C major / A minor, 첫 접속을 안내하는 성긴 하행 음형, 타악 최소 |
| A03 | A dorian 음색, 넓은 패드와 지연된 건반, 긴 조사에 맞춘 빈 공간 |
| A04 | E minor ninths, 세 음 상승 모티프, 도구 비교를 받치는 엇갈린 약한 펄스 |
| A05 | F sharp minor, 반음 응답과 낮은 킥으로 긴장 상승, 강한 사이렌 없음 |
| A06 | B minor / G major의 모호함, 느리게 열리는 패드와 연약한 벨, 정답 단정음 없음 |
| A07 | G major ninths, 열린 높은 음역과 부드러운 귀결, 반복·크레딧 편집 분리 |

각 곡의 정확한 MIDI 음표·voicing·모티프·BPM·길이는 `manifest.json`에 저장했다. 16마디 단위로 성긴 시작→음역 확장→리듬 증가→귀환하며, 보컬 없이 낮은 배음·완만한 어택으로 구성한다. 패드와 잔향의 꼬리는 원형 버퍼로 이어지고, Vorbis padding을 고려한 25ms de-click 창으로 샘플 경계를 줄인다. 이 수치 검사는 반복 피로도나 예술적 품질의 청취 승인을 대신하지 않는다.

## 재생 API·연결 계약

`godot/scripts/presentation/audio_director.gd`를 하나의 Node로 추가한다. 저장·세계·실제 OS를 변경하지 않으며 음악·효과음 리소스만 로드한다. 외부 네트워크·명령 실행은 없다.

```gdscript
var audio = preload("res://scripts/presentation/audio_director.gd").new()
add_child(audio)
audio.configure(settings_store.get_values())
audio.set_mood("home")
settings_store.changed.connect(audio.set_volumes)
```

- `configure(settings={})`: Master/Music/SFX/UI/Ambience 버스와 두 음악 재생기 생성, 설정 적용. 자동 재생하지 않는다. 버스가 이미 있으면 재사용한다.
- `set_mood("home"|"intro"|"investigate"|"flow"|"alert"|"reveal"|"ending")`: 루프 곡으로 1.8초 crossfade. 같은 mood 재요청은 재시작하지 않고, 전환 중 새 요청은 더 조용한 재생기를 재사용한다. 알 수 없는 mood는 무시한다. 첫 mood부터 환경음도 반복한다.
- `set_volumes(settings)`: 0~1 선형 `master_volume`, `music_volume`, `sfx_volume`, `ui_volume`, `ambience_volume`; 유한 숫자만 받고 범위를 고정한다. 선택 `keyboard_volume`, `tool_volume`, `notification_volume`은 해당 효과음에 추가 배율로 적용한다. `mute`가 있으면 Master mute를 적용한다. `background_audio`로 비활성 창 정책을 바꾼다. 설정 저장은 외부 settings_store가 담당한다.
- `play_ui(event)`: 위 12개 이벤트. `alarm→alert`, `open/close/window_open/window_close→window`, `complete→success` 별칭. key/hover는 70ms, 나머지는 35ms 간격 제한. 경보는 하나만 재생한다. UI 버스는 click/key/hover/window, SFX 버스는 나머지다.
- `set_background_active(active)`: 기본 `background_audio=false`이면 비활성에서 재생 위치를 보존하며 정지하고 새 효과음을 억제한다. 복귀하면 이어 재생한다. 실제 포커스 신호 연결은 main 소유자가 담당한다.
- `set_paused(paused)`: 음악·환경음·SFX 정지, 정지 메뉴의 UI 피드백은 유지한다. PROCESS_MODE_ALWAYS로 scene tree pause 중에도 메뉴 피드백이 가능하다.

어떤 함수도 게임 시작·저장·실제 경보 의미를 판단하지 않는다. 경보/발견/완료 이벤트를 화면 텍스트로 알리는 책임과 mood 선택은 main/campaign 소유자에게 있다. `reduced_motion`은 소리를 바꾸지 않는다. 최종 출력 장치 전환은 Godot 기본 장치 정책을 사용한다.

공식 API 확인: [AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html), [AudioStreamOggVorbis](https://docs.godotengine.org/en/stable/classes/class_audiostreamoggvorbis.html). 새 오디오 미들웨어·플러그인·패키지를 설치하지 않았다.

## 재현·검증

이미 설치된 NumPy 2.5.4 환경과 ffmpeg를 사용했다. 기본 python3에는 NumPy가 없어 새 설치 대신 기존 실행기를 사용했다. 아래 경로는 이 개발 컴퓨터의 실행 환경이며 게임 런타임 의존성이 아니다.

```sh
/Users/choi/.codex/tools/venvs/qdrant/bin/python tools/generate_audio.py
/Users/choi/.codex/tools/venvs/qdrant/bin/python tools/generate_audio.py --self-test
/Users/choi/.codex/tools/venvs/qdrant/bin/python tools/generate_audio.py --verify
```

생성기는 고정 seed·명시적 악보로 재현한다. ffmpeg 버전과 Ogg serial에 따라 압축 파일 해시는 달라질 수 있어 재생산 때 `manifest.json`을 함께 갱신한다. WAV 음악·편성은 고정되어 있다. 완성 Ogg는 stage 파일 검증 후 교체하므로 편집기에서 반쯤 생성된 파일을 읽는 상황을 줄인다.

- **PASS**: 주파수 조율·엔벌로프·원형 꼬리·7곡 길이와 전체 길이·무음/클리핑/불연속 거부 self-check.
- **PASS**: 21개 배포 파일 전체 SHA256·실제 ffmpeg 디코드·peak/RMS/DC·유한 값·clipping·무음·loop seam 검사. 7곡+환경음의 1초 단위 무음 0, clipping 0, 최대 loop 경계 차이 0.0012044. 음악 RMS 약 −22.16dBFS, A05 약 −21.41dBFS. 측정 상세는 `manifest.json`.
- **PASS**: Godot 4.7 `audio_director.gd --check-only` 및 Python compile.
- **PASS**: 분리된 `builds/audio-masters/runtime-check` 프로젝트에서 AudioDirector 39개 검사: 설정 시 무재생, 5버스, 선형 음량, 2-player 중간값/종료/중단 전환, 같은 mood 재요청, 잘못된 mood 무시, 경보 중복 억제, 비활성 정책·복귀, pause/UI, mute/0/범위/NaN 처리, 12효과음 로드, 키/도구/알림 개별 음량. 실제 오디오 frame을 진행한 후 종료했으며 최종 로그에 ERROR/누수 없음. 검증 script와 결과는 같은 ignored 폴더의 `verify.gd`, `result.log`에 보존한다.
- **PASS**: 소유 파일 `git diff --check`.

첫 압축 시 A03의 Vorbis padding으로 loop 경계 검사가 실패해 25ms de-click 창을 적용하고 전곡을 재생성했다. 분리 테스트의 첫 동시 복사도 생성 중인 파일을 읽어 실패했으며, 생성 완료 후 복사·import를 순차 처리해 해결했다. 파일 검증·통합 검증·청취를 구분한다.

## 출처·배포·검증 한계

`godot/assets/audio/LICENSE.txt`에 프로젝트용 제작·수정·상업 배포 범위와 외부 공개 asset 라이선스를 별도로 부여하지 않았음을 기록했다. 모든 자산은 프로젝트를 위해 새로 작성한 음표·화성·합성 신호이며 기존 게임/음악/샘플을 복제하지 않았다. AI 산출물의 저작권 보호를 모든 지역에서 보장한다는 주장도 하지 않는다. 라이선스·제작자·점검 수치·경로·SHA256은 배포 Ogg와 함께 남긴다.

**NOT_RUN**: 사람의 실제 청취·장시간 피로도·출력 장치 교체·3OS 실재생·전체 게임 연결·export/배포. 이 담당 범위에서는 전체 프로젝트 gate와 다른 작업자의 씬을 실행하지 않았다. 최종 믹스·기기 음량과 긴장 큐의 체감은 리더의 렌더/실재생 및 사람 피드백으로 확인해야 한다.
