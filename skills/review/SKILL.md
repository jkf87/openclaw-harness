---
name: review
description: "4관점 코드 리뷰를 수행하는 스킬"
version: "1.0.0"

harness:
  triggers:
    keywords: ["리뷰", "review", "검토", "코드 리뷰"]
    slash: "/review"
  pipeline: review
  agents: [reviewer]
  output:
    format: yaml
    schema: review_verdict_v1
---

# /review — 코드 리뷰 스킬

## 개요

Worker가 수행한 코드 변경사항을 4관점(완료기준/보안/성능/유지보수성)으로 검토합니다.

## 실행 흐름

```
리뷰 요청 (diff + DoD)
    ↓
1. 완료 기준 대비 검증 — DoD 각 항목 체크
    ↓
2. 보안 검토 — OWASP Top 10 패턴 스캔
    ↓
3. 성능/품질 검토 — N+1 쿼리, 에러 핸들링 등
    ↓
4. 유지보수성 검토 — 명명 규칙, 추상화 수준
    ↓
5. 판정 — APPROVE 또는 REQUEST_CHANGES
```

## 사용법

```
/review                    # 현재 변경사항 리뷰
/review --diff HEAD~3      # 최근 3커밋 리뷰
```

## 판정 기준

| severity | 설명 | APPROVE 차단 |
|----------|------|-------------|
| critical | 보안 취약점, 데이터 손실 위험 | 차단 |
| major | 기능 미충족, 성능 문제 | 차단 |
| minor | 코드 스타일, 가독성 | 비차단 |
| suggestion | 개선 제안 | 비차단 |

**APPROVE 조건**: critical + major 이슈 = 0건

## 관련 에이전트

- **reviewer** — 이 스킬을 실행하는 에이전트 (HIGH 티어 모델, 읽기 전용)
