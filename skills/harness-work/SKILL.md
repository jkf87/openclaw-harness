---
name: harness-work
description: "Plan→Work→Review 전체 사이클을 오케스트레이션하는 마스터 스킬"
version: "1.0.0"

harness:
  triggers:
    keywords: ["하네스", "전체 구현", "full cycle", "오케스트레이션"]
    slash: "/harness-work"
  pipeline: full_cycle
  agents: [planner, worker, reviewer]
  output:
    format: markdown
    schema: cycle_report_v1
---

# /harness-work — 오케스트레이터 스킬

## 개요

Plan→Work→Review 전체 사이클을 자동으로 실행하는 마스터 스킬입니다. Orchestrator(main 세션)에서 실행되며, 태스크 규모에 따라 Solo/Parallel/Full 모드를 자동 선택합니다.

## 실행 모드 자동 선택

| 조건 | 모드 | 동작 |
|------|------|------|
| 태스크 1개, 단순 | Solo | Orchestrator가 직접 구현 (spawn 없음) |
| 태스크 2-3개, 독립적 | Parallel | Worker 세션 N개 동시 spawn |
| 태스크 4개+ 또는 의존관계 복잡 | Full Cycle | Plan → Work(병렬) → Review 전체 사이클 |

## Full Cycle 흐름

```
사용자 요청
    ↓
① Intent Gate — 모드 자동 선택
    ↓
② Plan 단계
   - Planner 세션 spawn (HIGH 티어 모델)
   - plan_v1 YAML 산출물 수신
   - [HITL] 계획 승인/수정/거부
    ↓
③ Work 단계
   - parallel_group별 Worker 세션 spawn (MEDIUM 티어)
   - 각 Worker: 태스크 구현 → work_result_v1 반환
   - 모델은 route-task.sh로 자동 결정
    ↓
④ Review 단계
   - Reviewer 세션 spawn (HIGH 티어, 읽기 전용)
   - review_verdict_v1 반환
    ↓
⑤ 판정 분기
   - APPROVE → 완료 보고
   - REQUEST_CHANGES → Fix Loop (최대 3회)
    ↓
⑥ 결과 통합 — 사용자에게 최종 보고
```

## Fix Loop

```
REQUEST_CHANGES 수신
    ↓
Worker에 fix_request 전달 (findings 포함)
    ↓
Worker 재구현 → work_result_v1
    ↓
Reviewer 재리뷰 → review_verdict_v1
    ↓
APPROVE → 완료 | REQUEST_CHANGES → 반복 (최대 3회)
    ↓
3회 초과 → 사용자 에스컬레이션
```

## 상태 추적

사이클 상태는 `cycle-state.yaml`에 영속화:

```yaml
cycle:
  id: "cycle-001"
  phase: planning | working | reviewing | fixing | complete | escalated
  plan:
    session_id: "ses_plan_xxx"
    status: completed | in_progress | failed
  workers:
    - task_id: T1
      session_id: "ses_worker_xxx"
      status: completed | in_progress | failed
      attempt: 1
  review:
    verdict: null | APPROVE | REQUEST_CHANGES
    attempt: 0
  fix_loop:
    count: 0
    max: 3
```

## 실패 대응

```
1단계: Worker 내부 재시도 (동일 오류 3회 → 중단)
    ↓
2단계: Orchestrator 재시도 (새 세션, 모델 업그레이드)
    ↓
3단계: 사용자 에스컬레이션 (실패 원인 + 옵션 제시)
```

## 사용법

```
/harness-work Todo 앱 만들어줘
/harness-work --mode parallel 인증 + 프로필 구현
/harness-work --mode solo 버그 하나 고쳐줘
```
