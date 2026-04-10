# OpenClaw Harness

> Plan→Work→Review 에이전트 오케스트레이션 + 갭(Gap) 감지 루프

에이전트 기반 작업을 구조화된 사이클로 실행합니다. Claude Code 하네스 생태계 분석을 기반으로 설계되었고, 정구봉님의 "우로보로스 하네스" 핵심 아이디어(드리프트 방지, 갭 감지, 스펙 진화)를 채택했습니다.

## 특징

- **🔄 Plan→Work→Review 사이클** — Planner가 태스크를 분해하고 Worker가 병렬 구현, Reviewer가 검증
- **⚡ 갭(Gap) 감지 루프** — AI가 원래 의도에서 벗어난 것을 자동 감지하고 1회 수정 재실행
- **📡 브릿지 알림** — 에이전트 상태를 실시간으로 텔레그램/디스코드 등 채널에 푸시
- **🧭 멀티티어 모델 라우팅** — Z.ai 코딩플랜 **Lite/Pro/Max** 인식, 플랜이 허용한 모델만 자동 선택
- **🇰🇷 한국어 최적화** — 한국어 감지 시 GLM 시리즈 우선
- **🆕 GLM-5.1 지원** — Pro/Max 플랜에서 자동 활성
- **🔌 Codex OAuth 병행 (선택)** — ChatGPT Plus/Pro 구독으로 GPT-5.4 Codex를 고난도 코딩/보안에 오버레이

## 아키텍처

```
사용자 요청
    │
    ▼
┌─────────┐
│ Planner │ ── 태스크 분해 + Ambiguity Score
└────┬────┘
     │
     ▼
┌─────────┐     ┌─────────┐
│ Worker-1│ ... │ Worker-N│ ── 병렬 구현 (sessions_spawn)
└────┬────┘     └────┬────┘
     │               │
     ▼               ▼
┌─────────────────────┐
│     Reviewer        │ ── 5관점 리뷰 + 갭 감지
│  (read-only)        │
└──────────┬──────────┘
           │
     ┌─────┴─────┐
     │ APPROVE?  │
     └─────┬─────┘
      예 │     │ 아니오 (GAP_DETECTED)
         │     │
    COMPLETE  갭 피드백 → Worker 재실행 (최대 1회)
                   │
              ┌────┴────┐
              │ 여전히 갭? │
              └────┬────┘
             예 │     │ 아니오
                │     │
           에스컬레이션  COMPLETE
          (사용자 질문)
```

## 에이전트

| 에이전트 | 역할 | 권한 | Lite | Pro | Max | + Codex OAuth |
|---------|------|------|------|-----|-----|---------------|
| **planner** | 계획 수립 | read-only | glm-5 | glm-5.1 | glm-5.1 | glm-5.1 |
| **worker** | 코드 구현 | read+write+exec | glm-5 | glm-5.1 | glm-5.1 | gpt-5.4-codex (HIGH) |
| **reviewer** | 5관점 리뷰 + 갭 감지 | read-only | glm-5 | glm-5.1 | glm-5.1 | glm-5.1 |
| **debugger** | 체계적 디버깅 | read+exec | glm-5 | glm-5 | glm-5.1 | gpt-5.4-codex (HIGH) |

## Reviewer 5관점

1. **완료 기준 검증** — DoD 항목별 체크, 테스트/빌드 통과 여부
2. **보안 검토** — OWASP Top 10, 하드코딩 시크릿, 인젝션 패턴
3. **성능/품질** — N+1 쿼리, 불필요 API 호출, 에러 핸들링
4. **유지보수성** — 명명 규칙, 추상화 수준, 순환 복잡도
5. **🆕 갭(Gap) 감지** — 의도 보존, 가정 주입, 스코프 이탈, 방향성

## 갭(Gap) 유형

| 유형 | 설명 | 예시 |
|------|------|------|
| `assumption_injection` | 사용자가 말하지 않은 가정 추가 | "JWT 인증 자의 추가" |
| `scope_creep` | 요청하지 않은 기능/복잡도 | "TODO 앱에 알림 시스템 추가" |
| `direction_drift` | 전체 방향이 의도와 다름 | "단순 API → 풀스택 프레임워크" |
| `missing_core` | 핵심 기능 누락 | "검색 기능 구현 누락" |
| `over_engineering` | 과도한 추상화/일반화 | "단순 CRUD에 DI 컨테이너" |

