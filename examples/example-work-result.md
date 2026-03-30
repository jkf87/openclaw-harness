# 구현 결과 예시: T3 — Todo 목록 UI 컴포넌트

> 태스크: T3 — Todo 목록 UI 컴포넌트 구현
> 에이전트: worker
> 모델: gpt-5.3-codex (MEDIUM 티어)

## work_result_v1 출력

```yaml
result:
  task_id: T3
  status: completed
  files_changed:
    - path: src/components/TodoList.tsx
      action: created
    - path: src/components/TodoItem.tsx
      action: created
    - path: src/components/TodoList.test.tsx
      action: created
    - path: src/styles/TodoList.module.css
      action: created
  summary: "Todo 목록 UI 컴포넌트 구현 완료 — TodoList + TodoItem 분리, 완료 토글 동작"
  verification:
    build: pass
    tests: "5/5 통과"
    lint: pass
  escalation_reason: null
```

## 구현 내용

### src/components/TodoList.tsx

```tsx
import { useTodoStore } from '../store/todoStore';
import { TodoItem } from './TodoItem';
import styles from '../styles/TodoList.module.css';

export function TodoList() {
  const { todos, filter } = useTodoStore();

  const filteredTodos = todos.filter((todo) => {
    if (filter === 'completed') return todo.completed;
    if (filter === 'active') return !todo.completed;
    return true;
  });

  if (filteredTodos.length === 0) {
    return <p className={styles.empty}>할 일이 없습니다</p>;
  }

  return (
    <ul className={styles.list}>
      {filteredTodos.map((todo) => (
        <TodoItem key={todo.id} todo={todo} />
      ))}
    </ul>
  );
}
```

### 테스트 결과

```
 PASS  src/components/TodoList.test.tsx
  ✓ Todo 목록이 렌더링된다 (12ms)
  ✓ 빈 목록일 때 안내 메시지를 표시한다 (3ms)
  ✓ 완료 필터가 동작한다 (8ms)
  ✓ 미완료 필터가 동작한다 (5ms)
  ✓ 완료 토글이 동작한다 (10ms)

Test Suites: 1 passed, 1 total
Tests:       5 passed, 5 total
```
