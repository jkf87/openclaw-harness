#!/usr/bin/env bash
# OpenClaw 하네스 — 계정 풀 스모크 테스트
# 실제 API 호출 없이 round-robin, cooldown, fan-out 동작 검증
set -euo pipefail

HARNESS_DIR="${HARNESS_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
POOL="${HARNESS_DIR}/scripts/account-pool.sh"
TEST_STATE="${HARNESS_DIR}/state/account-pool-test-state.json"

PASS=0; FAIL=0
check_pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
check_fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  계정 풀 스모크 테스트"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 테스트용 더미 토큰
export ZAI_API_KEY="test-zai-1"
export ZAI_API_KEY_2="test-zai-2"
export OPENAI_API_KEY="test-openai-1"
export OPENAI_API_KEY_2="test-openai-2"
export POOL_STATE="${TEST_STATE}"

SPAWN="${HARNESS_DIR}/scripts/spawn-agent.sh"

# [1] 초기화
echo "[1/9] 초기화"
if bash "${POOL}" reset 2>&1 | grep -q "초기화"; then
    check_pass "전체 풀 초기화"
else
    check_fail "전체 풀 초기화"
fi

# [2] 풀 요약
echo ""
echo "[2/9] 풀 요약 조회"
output=$(bash "${POOL}" status 2>&1)
if echo "$output" | grep -q "zai" && echo "$output" | grep -q "openai"; then
    check_pass "zai + openai 풀 감지"
else
    check_fail "풀 감지 실패"
fi

# [3] 라운드 로빈
echo ""
echo "[3/9] 라운드 로빈 (zai 풀, 3회 순환)"
for i in 1 2 3; do
    acct=$(bash "${POOL}" next zai 2>/dev/null | grep 'account_id:' | sed 's/.*: //')
    if [[ -n "$acct" ]]; then
        check_pass "선택 #${i}: ${acct}"
    else
        check_fail "선택 #${i} 실패"
    fi
done

# [4] 쿨다운 + 페일오버
echo ""
echo "[4/9] 쿨다운 + 페일오버"
bash "${POOL}" cooldown zai zai-primary rate_limit >/dev/null 2>&1
acct=$(bash "${POOL}" next zai 2>/dev/null | grep 'account_id:' | sed 's/.*: //')
if [[ "$acct" == "zai-secondary" ]]; then
    check_pass "쿨다운 후 zai-secondary 페일오버"
else
    check_fail "페일오버 실패 (got: ${acct:-empty})"
fi

# [5] 쿨다운 해제
echo ""
echo "[5/9] 쿨다운 해제"
bash "${POOL}" release zai zai-primary 2>/dev/null
if bash "${POOL}" status zai 2>/dev/null | grep -A3 "zai-primary" | grep -q "status: ready"; then
    check_pass "zai-primary → ready 복구"
else
    check_fail "쿨다운 해제 실패"
fi

# [6] Fan-out
echo ""
echo "[6/9] Fan-out (openai 풀)"
count=$(bash "${POOL}" fanout openai 2>/dev/null | grep 'available_count:' | sed 's/.*: //')
if [[ "${count:-0}" -ge 2 ]]; then
    check_pass "Fan-out: ${count}개 계정 사용 가능"
else
    check_fail "Fan-out 계정 수 부족 (${count:-0})"
fi

bash "${POOL}" reset >/dev/null

# [7] spawn-agent 통합: zai 모델은 zai 풀로 라우팅
echo ""
echo "[7/9] spawn-agent 통합 — glm 모델 → zai 풀 라우팅"
out=$(bash "${SPAWN}" worker "test" glm-5 2>/dev/null || true)
if echo "$out" | grep -q "pool: zai" && echo "$out" | grep -q "account_id: zai-"; then
    check_pass "glm-5 → zai 풀에서 토큰 선택"
else
    check_fail "glm-5 → zai 풀 라우팅 실패"
fi

# [8] spawn-agent 통합: gpt 모델은 openai 풀로
echo ""
echo "[8/9] spawn-agent 통합 — gpt 모델 → openai 풀 라우팅"
out=$(bash "${SPAWN}" worker "test" gpt-5.3-codex 2>/dev/null || true)
if echo "$out" | grep -q "pool: openai" && echo "$out" | grep -q "account_id: openai-"; then
    check_pass "gpt-5.3-codex → openai 풀에서 토큰 선택"
else
    check_fail "gpt-5.3-codex → openai 풀 라우팅 실패"
fi

# [9] spawn-agent 통합: 4회 호출 시 두 계정 모두 등장 (round-robin)
echo ""
echo "[9/9] spawn-agent 통합 — 4회 호출 라운드 로빈"
bash "${POOL}" reset >/dev/null
seen_primary=0
seen_secondary=0
for i in 1 2 3 4; do
    out=$(bash "${SPAWN}" worker "test" glm-5 2>/dev/null || true)
    echo "$out" | grep -q "account_id: zai-primary" && seen_primary=1
    echo "$out" | grep -q "account_id: zai-secondary" && seen_secondary=1
done
if [[ "$seen_primary" -eq 1 ]] && [[ "$seen_secondary" -eq 1 ]]; then
    check_pass "4회 호출에 두 계정 모두 사용됨"
else
    check_fail "라운드 로빈 미작동 (primary=${seen_primary}, secondary=${seen_secondary})"
fi

# 정리
rm -f "${TEST_STATE}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  결과: ✓ ${PASS} 통과 / ✗ ${FAIL} 실패"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0