## 브릿지(Bridge) 알림

에이전트 상태를 채널(텔레그램 등)에 실시간 푸시합니다.

```bash
# 상태 확인
bash scripts/bridge.sh status

# 새 사이클
bash scripts/bridge.sh reset "my-cycle" full

# 단계 전환
bash scripts/bridge.sh phase WORKING

# 갭 감지
bash scripts/bridge.sh gap-detected worker-1 scope_creep "알림 자의 추가" "알림 제거"

# 갭 수정 시작
bash scripts/bridge.sh gap-fix-start worker-1 glm-5.1
```

### 알림 예시

```
🔄 [harness] → WORKING 단계 시작
✅ [harness] 3/5 완료 (60%)
├── worker-1: API 구현 (glm-5-turbo, 120s)
├── worker-2: 테스트 작성 (glm-5-turbo, 45s)
└── 예상 잔여: ~60s

⚡ [harness] worker-2 갭 감지 (scope_creep)
├── 원인: TODO 앱에 알림 시스템 자의 추가
├── 수정 방향: 알림 기능 제거, 단순 CRUD로 축소
├── 루프: 0/1
└── 상태: 3/5
```

## Z.ai 코딩플랜 (Lite / Pro / Max)

본 하네스는 Z.ai 코딩플랜 **3개 티어를 모두 인식**하며, 활성 플랜에서 허용한 모델만 라우팅합니다. 가입: https://z.ai/subscribe?ic=OTYO9JPFNV

| 플랜 | 가격 | 사용 가능 모델 | 일일 토큰 | 동시 워커 | full 파이프라인 |
|------|------|----------------|-----------|-----------|------------------|
| **Lite** | $3/월 | GLM-5 Turbo, GLM-5 | 1.5M | 2 | ⚠️ 제한 |
| **Pro**  | $15/월 | + GLM-5.1 | 8M | 4 | ✅ |
| **Max**  | $30/월 | 풀 모델 + 우선 슬롯 | 25M | 7 | ✅ |

활성 플랜은 `routing/plans.yaml` 의 `active_plan` 또는 환경변수 `ZAI_CODING_PLAN` 으로 지정합니다. 빠른 전환:

```bash
bash scripts/switch-plan.sh lite
bash scripts/switch-plan.sh pro
bash scripts/switch-plan.sh max
bash scripts/switch-plan.sh pro --with-codex
```

## 모델 라우팅

태스크의 **복잡도 × 카테고리 × 활성 플랜** 3D 매트릭스로 자동 모델 선택. Anthropic Claude / Google Gemini 직접 호출은 사용하지 않습니다.

### 지원 모델

| 모델 | 티어 | 컨텍스트 | 코딩 | 추론 | 한국어 | Lite | Pro | Max |
|------|------|----------|------|------|--------|------|-----|-----|
| **GLM-5 Turbo** | LOW | 128K | 70 | 60 | 95 | ✅ | ✅ | ✅ |
| **GLM-5** | MEDIUM | 128K | 88 | 82 | 95 | ✅ | ✅ | ✅ |
| **GLM-5.1** ⚡ | HIGH | 204.8K | 95 | **95** | 96 | ❌ | ✅ | ✅ |
| **GPT-5.4 Codex** ⚡ *(선택)* | HIGH | 256K | **97** | **97** | 72 | OAuth | OAuth | OAuth |

⚡ = extended thinking (reasoning_mode) 지원. 숫자는 0–100 상대 점수.

> 💡 GPT-5.4 Codex는 ChatGPT Plus/Pro 구독을 보유한 경우 **Codex OAuth** 로 무료 병행 사용이 가능합니다. GLM-5.1 보다 소폭 강한 extended thinking 을 제공하므로 추론 집약 태스크(알고리즘 증명, 분산 시스템, 보안 분석)에 특히 유리합니다 (자세한 내용은 [docs/zai-coding-plan.md](docs/zai-coding-plan.md)).

### 라우팅 매트릭스 (Pro 기준)

| 카테고리 | LOW | MEDIUM | HIGH |
|---------|-----|--------|------|
| 코딩 (일반) | GLM-5 Turbo | GLM-5 | GLM-5.1 |
| 코딩 (아키텍처) | GLM-5 | GLM-5.1 | GLM-5.1 |
| 한국어 NLP | GLM-5 Turbo | GLM-5 | GLM-5.1 |
| 추론 | GLM-5 Turbo | GLM-5 | GLM-5.1 |
| 디버깅 | GLM-5 Turbo | GLM-5 | GLM-5.1 |
| 보안 | GLM-5 | GLM-5.1 | GLM-5.1 |
| 콘텐츠 생성 | GLM-5 Turbo | GLM-5 | GLM-5.1 |

