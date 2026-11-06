# 심야접속 — 다음 작업 시작점

현재 구현 상태는 [README](../README.md#현재-상태), 피드백 수용 판단은 [개정 기록](reviews/CLAUDE_FEEDBACK_RESPONSE_20261104.md)이 기준이다. 폴더·저장소 ID는 `packet-trail`을 유지한다.

## 현재 구현과 검증

최신 작업은 `1.4.0-rc1` 선택 의뢰·생활 공간 확장이다. 실행 소스 `44c12d59e169d67a1ce00ffe034ecbe846dcd582`, Godot tree `6dae489404cf85350c80c4c78301e33611bb4e75`. [기록](implementation/2026-11-06-optional-living.md), [배포](https://github.com/choijunhuk/packet-trail/releases/tag/v1.4.0-rc1), [CI](https://github.com/choijunhuk/packet-trail/actions/runs/42213402265). 본편4선택/47사건/94경로는 그대로이며 I01/I02는 사건 보드의 독립 선택 의뢰다. 안뜰·배송 수령·통신함 일감·벤치·고정 데스크 장착은 별도 생활 저장을 쓴다. 전체 gate, 본편 GUI6,286/47사건/4결말, 선택·생활 GUI688, 생활1,068, 의뢰복구41, 생활UI31, 세 PCK 각564를 확인했다. 독립 코드 검토의 두 결함을 재현·수리했고 Claude 두 검토 호출은 시간 제한으로 완료 응답이 없었다.


이전 `1.3.1-rc1`은 색상 개선판이다. 공통차콜·터미널민트/도구청록/메일구리/브라우저보라/파일파랑/보드모래색을 기존위젯에연결했다. 실행소스 `6262d5aefbde1db991360f4df7993a24d4af33c8`, Godot tree `384a795fd17dfb13dc5b14bfad542c702d99ea53`. [현재배포](https://github.com/choijunhuk/packet-trail/releases/tag/v1.3.1-rc1), [기록](implementation/2026-11-06-color-refinement.md), [3OS CI](https://github.com/choijunhuk/packet-trail/actions/runs/42179897714). 전체gate/대비44/nativepreview1270·71PNG/PCK각509와Mac시작·3D이동·종료를확인했다. 아래1.3전편GUI기록은선행버전근거다.


`1.3.0-rc1`은 기존3편44사건/88해법과 v2 저장을 보존하고 별도 종합 도전3사건/6해법과 분석 작업대를 추가했다. 관찰·행동·결과, 공개기록상세·펼침상태, 현재목표이동, 안내/중요오류알림을 정리했다. [다운로드](https://github.com/choijunhuk/packet-trail/releases/tag/v1.3.0-rc1) · [실행 기록](implementation/2026-11-06-challenge-workbench.md) · [발전 계획](EVOLUTION_PLAN.md).

실행 소스 `5fe9c9c7463c5005dcb786a51f7fa15f5c60c038`, Godot tree `a73d0271ec2d158902a375c6577c7005df8c9ca5`. [CI42173382639](https://github.com/choijunhuk/packet-trail/actions/runs/42173382639)의 세OS가 모두 성공했다. 전체gate/Python51·public15,059/94경로·독립686·workbench78, 실제native6,284/47사건/4결말과preview1,237/65PNG, 세PCK각509/0을 확인했다. Linux부분GUI516/1사건/0결말은 전편GUI와 다르다. Mac 최종ZIP의4선택·4지원·취소·종료는 실제OS로 확인했으며 기존사용자파일7개와새도전slot4보호경로가 같았다. tag/문서커밋은 BUILD-INFO에서 실행소스와 구분한다.

새 challenge는 midnight_challenge@1과 challenge_01.json으로 독립된다. current_content/allowlist_policy는 새정의만 사용하는 opt-in 모델 계약이며 기존basis/통지의미를 보존했다. 재현된 파일오염 완료오판·인증탐색 복구·typed배열입력 문제는 실제RED→GREEN으로 수리했다. 새지원선호키는 구버전설정검증기에서거절될수 있고 기존캠페인호환과 별개다. 구현은 Sol6.1 high/xhigh, Astra는 통합/검증이며 같은결함반복실패로 구현을 전환한 사례는 없었다.

이전 [1.1 배포 기록](implementation/2026-11-05-three-perspectives.md)·[1.0 배포 기록](implementation/2026-11-05-full-production.md)과 원본 저장은 보존한다. 공개3편의 진도는 독립 고정 슬롯이며, 구판 진행은 동결한 콘텐츠의 별도 이어하기 사본에서 계속한다. 기존 캠페인 v2 저장 구조는 그대로다. 새 지원 선호 키를 구1.1에서 읽으면 설정이 기본값으로 보일 수 있으므로 선호 파일의 역방향 호환과 캠페인 호환을 혼동하지 않는다. 사람이 직접8~12h·재미·원어민 번역·물리IME·WindowsGUI·장시간 청취를 검증했다는 뜻으로 자동 통과를 확대하지 않는다.

사용자의 포기 메시지는 다른 작업에 보낸 오입력으로 명시적으로 철회됐다. 이번에는 중간 GREEN이나 다음 피드백 대기에서 멈추지 않고 수정·게임성 강화·확장·검증·배포를 수행했다. 후속 피드백은 재현 조건과 영향으로 판단한다.

## 유지할 계약

- 제품은 설치형 게임, 최종 목표는 작은3D 작업실+가상OS·3OS·다국어·OST·빠른첫회8시간/탐색12시간이다.
- 기본 스토리 모드에 침투·회수 성공과 행동 경보의 피드백을 둔다. 읽기·오타·일시정지로 실패시키지 않는다.
- 새 도구를 이야기에서 배우고 이전 기술과 조합하되 숙련자의 다른 유효 경로를 허용한다.
- 목표와 제약은 현재 상태로 평가한다. 특정 도구·입력·힌트·퀴즈·pin은 통과 조건이 아니다.
- 학습 미평가를 숙달로 표시하지 않는다. 전체 학습 계측은 수요가 확인된 단계에서 추가한다.
- 창 닫기와 연결 종료를 분리하고, 다중 사건부터 이월 사실/정책을 명시한다. 서로 다른 읽기 관찰이 다른 관찰을 지우지 않게 한다.
- 실패한 행동의 부분 적용·저장 손실을 막고 입력은 가상 상태에만 작용하게 한다.

캐릭터 외형·생성 프롬프트는 [CHARACTER_ART](CHARACTER_ART.md), 실제 원본4인·표정16장과 공개 조건은 [제작 기록](implementation/character-production.md)에 있다. P1 당시의 미생성 제약을 현재 전체판 상태와 혼동하지 않는다. 플레이 조작·저장·업데이트는 [실행 안내](PLAYING.md)를 따른다.

## 협업·검증

작업별 실제 모델·추론 수준과 세션별 협업 기록은 [AI_WORKFLOW](AI_WORKFLOW.md)에 남긴다.

문서 정적 검사와 게임 테스트를 구분한다. 새 판정·저장 코드는 작은 회귀 검증을 남기고, 헤드리스·실제 UI·OS·사람 플레이를 구분한다. 새 검증 결과는 [PLANNING_VALIDATION](PLANNING_VALIDATION.md)에 기록한다.
