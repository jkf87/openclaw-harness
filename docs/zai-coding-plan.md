# Z.ai 코딩플랜 셋업 가이드 (Lite / Pro / Max)

OpenClaw 하네스를 Z.ai 코딩플랜에 맞춰 사용하는 전체 가이드입니다.
선택적으로 OpenAI Codex OAuth(ChatGPT Plus/Pro 구독)를 병행할 수 있습니다.

## 1. 플랜 선택

| 플랜 | 가격 | 모델 | 일일 토큰 | 동시 워커 | 권장 사용자 |
|------|------|------|-----------|-----------|-------------|
| **Lite** | $3/월 | GLM-5 Turbo, GLM-5 | 1.5M | 2 | 개인/학습/사이드 프로젝트 |
| **Pro**  | $15/월 | + GLM-5.1 | 8M | 4 | 프로 개발자/소규모 팀 |
| **Max**  | $30/월 | 풀 모델 + 우선 슬롯 | 25M | 7 | 헤비 유저/팀/오케스트레이션 |

가입: https://z.ai/subscribe?ic=OTYO9JPFNV

## 2. Z.ai OAuth 인증

```bash
# OpenClaw 온보드
openclaw onboard

# 프롬프트에서 "Z.ai Coding Plan" 선택 → 브라우저 OAuth 완료
# 발급된 토큰은 ~/.openclaw/credentials 에 저장됨
```

API 키 방식을 선호하는 경우:

```bash
export ZAI_API_KEY="zai_xxx..."
# (.zshrc 또는 .envrc 에 영구 저장)
```

## 3. 활성 플랜 지정

`routing/plans.yaml` 의 `active_plan` 을 본인 구독에 맞게 변경:

```yaml
active_plan: pro              # lite | pro | max
codex_oauth_enabled: false    # Codex 병행 시 true
```

또는 환경변수로:

```bash
export ZAI_CODING_PLAN=pro
```

빠른 전환:

```bash
bash scripts/switch-plan.sh lite
bash scripts/switch-plan.sh pro
bash scripts/switch-plan.sh max
bash scripts/switch-plan.sh pro --with-codex
```

## 4. Claude Code 연동

`~/.claude/settings.json` 에 Z.ai Anthropic 호환 엔드포인트를 추가:

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

> ⚠️ **Lite 플랜 사용자**: `OPUS_MODEL` 을 `glm-5` 로 변경하세요. Lite는 GLM-5.1 미포함입니다.

새 터미널에서:

```bash
claude
/status   # 모델 매핑 확인
```

## 5. OpenAI Codex OAuth 병행 (선택)

ChatGPT Plus($20) / Pro($200) 구독을 보유했다면 Codex CLI OAuth로 GPT-5.4 Codex를 함께 사용할 수 있습니다. 라우팅 엔진은 고난도 아키텍처/보안 태스크를 Codex로 자동 분배합니다.

### 5-1. Codex 로그인

```bash
# 메인 계정
codex login

# 두 번째 계정 (선택)
CODEX_HOME=~/.codex-acct2 codex login
```

### 5-2. accounts.yaml 활성화

`routing/accounts.yaml` 의 `pools.codex.accounts[*].enabled` 를 `true` 로:

```yaml
pools:
  codex:
    optional: true
    accounts:
      - id: codex-primary
        auth_type: oauth_codex
        codex_home: ~/.codex
        enabled: true            # ✅ 켜기
```

### 5-3. 라우팅 엔진에 Codex 알리기

`routing/plans.yaml`:

```yaml
codex_oauth_enabled: true
```

이렇게 하면 `codex_overlay` 가 적용되어:

| 카테고리 | 복잡도 | Z.ai 단독 | Z.ai + Codex |
|----------|--------|-----------|---------------|
| coding_arch | HIGH | glm-5.1 | **gpt-5.4-codex** |
| coding_arch | MEDIUM | glm-5.1 | **gpt-5.4-codex** |
| security    | HIGH | glm-5.1 | **gpt-5.4-codex** |
| security    | MEDIUM | glm-5.1 | **gpt-5.4-codex** |
| coding_general | HIGH | glm-5.1 | **gpt-5.4-codex** |
| debugging   | HIGH | glm-5.1 | **gpt-5.4-codex** |
| **reasoning** | HIGH | glm-5.1 | **gpt-5.4-codex** 🧠 |
| **data_analysis** | HIGH | glm-5.1 | **gpt-5.4-codex** 🧠 |

추가로 태스크 텍스트에 **추론 집약 신호**(증명/알고리즘/복잡도/불변조건/race condition/distributed consensus 등)가 감지되면, 카테고리와 무관하게 `reasoning_score` 최상위 모델로 라우팅됩니다:

- Codex 활성 + HIGH → **GPT-5.4 Codex** (reasoning_score 97, extended thinking)
- Pro/Max (Codex 없음) → **GLM-5.1** (reasoning_score 95)
- Lite → GLM-5 (상한)

나머지(한국어 NLP, 콘텐츠)는 그대로 GLM 시리즈가 담당합니다.

## 6. 동작 확인

```bash
# 진단
bash scripts/doctor.sh

# 라우팅 시뮬레이션
bash scripts/route-task.sh "REST API 인증 미들웨어 구현" --dry-run

# 실제 사이클 시작
bash scripts/orchestrate.sh "TODO 앱에 검색 기능 추가"
```

`bash scripts/bridge.sh status` 로 실시간 상태를 확인할 수 있습니다.

## 7. 트러블슈팅

| 증상 | 해결 |
|------|------|
| `glm-5.1 not allowed` 경고 | Lite 플랜이면 정상. Pro 이상으로 업그레이드하거나 `glm-5` 사용 |
| 401 from Z.ai | `openclaw onboard` 재실행 또는 `ZAI_API_KEY` 확인 |
| Codex rate limit | `routing/accounts.yaml` 에 두 번째 `codex_home` 추가 |
| 한국어 응답 품질 저하 | `prompt_adaptation` 으로 GLM 우선 라우팅 활성 확인 |
| 동시 워커 한도 초과 | `pipelines.yaml#concurrency.by_plan` 의 본인 플랜 수치 확인 |

## 8. 플랜 비교 매트릭스 요약

```
              ┌────────┬─────────┬──────────┐
              │  LITE  │   PRO   │   MAX    │
              ├────────┼─────────┼──────────┤
glm-5-turbo   │   ✅   │   ✅    │    ✅    │
glm-5         │   ✅   │   ✅    │    ✅    │
glm-5.1       │   ❌   │   ✅    │    ✅    │
fix loop max  │   2    │   3     │    4     │
full pipeline │   ⚠️   │   ✅    │    ✅    │
priority slot │   ❌   │   ❌    │    ✅    │
              └────────┴─────────┴──────────┘
              + Codex OAuth (선택): 코딩/보안 HIGH 오버레이
```