**Lite 플랜**: HIGH 슬롯이 모두 GLM-5로 자동 강등됩니다.
**Max 플랜**: MEDIUM 코딩/리뷰도 적극적으로 GLM-5.1을 사용합니다.
**Codex OAuth 활성**: 코딩(아키텍처/일반 HIGH), 디버깅(HIGH), 보안(MEDIUM/HIGH), **추론(HIGH), 데이터 분석(HIGH)** 이 GPT-5.4 Codex로 오버레이됩니다.

### 🧠 추론 집약 감지

라우팅 엔진은 태스크 텍스트에서 **추론 집약 신호**를 감지해 `reasoning_score` 가 가장 높은 모델로 우선 라우팅합니다.

**감지 키워드:**
- 한국어: 증명, 알고리즘, 복잡도, 수학, 최적화, 정합성, 상태 머신, 불변조건, 분산 합의, race condition
- 영문: prove/proof, invariant, complexity, big-O, algorithm, optimization, theorem, tradeoff, distributed consensus

**분기:**
| 조건 | 선택 모델 | reasoning_score |
|------|-----------|-----------------|
| reasoning_heavy + Codex 활성 + HIGH | **GPT-5.4 Codex** | 97 |
| reasoning_heavy + Pro/Max + MEDIUM 이상 | **GLM-5.1** | 95 |
| reasoning_heavy + Lite | GLM-5 (상한) | 82 |

### 우선순위 규칙 (first-match)

1. **P100** — 사용자 명시 오버라이드
2. **P95** — 활성 플랜 미허용 모델 자동 강등 (예: Lite의 glm-5.1 → glm-5)
3. **P90** — 한국어 비율 >70% + NLP/콘텐츠 → GLM 시리즈 우선
4. **P85** — 한국어 혼합(>50%) → GLM-5
5. **P82** — 🧠 추론 집약 + Codex 활성 + HIGH → **GPT-5.4 Codex** (extended thinking)
6. **P81** — 🧠 추론 집약 + Pro/Max + MEDIUM↑ → **GLM-5.1**
7. **P80** — Codex OAuth 활성 + 고난도 아키텍처/보안/추론/분석 → GPT-5.4 Codex
8. **P75** — Pro/Max + HIGH 복잡도 → GLM-5.1
9. **P70** — Lite + HIGH 복잡도 → GLM-5 (상한)
10. **P60** — 표준 코딩/디버깅 → GLM-5
11. **P50** — 저복잡도 → GLM-5 Turbo
12. **P0** — 기본 → GLM-5

### 복잡도 측정 신호

**어휘 신호:** 단어 수, 코드 블록 수, 파일 경로 수, 아키텍처 키워드("설계", "마이그레이션", "리팩토링")

**구조 신호:** 서브태스크 수, 크로스 파일 참조, 테스트 필요 여부, 시스템 전체 영향

**컨텍스트 신호:** 이전 실패 횟수, 대화 턴 수, 계획 단계 수

### 폴백 체인 (플랜별)

| 용도 | Lite | Pro / Max | + Codex OAuth |
|------|------|-----------|----------------|
| 코딩 | glm-5 → glm-5-turbo | glm-5.1 → glm-5 → glm-5-turbo | gpt-5.4-codex → glm-5.1 → glm-5 |
| 한국어 | glm-5 → glm-5-turbo | glm-5.1 → glm-5 → glm-5-turbo | (동일) |
| 추론 | glm-5 → glm-5-turbo | glm-5.1 → glm-5 → glm-5-turbo | (동일) |
| 보안 | glm-5 | glm-5.1 → glm-5 | gpt-5.4-codex → glm-5.1 |

## 예산 프로파일 (코딩플랜 정액제 기반)

Z.ai 코딩플랜은 정액제이므로 비용 대신 **토큰/요청 quota**를 관리합니다. 각 프로파일은 코딩플랜 티어와 1:1 매핑됩니다.

