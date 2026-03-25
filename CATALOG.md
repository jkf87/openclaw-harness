# OpenClaw 하네스 카탈로그

> 자동 생성됨. 수정 금지. `catalog-gen.sh`로 재생성.
> 생성 시각: 2026-03-25T15:31:46+09:00
> 프로파일: standard  # minimal | standard | full

## 사용 가능 에이전트

| 에이전트 | 설명 | 모델 티어 | 세션 유형 |
|---------|------|----------|----------|
| debugger | 4단계 체계적 근본 원인 분석을 수행하는 디버깅 에이전트 | MEDIUM | isolated |
| planner | 태스크를 분해하고 구현 계획을 생성하는 전략 에이전트 | HIGH                    # LOW | MEDIUM | HIGH | isolated |
| reviewer | 코드 변경사항을 검토하는 읽기 전용 리뷰 에이전트 | HIGH | isolated |
| worker | 계획을 실행하여 코드를 작성하는 구현 에이전트 | MEDIUM | isolated |

## 사용 가능 스킬

| 스킬 | 슬래시 명령 | 설명 |
|------|-----------|------|
| debug | /debug | 4단계 체계적 근본 원인 분석을 수행하는 디버깅 스킬 |
| harness-work | /harness-work | Plan→Work→Review 전체 사이클을 오케스트레이션하는 마스터 스킬 |
| plan | /plan | 태스크를 분해하고 구현 계획을 생성하는 스킬 |
| review | /review | 4관점 코드 리뷰를 수행하는 스킬 |
| work | /work | 계획을 실행하여 코드를 작성하는 구현 스킬 |

## 모델 라우팅 (Claude/Gemini 제외)

| 모델 | 프로바이더 | 티어 | 한국어 | 코딩 | 추론 |
|------|-----------|------|--------|------|------|
| GLM-5 Turbo | Z.ai | LOW | 95 | 70 | 60 |
| GPT-5.4 Codex | OpenAI | MEDIUM | 70 | 95 | 90 |
| GLM-5 | Z.ai | MEDIUM | 95 | 80 | 80 |

## 사용법

스킬을 호출하려면 자연어로 요청하거나 슬래시 명령 사용:
- "이 기능을 계획해줘" → /plan 자동 트리거
- "/work all" → 전체 태스크 구현
- "/review" → 코드 리뷰 실행
- "/debug" → 체계적 디버깅
- "/harness-work" → Plan→Work→Review 전체 사이클
