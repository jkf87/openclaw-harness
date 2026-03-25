#!/usr/bin/env bash
# OpenClaw 하네스 — 설치 상태 진단 스크립트
# 의존성, 설정 파일, 디렉토리 구조 검증
# 사용법: ./doctor.sh
set -euo pipefail

# ──────────────────────────────────────────────
# 설정
# ──────────────────────────────────────────────
HARNESS_DIR="${HARNESS_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

PASS=0
WARN=0
FAIL=0

# ──────────────────────────────────────────────
# 출력 헬퍼
# ──────────────────────────────────────────────
check_pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
check_warn() { echo "  ⚠ $1"; WARN=$((WARN + 1)); }
check_fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

# ──────────────────────────────────────────────
# 1. 핵심 파일 검사
# ──────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OpenClaw 하네스 진단"
echo "  하네스 디렉토리: ${HARNESS_DIR}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "[1/5] 핵심 파일 검사"

required_files=(
    "harness.yaml:마스터 설정"
    "CATALOG.md:에이전트/스킬 카탈로그"
    "agents/planner.md:계획 에이전트"
    "agents/worker.md:구현 에이전트"
    "agents/reviewer.md:리뷰 에이전트"
    "agents/debugger.md:디버그 에이전트"
    "skills/plan/SKILL.md:계획 스킬"
    "skills/work/SKILL.md:구현 스킬"
    "skills/review/SKILL.md:리뷰 스킬"
    "skills/debug/SKILL.md:디버그 스킬"
    "skills/harness-work/SKILL.md:오케스트레이터 스킬"
    "routing/models.yaml:모델 카탈로그"
    "routing/routing-rules.yaml:라우팅 규칙"
    "routing/budget-profiles.yaml:예산 프로파일"
    "orchestration/pipelines.yaml:파이프라인 정의"
    "orchestration/message-protocol.md:메시지 프로토콜"
)

for entry in "${required_files[@]}"; do
    file="${entry%%:*}"
    label="${entry#*:}"
    if [[ -f "${HARNESS_DIR}/${file}" ]]; then
        check_pass "${label} (${file})"
    else
        check_fail "${label} (${file}) — 파일 누락!"
    fi
done

# ──────────────────────────────────────────────
# 2. 스크립트 실행 권한 검사
# ──────────────────────────────────────────────
echo ""
echo "[2/5] 스크립트 실행 권한 검사"

scripts=(
    "scripts/route-task.sh"
    "scripts/orchestrate.sh"
    "scripts/spawn-agent.sh"
    "scripts/install.sh"
    "scripts/catalog-gen.sh"
    "scripts/doctor.sh"
)

for script in "${scripts[@]}"; do
    if [[ -f "${HARNESS_DIR}/${script}" ]]; then
        if [[ -x "${HARNESS_DIR}/${script}" ]]; then
            check_pass "${script} (실행 가능)"
        else
            check_warn "${script} — 실행 권한 없음 (chmod +x 필요)"
        fi
    else
        check_fail "${script} — 파일 누락!"
    fi
done

# ──────────────────────────────────────────────
# 3. YAML 유효성 검사 (기본)
# ──────────────────────────────────────────────
echo ""
echo "[3/5] YAML 구문 검사"

yaml_files=(
    "harness.yaml"
    "routing/models.yaml"
    "routing/routing-rules.yaml"
    "routing/budget-profiles.yaml"
    "orchestration/pipelines.yaml"
)

for yaml_file in "${yaml_files[@]}"; do
    full_path="${HARNESS_DIR}/${yaml_file}"
    if [[ ! -f "$full_path" ]]; then
        check_fail "${yaml_file} — 파일 없음"
        continue
    fi

    # 기본 YAML 구문 검사 (탭 문자, 잘못된 들여쓰기)
    if grep -qP '\t' "$full_path" 2>/dev/null; then
        check_warn "${yaml_file} — 탭 문자 발견 (공백 사용 권장)"
    else
        check_pass "${yaml_file} (구문 기본 검사 통과)"
    fi
done

# ──────────────────────────────────────────────
# 4. 환경 변수 검사
# ──────────────────────────────────────────────
echo ""
echo "[4/5] 환경 변수 검사"

env_vars=(
    "ZAI_API_KEY:Z.ai API 키 (GLM-5 시리즈)"
    "OPENAI_API_KEY:OpenAI API 키 (GPT-5.4 Codex)"
)

for entry in "${env_vars[@]}"; do
    var="${entry%%:*}"
    label="${entry#*:}"
    if [[ -n "${!var:-}" ]]; then
        check_pass "${label} (${var} 설정됨)"
    else
        check_warn "${label} (${var} 미설정) — 해당 모델 사용 불가"
    fi
done

# ──────────────────────────────────────────────
# 5. OpenClaw 연동 검사
# ──────────────────────────────────────────────
echo ""
echo "[5/5] OpenClaw 연동 검사"

if command -v openclaw &>/dev/null; then
    check_pass "openclaw CLI 설치됨"
else
    check_warn "openclaw CLI 미설치 — 시뮬레이션 모드로 동작"
fi

if [[ -d "${HOME}/.openclaw" ]]; then
    check_pass "~/.openclaw/ 디렉토리 존재"
else
    check_warn "~/.openclaw/ 디렉토리 없음 — OpenClaw 미설치 가능성"
fi

if [[ -L "${HOME}/.openclaw/harness" ]] || [[ -d "${HOME}/.openclaw/harness" ]]; then
    check_pass "하네스 설치됨 (~/.openclaw/harness/)"
else
    check_warn "하네스 미설치 — install.sh 실행 필요"
fi

# ──────────────────────────────────────────────
# 결과 요약
# ──────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  진단 결과"
echo "  ✓ 통과: ${PASS}"
echo "  ⚠ 경고: ${WARN}"
echo "  ✗ 실패: ${FAIL}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$FAIL" -gt 0 ]]; then
    echo ""
    echo "  ✗ 실패 항목이 있습니다. 위 내용을 확인하세요."
    exit 1
elif [[ "$WARN" -gt 0 ]]; then
    echo ""
    echo "  ⚠ 경고 항목이 있지만 기본 동작에는 문제없습니다."
    exit 0
else
    echo ""
    echo "  모든 검사 통과! 하네스가 정상 상태입니다."
    exit 0
fi