| 프로파일 | 플랜 | 일일 토큰 | 태스크당 | 일일 요청 | 동시 워커 |
|---------|------|-----------|----------|-----------|-----------|
| `lite` | Lite ($3) | 1.5M | 60K | 600 | 2 |
| `pro`  | Pro ($15) | 8M | 200K | 3,000 | 4 |
| `max`  | Max ($30) | 25M | 500K | 12,000 | 7 |
| `codex_oauth_addon` | (Codex 병행) | — | — | 1,500 | 3 |

**Quota 초과 정책:** 80% 경고 → 95% GLM-5 Turbo 강등 + Reviewer를 GLM-5로 강등 → 100% 신규 태스크 차단 (Codex OAuth 활성 시 자동 페일오버)

## 파이프라인 모드

| 모드 | 조건 | 파이프라인 | 최대 Worker |
|------|------|-----------|-------------|
| `solo` | 태스크 1개 + 중간 이하 복잡도 | Work | 0 |
| `parallel` | 독립 태스크 2~3개 | Work(병렬) → Review | 3 |
| `full` | 태스크 4개+ or 의존성 있음 or 고복잡도 | Plan → Work(병렬) → Review | 5 |

**동시 실행:** 활성 플랜 기준 — Lite 2 / Pro 4 / Max 7. 모델별 추가 상한은 GLM-5-turbo 7, GLM-5 5, GLM-5.1 3, GPT-5.4 Codex 3 (min 적용).

### 상태 머신

```
IDLE → PLANNING → WORKING → REVIEWING → COMPLETE
                        ↓           ↓
                    ESCALATED    FIXING → REVIEWING (최대 3회)
```

## 메시지 프로토콜

에이전트 간 통신은 `sessions_send` + YAML 봉투 포맷:

```yaml
message:
  type: task_assign
  from: orchestrator
  to: worker-1
  timestamp: "2026-03-26T14:30:00Z"
  correlation_id: "cycle-001"
  payload:
    task:
      id: T1
      content: "태스크 설명"
      dod: "검증 가능한 완료 기준"
    related_files:
      - path: src/auth/middleware.ts
        reason: "수정 대상"
```

**메시지 유형:** `plan_request`, `plan`, `task_assign`, `work_result`, `review_request`, `review_verdict`, `fix_request`, `escalation`, `status_update`

## 파일 구조

```
harness/
├── agents/                    # 에이전트 정의
│   ├── planner.md             #   계획 수립 (read-only)
│   ├── worker.md              #   코드 구현 (read+write+exec)
│   ├── reviewer.md            #   5관점 리뷰 + 갭 감지 (read-only)
│   ├── debugger.md            #   체계적 디버깅 (read+exec)
│   └── bridge.md              #   브릿지 참조
├── scripts/
│   ├── bridge.sh              #   브릿지 상태 추적 + 알림
│   ├── orchestrate.sh         #   오케스트레이터 진입
│   ├── route-task.sh          #   라우팅 엔진
│   ├── spawn-agent.sh         #   에이전트 스폰 래퍼
│   └── doctor.sh              #   진단 스크립트
├── routing/
│   ├── models.yaml            #   모델 카탈로그 + 비용
│   ├── routing-rules.yaml     #   라우팅 규칙 엔진
│   └── budget-profiles.yaml   #   예산 프로파일
├── orchestration/
│   ├── pipelines.yaml         #   파이프라인 정의
│   └── message-protocol.md    #   메시지 프로토콜
├── examples/                  #   예시 산출물
└── state/                     #   런타임 상태 (git-ignored)
```

## 가입 / 인증 / Claude Code 연동

전체 셋업 절차(플랜 선택, OAuth, Claude Code env, Codex 병행)는 **[docs/zai-coding-plan.md](docs/zai-coding-plan.md)** 에 정리되어 있습니다.

핵심 요약:

```bash
# 1) Z.ai 코딩플랜 가입 (Lite $3 / Pro $15 / Max $30)
open https://z.ai/subscribe?ic=OTYO9JPFNV

# 2) OAuth 인증
openclaw onboard          # → "Z.ai Coding Plan" 선택

# 3) 활성 플랜 지정
bash scripts/switch-plan.sh pro

# 4) (선택) Codex OAuth 병행
codex login
bash scripts/switch-plan.sh pro --with-codex
```

