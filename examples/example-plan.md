# 계획 예시: Todo 앱 만들어줘

> 사용자 요청: "Todo 앱 만들어줘"
> 에이전트: planner
> 모델: gpt-5.3-codex (HIGH 티어 → 아키텍처 카테고리)

## plan_v1 출력

```yaml
plan:
  goal: "CRUD 기능이 있는 Todo 웹 애플리케이션 구현"
  tasks:
    - id: T1
      content: "프로젝트 초기 설정 — package.json, TypeScript, React 설정"
      dod: "npm run dev 실행 시 빈 페이지 렌더링 성공"
      depends: []
      effort: low
      parallel_group: A

    - id: T2
      content: "Todo 데이터 모델 및 스토어 구현 — Zustand 상태관리"
      dod: "Todo 생성/조회/수정/삭제 함수가 단위 테스트 통과"
      depends: []
      effort: medium
      parallel_group: A

    - id: T3
      content: "Todo 목록 UI 컴포넌트 구현 — 할 일 목록 렌더링"
      dod: "Todo 목록이 화면에 렌더링되고 완료 토글 동작"
      depends: [T1, T2]
      effort: medium
      parallel_group: B

    - id: T4
      content: "Todo 추가 폼 UI 컴포넌트 구현 — 입력 + 추가 버튼"
      dod: "텍스트 입력 후 추가 버튼 클릭 시 목록에 반영"
      depends: [T1, T2]
      effort: low
      parallel_group: B

    - id: T5
      content: "Todo 삭제 및 편집 기능 구현"
      dod: "삭제 버튼 클릭 시 항목 제거, 더블클릭 시 편집 가능"
      depends: [T3, T4]
      effort: medium
      parallel_group: C

    - id: T6
      content: "필터링 기능 구현 — 전체/완료/미완료 필터"
      dod: "필터 버튼 클릭 시 해당 상태의 Todo만 표시"
      depends: [T3]
      effort: low
      parallel_group: C

    - id: T7
      content: "로컬스토리지 영속화 — 새로고침 후에도 데이터 유지"
      dod: "브라우저 새로고침 후 기존 Todo 목록 유지 확인"
      depends: [T5, T6]
      effort: low
      parallel_group: D

  execution_order:
    - [T1, T2]        # Phase 1: 초기 설정 + 데이터 모델 (병렬)
    - [T3, T4]        # Phase 2: 목록 + 추가 폼 (병렬)
    - [T5, T6]        # Phase 3: 삭제/편집 + 필터 (병렬)
    - [T7]            # Phase 4: 영속화 (단독)
```

## 라우팅 결과

```yaml
routing_decision:
  model: gpt-5.3-codex
  category: coding_general
  complexity_score: 6
  complexity_tier: MEDIUM
  korean_ratio: 0.85
  budget_profile: standard
  fallback_chain: [gpt-5.3-codex, glm-5, glm-5-turbo]
  reason: "카테고리=coding_general, 복잡도=MEDIUM(6점), 한국어=0.85"
```
