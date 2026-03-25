---
name: work
description: "계획을 실행하여 코드를 작성하는 구현 스킬"
version: "1.0.0"

harness:
  triggers:
    keywords: ["구현", "work", "build", "만들어줘", "코드 작성"]
    slash: "/work"
  pipeline: work
  agents: [worker]
  output:
    format: yaml
    schema: work_result_v1
---

# /work — 구현 실행 스킬

## 개요

Planner가 생성한 계획(또는 직접 지정한 태스크)을 실행하여 코드를 작성합니다.

## 실행 흐름

```
태스크 할당
    ↓
1. 태스크 확인 — 범위, DoD 숙지
    ↓
2. 관련 파일 읽기 — 최소한만, 전체 탐색 금지
    ↓
3. 구현 — TDD 사이클 (필요 시)
    ↓
4. 셀프 검증 — 빌드, 테스트, 린트 실행
    ↓
5. 결과 보고 — work_result_v1 YAML 포맷
```

## 사용법

```
/work T1          # 특정 태스크 구현
/work all         # 전체 태스크 순차 구현
/work A           # parallel_group A 태스크 구현
```

## 실패 시 행동

1. **1차 실패** — 원인 분석 후 수정 재시도
2. **2차 실패** — 접근 방식 변경 후 재시도
3. **3차 실패** — 중단 + 에스컬레이션 보고 (escalation_reason 기술)

## 관련 에이전트

- **worker** — 이 스킬을 실행하는 에이전트 (MEDIUM 티어 모델)