Claude Code `~/.claude/settings.json` (Pro 기준):

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "zai_xxx...",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-5-turbo",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5.1"
  }
}
```

> ⚠️ **Lite 플랜**: `OPUS_MODEL` 을 `glm-5` 로 변경 (GLM-5.1 미포함).

## ChatGPT Codex OAuth 연동 (상세)

**선택 사항입니다.** Z.ai 단독으로도 충분히 동작합니다. 다만 **ChatGPT Plus($20/월) 또는 Pro($200/월)** 구독을 이미 보유했다면, OpenAI Codex CLI의 OAuth를 활용해서 GPT-5.4 Codex를 **추가 비용 없이** 고난도 코딩/보안 태스크에 병행 사용할 수 있습니다. 라우팅 엔진이 `codex_overlay` 규칙에 따라 자동으로 분배합니다.

### 사전 조건

| 항목 | 확인 방법 |
|------|-----------|
| ChatGPT Plus/Pro 구독 | https://chat.openai.com/#settings/Subscription |
| Node.js 18+ 또는 Homebrew | `node -v` / `brew --version` |
| 브라우저 접근 가능 | OAuth 콜백 수신용 (localhost) |

### 1단계 — Codex CLI 설치

macOS (Homebrew 권장):
```bash
brew install codex
```

또는 npm (크로스 플랫폼):
```bash
npm install -g @openai/codex
```

설치 확인:
```bash
codex --version
# codex 0.x.x
```

### 2단계 — OAuth 로그인 (메인 계정)

```bash
codex login
```

진행 흐름:

1. 터미널에 `Opening browser for authentication...` 메시지가 뜨고 자동으로 브라우저가 열립니다.
2. ChatGPT 로그인 페이지로 리다이렉트 → 구독 계정으로 로그인.
3. **"Authorize Codex CLI"** 권한 요청 화면에서 **Allow** 클릭.
4. `http://localhost:1455/success` 페이지가 뜨면 성공. 터미널로 돌아가면 `✓ Logged in as <email>` 이 표시됩니다.
5. 인증 토큰은 `~/.codex/auth.json` 에 저장됩니다 (평문 JSON, 파일 권한 600).

검증:
```bash
codex whoami
# Logged in as your@email.com (subscription: plus)

ls -la ~/.codex/auth.json
# -rw-------  1 user  staff  ... auth.json
```

### 3단계 — (선택) 두 번째 계정 추가

여러 계정으로 rate limit을 분산하고 싶다면 `CODEX_HOME` 환경변수로 별도 디렉토리에 로그인하세요:

```bash
# 새 디렉토리에서 두 번째 계정으로 로그인
CODEX_HOME=~/.codex-acct2 codex login

# 검증
CODEX_HOME=~/.codex-acct2 codex whoami
ls ~/.codex-acct2/auth.json
```

> 💡 **팀에서 공용 사용 시**: 각자 개인 계정으로 `~/.codex` 에 로그인하고, 본 하네스가 `accounts.yaml` round-robin 으로 분산합니다. 한 계정을 여러 명이 공유하면 OpenAI 약관 위반이 될 수 있으니 피해 주세요.

### 4단계 — 하네스 계정 풀 활성화

`routing/accounts.yaml` 의 Codex 풀 항목을 **`enabled: true`** 로 변경:

```yaml
pools:
  codex:
    base_url: https://api.openai.com/v1
    strategy: round_robin
    optional: true
    accounts:
      - id: codex-primary
        auth_type: oauth_codex
        codex_home: ~/.codex
        weight: 10
        enabled: true          # ← false에서 true로 변경

      # 두 번째 계정이 있다면:
      - id: codex-secondary
        auth_type: oauth_codex
        codex_home: ~/.codex-acct2
        weight: 10
        enabled: true          # ← 두 번째 계정도 true
```

### 5단계 — 라우팅 엔진에 Codex 알리기

두 가지 방법 중 하나:

**A) 스크립트로 (권장):**
```bash
bash scripts/switch-plan.sh pro --with-codex
```

**B) 수동으로 `routing/plans.yaml` 편집:**
```yaml
active_plan: pro
codex_oauth_enabled: true    # ← false에서 true로
```

### 6단계 — 동작 확인

`doctor.sh` 로 전체 상태 점검:
```bash
bash scripts/doctor.sh
```

기대 출력:
```
[4/7] 인증 자격 검사
  ✓ Z.ai API 키 (ZAI_API_KEY 설정됨)
  ✓ Codex OAuth (~/.codex/auth.json 존재)
  ✓ Codex OAuth 보조 계정 (~/.codex-acct2/auth.json)   ← 추가 계정 있을 때
```

