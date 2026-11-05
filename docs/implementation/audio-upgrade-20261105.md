# 강화 OST 제품 적용과 순환 경계 교정 — 2026-11-05

실제 작성·편곡·합성·검증 모델: **Codex gpt-6.1-sol / high**. 작업 트리 `packet-trail-expansion`, 브랜치 `feat/three-perspectives`, 기준 `0565166`. 원본 `packet-trail`과 승인된 OST staging은 읽기 전용으로 유지했다. 제품 버전·설정·사용자 저장·앱·릴리스·full_game 곡 매핑은 이 담당 범위에서 변경하지 않았다.

## 제품 변경

- 승인된 오리지널 dark electronic/synthwave/breakbeat 7곡과 A07 ending edit를 제품 `godot/assets/audio/music/`에 적용했다. 112~148 BPM, 킥·스네어·리듬 베이스·arp 및 16마디 break/return 편성이다. 곡 ID·파일명·기존 17~24분/곡당 2~4분 계약을 유지한다.
- `tools/generate_audio.py`에서 staging 표식과 절대 경로 의존을 제거했다. 프로젝트 상대 경로로 소스 악보·seed에서 PCM 원본과 Ogg를 다시 생성한다. NumPy/ffmpeg는 기존 도구를 사용하며 새 의존성·외부 샘플·음악 서비스를 추가하지 않았다.
- SFX 12개는 바이트·SHA256을 보존했다. 빗소리는 순환 경계 교정 때문에 다시 인코드했다. 출처·권리·파일 경로·측정·SHA256은 `godot/assets/audio/LICENSE.txt`, `manifest.json`에 기록한다.
- AudioDirector의 `ending`은 `a07_clear_channel_ending.ogg`를 **loop=false**로 한 번 재생한다. 같은 mood의 반복 요청은 종료 뒤에도 재시작하지 않는다. 다른 mood를 거쳐 다시 ending에 들어오면 새 one-shot을 재생한다. 일반 6개 mood·빗소리 반복, 두 플레이어 1.8초 crossfade, mute/focus/pause/중복 alarm 동작은 유지한다. A07 loop 파일도 자산 계약에 남긴다.

## R5 원인과 신호 설계

양끝 샘플은 같은 위상이 아니라 **주기상 한 샘플 간격**이다. 약 2.4kHz의 정상 주기 사인파도 끝→처음 차이가 1e-3보다 크다. 이 차이만으로 가청 click을 판정하면 자연 미분을 오류로 취급한다. 새로운 self-check는 이 정상 파형과 낮은 주파수 주기파를 통과시키며, 0.4 step 오염은 거부한다.

실제 codec 실험에서는 native Vorbis가 88,209 sample 입력을 88,256 sample로, 132,300 입력을 132,352로 디코드했다. 추가된 47/52 sample 때문에 원래 정상 주기파의 raw 차이 0.00561/0.00371이 encoded 약 0.052/0.051로 커졌다. 기존 25ms×2 zero fade는 이 경계 문제를 숨기면서 50ms 길이의 에너지 함몰을 만들었다.

교정은 전역 fade 제거만으로 끝내지 않았다. **실제 합성 주기 자체를 64 sample 배수로 구성**하여 native encoder의 tail padding을 없앴다. 음악의 원형 note tail·delay와 빗소리의 원형 FFT 합성을 그대로 사용한다. 박자 기준 길이와의 차이는 최대 64/44100초 미만이며, 끝에 무음 sample을 덧붙이지 않는다.

음악 7곡은 이 설계로 통과했다. 빗소리는 padding이 없어도 codec 시작 창의 곡률 검사에서 실패해, stereo 값과 기울기의 제곱합이 작은 **자연 위상으로 순환 회전**했다. offset은 1,661,036 sample이다. 샘플을 버리거나 0으로 누르지 않고 순서의 시작점만 바꾸므로 전체 RMS·원형 스펙트럼을 보존한다. one-shot의 어택·릴리스 및 A07 edit의 시작 2초/끝 14초 fade는 유지한다.

## 연속성 검사

±50ms의 인접 차이 분포에서 경계 교차 항을 제외해 q99.9를 구한다. seam 1차 차이는 `1.75×q99.9 + 4/32768`, seam 근방 2차 차이는 `1.75×q99.9 + 8/32768` 안에 들어야 한다. 뒤 항은 PCM16의 수 LSB 오차 여유다. 실제 인코드 파일을 디코드해 같은 검사를 하고, 합성/디코드 sample 수가 같아야 한다. RMS·DC·peak·무음·clipping 검사도 별도로 유지한다.

아래는 승인된 강화 staging의 zero-fade 출력과 이번 제품 출력 비교다. RMS 비율은 중앙 ±2ms RMS / 중앙 ±50ms RMS다. 현재의 넓은 대역 생산 음원에서는 `>0.10`을 fade-dip 회귀 기준으로 사용한다. 이는 모든 음악의 연속성 법칙이 아니다. self-check의 정상 1Hz 주기파는 이 비율이 0.10보다 작아도 미분 연속성 검사에 통과한다. 의도적인 seam 쉼표가 있는 새 곡은 이 생산 자산 회귀 기준을 다시 평가해야 한다.

