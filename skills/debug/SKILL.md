---
name: debug
description: "4단계 체계적 근본 원인 분석을 수행하는 디버깅 스킬"
version: "1.0.0"

harness:
  triggers:
    keywords: ["디버그", "debug", "버그", "에러", "오류", "fix", "고쳐줘"]
    slash: "/debug"
  pipeline: debug
  agents: [debugger]
  output:
    format: yaml
    schema: debug_result_v1
---

# /debug — 체계적 디버깅 스킬

## 개요

버그, 에러, 예기치 않은 동작의 근본 원인을 4단계(재현→격리→근본원인→수정검증)로 분석합니다.

## 실행 흐름

```
에러/버그 보고
    ↓
1. 재현 (Reproduce) — 최소 재현 단계 확인
    ↓
2. 격리 (Isolate) — 이분 탐색으로 범위 좁히기
    ↓
3. 근본 원인 (Root Cause) — 5-Whys 기법
    ↓
4. 수정 및 검증 (Fix & Verify) — 최소 수정 + 회귀 테스트
```

## 사용법

```
/debug "TypeError: Cannot read property 'id' of undefined at line 42"
/debug  # 현재 에러 상태에서 자동 분석
```

## 제약

- **추측 금지** — 증거 기반 분석만
- **최소 수정** — 버그 수정에 필요한 최소한의 변경만
- **회귀 테스트 필수** — 같은 버그 재발 방지

## 관련 에이전트

- **debugger** — 이 스킬을 실행하는 에이전트 (MEDIUM 티어 모델)
