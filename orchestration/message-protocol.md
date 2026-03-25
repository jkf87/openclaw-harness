# 에이전트 간 메시지 프로토콜

> 모든 에이전트 간 통신은 `sessions_send`를 통해 구조화된 YAML 봉투 포맷으로 이루어진다.

## 메시지 봉투(Envelope) 포맷

```yaml
message:
  type: <메시지 유형>
  from: <발신 에이전트>
  to: <수신 에이전트>
  timestamp: "2026-03-26T14:30:00Z"
  correlation_id: "cycle-001"       # 사이클 추적용
  payload: { ... }                  # type별 페이로드
```

## 메시지 유형

| type | from | to | 설명 |
|------|------|----|------|
| `plan_request` | orchestrator | planner | 계획 수립 요청 |
| `plan` | planner | orchestrator | 계획 결과 (plan_v1) |
| `task_assign` | orchestrator | worker-{id} | 태스크 할당 |
| `work_result` | worker-{id} | orchestrator | 구현 결과 (work_result_v1) |
| `review_request` | orchestrator | reviewer | 리뷰 요청 |
| `review_verdict` | reviewer | orchestrator | 리뷰 판정 (review_verdict_v1) |
| `fix_request` | orchestrator | worker-{id} | 수정 요청 (findings 포함) |
| `escalation` | any | orchestrator | 에스컬레이션 보고 |
| `status_update` | any | orchestrator | 진행 상태 보고 |

## 메시지 흐름 시퀀스

```
Orchestrator              Planner           Worker(s)          Reviewer
    │                        │                  │                  │
    │── plan_request ───────▶│                  │                  │
    │◀── plan ──────────────│                  │                  │
    │                        │                  │                  │
    │── task_assign ────────────────────────────▶│                  │
    │◀── work_result ──────────────────────────│                  │
    │                        │                  │                  │
    │── review_request ──────────────────────────────────────────▶│
    │◀── review_verdict ────────────────────────────────────────│
    │                        │                  │                  │
    │   [REQUEST_CHANGES인 경우]                 │                  │
    │── fix_request ────────────────────────────▶│                  │
    │◀── work_result ──────────────────────────│                  │
    │── review_request ──────────────────────────────────────────▶│
    │   ... (최대 3회 반복)                       │                  │
```

## 각 메시지 유형별 페이로드

### plan_request

```yaml
payload:
  user_request: "사용자 원문 요청"
  project_context:
    tech_stack: ["typescript", "react", "postgresql"]
    dir_structure: "2단계 디렉토리 트리"
```

### plan (plan_v1)

```yaml
payload:
  plan:
    goal: "사용자 요청 한 줄 요약"
    tasks:
      - id: T1
        content: "태스크 설명"
        dod: "검증 가능한 완료 기준"
        depends: []
        effort: medium
        parallel_group: A
    execution_order: [[T1, T2], [T3]]
```

### task_assign

```yaml
payload:
  task:
    id: T1
    content: "태스크 설명"
    dod: "완료 기준"
  related_files:
    - path: src/auth/middleware.ts
      reason: "수정 대상"
  dependencies_summary:
    - task_id: T0
      summary: "선행 태스크 결과 요약"
```

### work_result (work_result_v1)

```yaml
payload:
  result:
    task_id: T1
    status: completed | failed | escalated
    files_changed:
      - path: src/auth/middleware.ts
        action: created | modified | deleted
    summary: "구현 내용 한 줄 요약"
    verification:
      build: pass | fail
      tests: "3/3 통과"
      lint: pass | fail
    escalation_reason: null
```

### review_request

```yaml
payload:
  task:
    id: T1
    content: "태스크 설명"
    dod: "완료 기준"
  diff: "git diff 출력"
  build_log: "빌드/테스트 결과"
```

### review_verdict (review_verdict_v1)

```yaml
payload:
  verdict:
    decision: APPROVE | REQUEST_CHANGES
    findings:
      - severity: critical | major | minor | suggestion
        location: "src/auth/middleware.ts:42"
        issue: "발견된 이슈"
        fix_suggestion: "수정 제안"
    summary: "리뷰 결과 한 줄 요약"
```

### fix_request

```yaml
payload:
  task_id: T1
  findings:
    - severity: major
      location: "src/auth/middleware.ts:42"
      issue: "JWT 시크릿이 하드코딩됨"
      fix_suggestion: "환경변수 JWT_SECRET 사용"
  attempt: 1                        # 현재 시도 횟수
  max_attempts: 3
```

### escalation

```yaml
payload:
  type: plan_approval | destructive_action | retry_exhausted | security_finding
  context: "무엇이 발생했는지 요약"
  options:
    - label: "승인"
      action: proceed
    - label: "수정"
      action: edit
    - label: "취소"
      action: abort
  details: "상세 정보 (diff, 에러 로그 등)"
```

## 핸드셰이크 규약

1. **세션 생성 확인**: `sessions_spawn` 후 `sessions_list`로 세션 상태 `active` 확인
2. **메시지 전달 확인**: `sessions_send` 반환값으로 전달 성공 확인
3. **타임아웃 처리**: 응답 없으면 `sessions_history`로 세션 상태 확인 → 재전송 또는 에스컬레이션
4. **종료 시그널**: 작업 완료 시 `status: completed` 메시지 전송 → Orchestrator가 세션 정리