| 루프 | fade 출력 RMS 비율 | 새 RMS 비율 | encoded seam Δ | local Δ 한계 | encoded 곡률 | local 곡률 한계 |
|---|---|---|---|---|---|---|
| A01 | 0.080487 | 1.047307 | 0.006674 | 0.068083 | 0.008794 | 0.105919 |
| A02 | 0.084737 | 1.097103 | 0.003912 | 0.064079 | 0.007393 | 0.087849 |
| A03 | 0.083755 | 1.097155 | 0.000780 | 0.072758 | 0.002675 | 0.093693 |
| A04 | 0.071098 | 0.979297 | 0.003600 | 0.076896 | 0.003933 | 0.100264 |
| A05 | 0.084194 | 1.344791 | 0.014505 | 0.055182 | 0.019297 | 0.076981 |
| A06 | 0.080214 | 1.075173 | 0.008445 | 0.057530 | 0.012116 | 0.093483 |
| A07 | 0.098660 | 1.113284 | 0.001254 | 0.055718 | 0.003045 | 0.077885 |
| ambience | 0.055105 | 0.934773 | 0.005054 | 0.029451 | 0.008094 | 0.008818 |

`builds/audio-upgrade-20261105/loop-comparison.json`에 raw master/decoded의 ±2ms·±50ms·±2초 RMS, 1/2차 미분 분포, SHA와 전후 수치를 보존했다. 같은 폴더의 `*-boundary-50ms-before/after.wav`는 경계 ±50ms, `*-boundary-2000ms-before/after.wav`는 경계 근방 ±2초의 실제 디코드 신호다. 빗소리의 전후 근방 내용 차이에는 자연 위상 회전도 포함한다.

## 자산·재현

| 곡 | BPM | 실제 decoded 길이 초 | RMS dBFS | peak dBFS |
|---|---|---|---|---|
| A01 Signal Home | 120 | 160.000000 | -20.441 | -4.041 |
| A02 First Connection | 128 | 150.000907 | -19.995 | -4.897 |
| A03 Hidden Route | 124 | 216.774240 | -19.995 | -5.054 |
| A04 Packet Flow | 136 | 197.648254 | -19.572 | -4.775 |
| A05 Raised Alert | 148 | 155.676735 | -19.009 | -5.264 |
| A06 Broken Pattern | 112 | 137.142857 | -21.408 | -6.366 |
| A07 Clear Channel | 112 | 205.714286 | -20.911 | -4.129 |

실행은 NumPy가 있는 Python과 기존 ffmpeg로 한다. runtime 게임에는 Python/NumPy가 필요하지 않다. 생성 PCM은 `builds/audio-masters/`, 진단은 `builds/audio-upgrade-20261105/`의 ignored 산출물이다. 재생산 시 ffmpeg 빌드와 Ogg serial에 따라 압축 hash는 달라질 수 있어 manifest를 함께 갱신한다. 악보·seed·합성·검사 기준은 코드에 고정돼 있다.

```sh
python tools/generate_audio.py --self-test
python tools/generate_audio.py
python tools/generate_audio.py --verify
```

## 독립 검증

- 동일 최종 AudioTests를 기준 `0565166`의 기존 제품 복사본에 실행한 RED: **123 checks, 28 failures**. 약한 원래 편곡/연속성 근거 누락과 실제 loop ending을 잡았다.
- 생성기 self-check 및 전체 21 encoded 자산 실제 디코드·SHA·peak/RMS/DC·clipping·연속성 재검사 PASS. 음악/빗소리의 decoded sample 수는 합성 주기와 같고 모든 loop period는 64 sample 배수다.
- `godot/tests/headless/test_audio_revision.gd`의 **async `run()`**: **147 checks, 0 failures**. 실제 Ogg import/길이/해시, 정상 자연 미분, 7곡 drum/BPM, 모든 loop 근거, 5 bus, fade 중간/종료/중단, 동일 mood·잘못된 mood, 중복 경보, background/pause/UI, 0/mute/NaN, 실제 ending edit·native `finished` 1회·종료 뒤 중복 요청·다른 mood 뒤 새 one-shot을 확인했다.
- ending 검사는 pause 상태를 확인하고 재개 후 끝 80ms로 실제 seek해 native 종료 신호를 기다린다. 완료 신호를 직접 emit하지 않는다. paused seek의 backend별 처리는 이 end-of-stream 검사의 전제로 삼지 않는다.
- 기존 `test_presentation.gd`는 수정하지 않았다. root wrapper는 `var result: Dictionary = await preload("res://tests/headless/test_audio_revision.gd").new().run()` 형태로 호출한다.
- 전체 프로젝트 import/gate/export는 병행 작업을 고려해 root 통합 묶음에 남겼다. 이 담당은 소유 오디오만 복사한 `builds/audio-upgrade-20261105/isolated`에서 실행했다.

**사람의 실제 청취·장시간 피로도·출력 장치/OS별 오디오 수락은 NOT_RUN**이다. 경계 통계는 신호 결함 회귀를 잡는 기준이며 가청 품질의 완전한 판정은 아니다. 사용자 저장·설정은 이 검증이 쓰지 않는다.
