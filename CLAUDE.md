# 심야접속 / packet-trail 협업 계약

[AGENTS.md](AGENTS.md)와 [PROJECT_PLAN.md](PROJECT_PLAN.md)를 따른다. 현재 상태는 README에 모은다. 현재 과제가 파일 기반 피드백 개정이면 새 CLI 호출이나 게임 코드 구현으로 범위를 늘리지 않는다. 이후 Claude 자문은 사용자 지시와 주어진 소유 범위 안에서 수행한다.

모델·추론 수준은 [AI_WORKFLOW](docs/AI_WORKFLOW.md)의 요청/실제/권장을 구분한다. 과거의 일시 중단 지시를 영구 금지로 해석하거나 Codex6.1 실제 이력을 다른 클라이언트 기본값으로 바꾸지 않는다. 전역 설정·인증·다른 프로젝트 파일을 수정하지 않는다.

## SENSITIVE_PATHS

첫 게임 코드 도입 시 판정·상태·권한·저장 및 실행 경계에 해당하는 다음 경로를 민감 경로로 취급한다.

```text
godot/scripts/core/**
godot/data/missions/**
godot/tests/fixtures/solutions/**
tools/gate.sh
```

게임 소스와 함께 실제 `tools/gate.sh`를 만들고 콘텐츠 검증·헤드리스 테스트·경계 검사를 실행하게 한다. 필요한 실행기나 검사가 빠졌는데 PASS를 내는 gate는 만들지 않는다. 현재 문서 검사 성공은 게임 gate 통과가 아니다. 실제 merge에는 적용되는 상위 교차 검토/gate 규칙을 따른다.

검토 결과는 위치·재현 조건·영향·최소 수정안으로 보고한다. 독립 의견을 공식 근거·사용자 승인·테스트 통과로 대신하지 않는다.