라우팅 시뮬레이션 (아키텍처 HIGH 태스크가 Codex로 가는지 확인):
```bash
CODEX_OAUTH_ENABLED=true bash scripts/route-task.sh \
  "전체 인증 시스템 마이그레이션 설계 OAuth JWT 보안 감사" coding_arch

# 기대:
#   model: gpt-5.4-codex
#   fallback_chain: [gpt-5.4-codex, glm-5.1, glm-5, glm-5-turbo]
```

### Codex 오버레이 동작표

`codex_oauth_enabled: true` 일 때 아래 슬롯만 GPT-5.4 Codex로 오버레이됩니다. 나머지는 그대로 GLM 시리즈가 담당합니다.

| 카테고리 | 복잡도 | Z.ai 단독 | + Codex OAuth |
|----------|--------|-----------|---------------|
| coding_arch | MEDIUM / HIGH | glm-5.1 | **gpt-5.4-codex** |
| coding_general | HIGH | glm-5.1 | **gpt-5.4-codex** |
| debugging | HIGH | glm-5.1 | **gpt-5.4-codex** |
| security | MEDIUM / HIGH | glm-5.1 | **gpt-5.4-codex** |
| **reasoning** | HIGH | glm-5.1 | **gpt-5.4-codex** 🧠 |
| **data_analysis** | HIGH | glm-5.1 | **gpt-5.4-codex** 🧠 |
| korean_nlp / content | 전부 | GLM 시리즈 | (그대로 GLM — 한국어 우선) |

🧠 = extended thinking (reasoning_score 97) 활용. 추론 집약 신호가 감지되면 카테고리와 무관하게 GPT-5.4 Codex 로 라우팅됩니다.

Codex 동시 워커는 rate limit 보호를 위해 **최대 3개** 로 제한됩니다 (`pipelines.yaml#concurrency.rules`).

### 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `codex: command not found` | CLI 미설치 | `brew install codex` 또는 `npm i -g @openai/codex` |
| 브라우저가 안 열림 (SSH/원격) | 로컬 콜백 URL 접근 불가 | `codex login --no-browser` 후 출력된 URL을 로컬 브라우저에 붙여넣고, 받은 코드를 터미널에 입력 |
| `Error: No subscription found` | Free 계정으로 로그인 | Plus/Pro 구독 결제 후 재시도 |
| `auth.json` 이 생성되지 않음 | 권한 부족 또는 SIP 차단 | `mkdir -p ~/.codex && chmod 700 ~/.codex` 후 재로그인 |
| `401 Unauthorized` 가 간헐적으로 발생 | OAuth 토큰 만료 (30일) | `codex login` 재실행 (refresh token 자동 갱신) |
| Rate limit 초과 경고 | 단일 계정 과도 사용 | 2단계로 돌아가 두 번째 계정 추가, `accounts.yaml` 에서 `weight` 조정 |
| Codex가 라우팅에 안 잡힘 | `plans.yaml#codex_oauth_enabled: false` | `bash scripts/switch-plan.sh <plan> --with-codex` |
| `doctor.sh` 에서 `✗ Codex OAuth` | `~/.codex/auth.json` 없음 또는 읽기 불가 | `codex whoami` 로 확인, 실패 시 재로그인 |

### 로그아웃 / 계정 교체

```bash
# 현재 계정 로그아웃
codex logout

# 수동으로 토큰 삭제 (문제 발생 시)
rm ~/.codex/auth.json
# 두 번째 계정:
rm ~/.codex-acct2/auth.json

# 로그아웃 후 하네스에서도 비활성화
bash scripts/switch-plan.sh pro        # --with-codex 없이 실행
```

### 보안 참고

- `~/.codex/auth.json` 은 평문 refresh token을 포함합니다. **절대 git 에 커밋하지 마세요.** (하네스는 `.gitignore` 로 보호)
- 공용 머신에서 사용했다면 작업 후 `codex logout` 실행 권장.
- 토큰 탈취 의심 시: ChatGPT 설정 → **Security → Sessions** 에서 모든 세션 강제 종료 가능.

## 설치

```bash
# ClawHub에서 설치 (로그인 필요)
clawhub install openclaw-harness

# 또는 수동으로 심볼릭 링크
ln -s /path/to/openclaw-harness ~/.openclaw/skills/harness
```

## 영감

- OpenAI Codex Community Meetup 발표 시리즈 (우로보로스 하네스, OMX)
- Claude Code 하네스 생태계 분석

## 라이선스

MIT
