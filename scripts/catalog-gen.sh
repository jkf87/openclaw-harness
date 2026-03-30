#!/usr/bin/env bash
# OpenClaw 하네스 — CATALOG.md 자동 생성 스크립트
# agents/ + skills/ 디렉토리를 스캔하여 카탈로그 생성
# 사용법: ./catalog-gen.sh
set -euo pipefail

# ──────────────────────────────────────────────
# 설정
# ──────────────────────────────────────────────
HARNESS_DIR="${HARNESS_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
AGENTS_DIR="${HARNESS_DIR}/agents"
SKILLS_DIR="${HARNESS_DIR}/skills"
CATALOG_FILE="${HARNESS_DIR}/CATALOG.md"
HARNESS_YAML="${HARNESS_DIR}/harness.yaml"

# 현재 프로파일 읽기 (간단한 파싱)
PROFILE="standard"
if [[ -f "$HARNESS_YAML" ]]; then
    PROFILE=$(grep "^profile:" "$HARNESS_YAML" | sed 's/profile:[[:space:]]*//' | tr -d '"' || echo "standard")
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S+09:00)

# ──────────────────────────────────────────────
# frontmatter에서 값 추출
# ──────────────────────────────────────────────
get_field() {
    local file="$1"
    local field="$2"
    sed -n '/^---$/,/^---$/p' "$file" | grep -E "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//'
}

get_nested_field() {
    local file="$1"
    local field="$2"
    sed -n '/^---$/,/^---$/p' "$file" | grep -E "^[[:space:]]+${field}:" | head -1 | sed "s/.*${field}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//'
}

# ──────────────────────────────────────────────
# 카탈로그 생성
# ──────────────────────────────────────────────
{
    cat <<HEADER
# OpenClaw 하네스 카탈로그

> 자동 생성됨. 수정 금지. \`catalog-gen.sh\`로 재생성.
> 생성 시각: ${TIMESTAMP}
> 프로파일: ${PROFILE}

## 사용 가능 에이전트

| 에이전트 | 설명 | 모델 티어 | 세션 유형 |
|---------|------|----------|----------|
HEADER

    # 에이전트 스캔
    for agent_file in "${AGENTS_DIR}"/*.md; do
        [[ -f "$agent_file" ]] || continue
        [[ "$(basename "$agent_file")" == "*.md" ]] && continue

        name=$(get_field "$agent_file" "name")
        desc=$(get_field "$agent_file" "description")
        tier=$(get_field "$agent_file" "model_tier")
        tier=$(printf '%s' "$tier" | sed 's/[[:space:]]*#.*$//' | xargs)
        session_type=$(get_nested_field "$agent_file" "session_type")

        [[ -z "$name" ]] && continue

        echo "| ${name} | ${desc} | ${tier} | ${session_type:-isolated} |"
    done

    cat <<SKILLS_HEADER

## 사용 가능 스킬

| 스킬 | 슬래시 명령 | 설명 |
|------|-----------|------|
SKILLS_HEADER

    # 스킬 스캔
    if [[ -f "${HARNESS_DIR}/SKILL.md" ]]; then
        root_name=$(get_field "${HARNESS_DIR}/SKILL.md" "name")
        root_desc=$(get_field "${HARNESS_DIR}/SKILL.md" "description")
        [[ -n "$root_name" ]] && echo "| ${root_name} | /${root_name} | ${root_desc} |"
    fi

    if [[ -d "${SKILLS_DIR}" ]]; then
    for skill_dir in "${SKILLS_DIR}"/*/; do
        [[ -d "$skill_dir" ]] || continue
        skill_file="${skill_dir}SKILL.md"
        [[ -f "$skill_file" ]] || continue

        name=$(get_field "$skill_file" "name")
        desc=$(get_field "$skill_file" "description")

        # 트리거에서 슬래시 명령 추출
        slash=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep "slash:" | head -1 | sed 's/.*slash:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')

        [[ -z "$name" ]] && continue

        echo "| ${name} | ${slash:-/${name}} | ${desc} |"
    done
    fi

    cat <<MODELS_HEADER

## 모델 라우팅 (Claude/Gemini 제외)

| 모델 | 프로바이더 | 티어 | 한국어 | 코딩 | 추론 |
|------|-----------|------|--------|------|------|
| GLM-5 Turbo | Z.ai | LOW | 95 | 70 | 60 |
| GPT-5.3 Codex | OpenAI | MEDIUM | 70 | 95 | 90 |
| GLM-5 | Z.ai | MEDIUM | 95 | 80 | 80 |
| GLM-5.1 | Z.ai | HIGH | 96 | 88 | 94 |

## 사용법

스킬을 호출하려면 자연어로 요청하거나 슬래시 명령 사용:
- "이 기능을 계획해줘" → /plan 자동 트리거
- "/work all" → 전체 태스크 구현
- "/review" → 코드 리뷰 실행
- "/debug" → 체계적 디버깅
- "/harness-work" → Plan→Work→Review 전체 사이클
MODELS_HEADER

} > "${CATALOG_FILE}"

echo "CATALOG.md 생성 완료: ${CATALOG_FILE}"
agent_count=$(find "${AGENTS_DIR}" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ -d "${SKILLS_DIR}" ]]; then
    skill_count=$(find "${SKILLS_DIR}" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
else
    skill_count=0
fi
[[ -f "${HARNESS_DIR}/SKILL.md" ]] && skill_count=$((skill_count + 1))

echo "  에이전트: ${agent_count}개"
echo "  스킬: ${skill_count}개"
