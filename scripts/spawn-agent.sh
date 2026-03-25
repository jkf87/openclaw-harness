#!/usr/bin/env bash
# OpenClaw 하네스 — 에이전트 생성 헬퍼
# sessions_spawn 호출 래퍼
# 사용법: ./spawn-agent.sh <에이전트명> <태스크설명> [모델오버라이드]
set -euo pipefail

# ──────────────────────────────────────────────
# 설정
# ──────────────────────────────────────────────
HARNESS_DIR="${HARNESS_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
AGENTS_DIR="${HARNESS_DIR}/agents"
SCRIPT_DIR="${HARNESS_DIR}/scripts"

AGENT_NAME="${1:-}"
TASK_DESC="${2:-}"
MODEL_OVERRIDE="${3:-}"

if [[ -z "$AGENT_NAME" ]] || [[ -z "$TASK_DESC" ]]; then
    echo "사용법: $0 <에이전트명> <태스크설명> [모델오버라이드]" >&2
    echo "에이전트: planner, worker, reviewer, debugger" >&2
    exit 1
fi

# ──────────────────────────────────────────────
# 에이전트 정의 파일 읽기
# ──────────────────────────────────────────────
AGENT_FILE="${AGENTS_DIR}/${AGENT_NAME}.md"

if [[ ! -f "$AGENT_FILE" ]]; then
    echo "에러: 에이전트 정의 파일을 찾을 수 없습니다: ${AGENT_FILE}" >&2
    exit 1
fi

# YAML frontmatter 추출 (--- 사이)
extract_frontmatter() {
    sed -n '/^---$/,/^---$/p' "$AGENT_FILE" | sed '1d;$d'
}

# 프롬프트 본문 추출 (두 번째 --- 이후)
extract_prompt() {
    sed -n '/^---$/,/^---$/!p' "$AGENT_FILE" | tail -n +2
}

FRONTMATTER=$(extract_frontmatter)
PROMPT=$(extract_prompt)

# ──────────────────────────────────────────────
# frontmatter에서 값 추출 (간단한 YAML 파싱)
# ──────────────────────────────────────────────
get_yaml_value() {
    local key="$1"
    echo "$FRONTMATTER" | grep -E "^${key}:" | head -1 | sed "s/^${key}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//'
}

MODEL_TIER=$(get_yaml_value "model_tier")
SESSION_TYPE=$(echo "$FRONTMATTER" | grep "session_type:" | head -1 | sed 's/.*session_type:[[:space:]]*//')
TIMEOUT_MS=$(echo "$FRONTMATTER" | grep "timeout_ms:" | head -1 | sed 's/.*timeout_ms:[[:space:]]*//')
MAX_TOKENS=$(echo "$FRONTMATTER" | grep "max_tokens:" | head -1 | sed 's/.*max_tokens:[[:space:]]*//')

# 기본값
SESSION_TYPE="${SESSION_TYPE:-isolated}"
TIMEOUT_MS="${TIMEOUT_MS:-300000}"
MAX_TOKENS="${MAX_TOKENS:-32000}"

# ──────────────────────────────────────────────
# 모델 결정
# ──────────────────────────────────────────────
if [[ -n "$MODEL_OVERRIDE" ]]; then
    SELECTED_MODEL="$MODEL_OVERRIDE"
else
    # model_override가 에이전트 정의에 있는지 확인
    AGENT_MODEL_OVERRIDE=$(get_yaml_value "model_override")
    if [[ -n "$AGENT_MODEL_OVERRIDE" ]] && [[ "$AGENT_MODEL_OVERRIDE" != "null" ]]; then
        SELECTED_MODEL="$AGENT_MODEL_OVERRIDE"
    else
        # route-task.sh로 모델 자동 결정
        ROUTING_RESULT=$("${SCRIPT_DIR}/route-task.sh" "$TASK_DESC" "auto" "standard" 2>/dev/null || echo "")
        if [[ -n "$ROUTING_RESULT" ]]; then
            SELECTED_MODEL=$(echo "$ROUTING_RESULT" | grep "model:" | head -1 | sed 's/.*model:[[:space:]]*//')
        else
            # 폴백: 티어 기반 기본 모델
            case "$MODEL_TIER" in
                LOW)    SELECTED_MODEL="glm-5-turbo" ;;
                MEDIUM) SELECTED_MODEL="gpt-5.4-codex" ;;
                HIGH)   SELECTED_MODEL="gpt-5.4-codex" ;;
                *)      SELECTED_MODEL="gpt-5.4-codex" ;;
            esac
        fi
    fi
fi

# ──────────────────────────────────────────────
# 컨텍스트 구성
# ──────────────────────────────────────────────
build_context() {
    cat <<CONTEXT_EOF
# 에이전트: ${AGENT_NAME}
# 모델: ${SELECTED_MODEL}
# 세션 유형: ${SESSION_TYPE}

## 태스크

${TASK_DESC}

## 에이전트 지침

${PROMPT}
CONTEXT_EOF
}

CONTEXT=$(build_context)

# ──────────────────────────────────────────────
# sessions_spawn 호출
# ──────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 에이전트 스포닝: ${AGENT_NAME}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  모델: ${SELECTED_MODEL}"
echo "  세션 유형: ${SESSION_TYPE}"
echo "  타임아웃: $((TIMEOUT_MS / 1000))초"
echo "  최대 토큰: ${MAX_TOKENS}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# OpenClaw sessions_spawn 호출
# 실제 환경에서는 openclaw CLI 또는 API 사용
if command -v openclaw &>/dev/null; then
    openclaw sessions spawn \
        --type "${SESSION_TYPE}" \
        --model "${SELECTED_MODEL}" \
        --timeout "${TIMEOUT_MS}" \
        --prompt "${CONTEXT}"
else
    echo "[시뮬레이션] openclaw sessions spawn 호출" >&2
    echo "spawn_result:"
    echo "  agent: ${AGENT_NAME}"
    echo "  model: ${SELECTED_MODEL}"
    echo "  session_type: ${SESSION_TYPE}"
    echo "  timeout_ms: ${TIMEOUT_MS}"
    echo "  max_tokens: ${MAX_TOKENS}"
    echo "  status: simulated"
fi
