# 리뷰 결과 예시: T3 — Todo 목록 UI 컴포넌트

> 리뷰 대상: T3 구현 결과
> 에이전트: reviewer
> 모델: gpt-5.4-codex (HIGH 티어, 읽기 전용)

## review_verdict_v1 출력

```yaml
verdict:
  decision: REQUEST_CHANGES
  findings:
    - severity: major
      location: "src/components/TodoItem.tsx:28"
      issue: "Todo 삭제 시 확인 없이 즉시 삭제됨 — 실수로 삭제할 위험"
      fix_suggestion: "window.confirm() 또는 undo 토스트 패턴 적용"

    - severity: minor
      location: "src/components/TodoList.tsx:8"
      issue: "filteredTodos 계산이 매 렌더마다 실행됨 — useMemo 적용 권장"
      fix_suggestion: "useMemo(() => todos.filter(...), [todos, filter]) 사용"

    - severity: suggestion
      location: "src/styles/TodoList.module.css:15"
      issue: "완료된 Todo의 시각적 구분이 취소선만 있음"
      fix_suggestion: "opacity: 0.6 추가로 시각적 구분 강화"

    - severity: minor
      location: "src/components/TodoItem.tsx:12"
      issue: "aria-label 누락 — 접근성 개선 필요"
      fix_suggestion: "체크박스에 aria-label={`${todo.text} 완료 토글`} 추가"

  summary: "기능은 대부분 완성되었으나 삭제 시 확인 로직 누락 (major 1건). minor 2건, suggestion 1건."
```

## 리뷰 상세

### 1. 완료 기준(DoD) 대비 검증

| DoD 항목 | 결과 |
|---------|------|
| Todo 목록이 화면에 렌더링 | ✓ 통과 |
| 완료 토글 동작 | ✓ 통과 |
| 테스트 통과 | ✓ 5/5 통과 |

### 2. 보안 검토

- XSS 위험: 없음 (React의 자동 이스케이프)
- 데이터 유효성: Todo 텍스트 길이 제한 없음 (minor — 극단적 입력에서 UI 깨짐 가능)

### 3. 성능 검토

- `filteredTodos` 재계산 빈도: 매 렌더 시 → **useMemo 권장** (minor)
- 리스트 항목 100개 이하에서는 성능 문제 없음

### 4. 유지보수성 검토

- TodoList/TodoItem 분리는 적절
- 접근성(aria-label) 누락 → minor

## 판정

**REQUEST_CHANGES** — major 이슈 1건 (삭제 확인 로직) 수정 후 재리뷰 필요
