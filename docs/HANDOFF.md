# 심야접속 — 다음 작업 시작점

현재 구현 상태는 [README](../README.md#현재-상태), 피드백 수용 판단은 [개정 기록](reviews/CLAUDE_FEEDBACK_RESPONSE_20261104.md)이 기준이다. 폴더·저장소 ID는 `packet-trail`을 유지한다.

## 현재 구현과 검증

`1.1.0-rc1`은 침투24메인+4선택 개선, 독립 방어8·추적8, 강화OST·6언어·안전 저장·UI/정상 종료 수리와 세OS 패키지를 완성했다. [다운로드](https://github.com/choijunhuk/packet-trail/releases/tag/v1.1.0-rc1) · [세 관점 실행 기록](implementation/2026-11-05-three-perspectives.md) · [DESIGN](../DESIGN.md) · [코어 계약](implementation/three-perspectives-contract.md).

배포 게임 소스는 `508b7e020a3dd852166aa6836fd61a4f47d59fc4`, Godot tree는 `1a864f3ae93fbbeebecd1bcfee70cb6d1b406dfc`다. [세OS CI](https://github.com/choijunhuk/packet-trail/actions/runs/42025016354)는 모두 성공했다. Mac 공개44사건·세 결말 실제 렌더/엔진 입력, Linux M01 부분 GUI, 실제3PCK·ZIP/서명/서버 해시를 구분해 기록했다. 태그·문서 마감 커밋과 게임 소스가 다르면 Godot tree 동등과 BUILD-INFO를 확인한다.

이전 [1.0 배포 기록](implementation/2026-11-05-full-production.md)과 원본 저장은 보존한다. 새 공개3편의 진도는 독립 고정 슬롯이며, 구판 진행은 동결한 콘텐츠의 별도 이어하기 사본에서 계속한다. 사람이 직접8~12h·재미·원어민 번역·물리IME·WindowsGUI·장시간 청취를 검증했다는 뜻으로 자동 통과를 확대하지 않는다.

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
