# 계정 풀 관리 (OAuth Round-Robin / Fan-Out)

여러 OAuth 계정/API 키를 풀로 관리하여 rate limit을 분산하고 가용성을 높이는 유틸리티입니다.

## 개요

| 전략 | 설명 | 적합한 상황 |
|------|------|------------|
| **round_robin** | 순차적으로 계정을 돌려가며 사용 | 일반적인 rate limit 분산, 한 계정이 다 쓰면 다음 계정으로 |
| **fan_out** | 사용 가능한 모든 계정을 동시에 반환 | 병렬 호출로 처리량 극대화 (rate limit당 속도가 더 빠름) |

## 빠른 시작

```bash
# 1. 환경변수에 API 키 설정
export ZAI_API_KEY="your-primary-key"
export ZAI_API_KEY_2="your-secondary-key"
export OPENAI_API_KEY="your-openai-key"

# 2. 다음 계정 선택 (round-robin)
./scripts/account-pool.sh next zai

# 3. 전체 상태 확인
./scripts/account-pool.sh status
```

## 설정 (`routing/accounts.yaml`)

```yaml
pool_defaults:
  strategy: round_robin          # 기본 전략
  cooldown_seconds: 60           # rate limit 시 쿨다운
  max_cooldown_seconds: 600      # 최대 쿨다운 (지수 백오프 상한)
  backoff_multiplier: 2          # 연속 오류 시 배수

pools:
  zai:
    strategy: round_robin
    accounts:
      - id: zai-primary
        env_key: ZAI_API_KEY     # 환경변수 이름
        weight: 10               # 높을수록 우선
        enabled: true
      - id: zai-secondary
        env_key: ZAI_API_KEY_2
        weight: 5
        enabled: true
```

### 계정 추가하기

1. `routing/accounts.yaml`에서 해당 풀의 `accounts:` 아래에 추가
2. 해당 환경변수에 API 키 설정
3. `./scripts/account-pool.sh status <pool>` 로 확인

## 명령어

### `next <pool>` — 다음 계정 선택

라운드 로빈으로 다음 사용 가능한 계정을 선택합니다.
- 쿨다운 중인 계정은 자동 건너뜀
- 환경변수 미설정 계정도 건너뜀
- 가중치 순으로 정렬 후 순환

```bash
$ ./scripts/account-pool.sh next zai
account_selection:
  pool: zai
  account_id: zai-primary
  env_key: ZAI_API_KEY
  strategy: round_robin
  timestamp: 2026-04-09T12:00:00Z
```

### `fanout <pool>` — 동시 호출용 계정 목록

사용 가능한 모든 계정을 반환합니다. 병렬 API 호출에 사용합니다.

```bash
$ ./scripts/account-pool.sh fanout openai
fan_out_accounts:
  pool: openai
  available_count: 2
  cooldown_count: 0
  accounts:
    - id: openai-primary
      env_key: OPENAI_API_KEY
      weight: 10
    - id: openai-secondary
      env_key: OPENAI_API_KEY_2
      weight: 5
```

### `cooldown <pool> <account> [reason]` — 쿨다운 등록

rate limit이나 인증 오류 발생 시 호출합니다. 지수 백오프가 자동 적용됩니다.

```bash
# 첫 번째 오류: 60초 쿨다운
$ ./scripts/account-pool.sh cooldown zai zai-primary rate_limit

# 두 번째 연속 오류: 120초 (60 * 2^1)
# 세 번째: 240초 (60 * 2^2)
# 최대: 600초
```

reason 값: `rate_limit` (기본), `auth_error`, `server_error` 등

### `release <pool> <account>` — 쿨다운 해제

수동으로 쿨다운을 해제합니다. 연속 오류 카운터도 초기화됩니다.

### `status [pool]` — 상태 조회

풀 전체 또는 특정 풀의 상태를 조회합니다.

### `reset [pool]` — 상태 초기화

특정 풀 또는 전체 상태를 초기화합니다.

## Round-Robin vs Fan-Out: 언제 무엇을 쓸까

### Round-Robin 추천 상황
- API 비용을 균등 분산하고 싶을 때
- 한 번에 하나의 요청만 보내는 순차 작업
- 계정별 일일 한도가 있을 때 (하나 소진 → 다음)

### Fan-Out 추천 상황
- **속도가 핵심**: 여러 계정으로 동시 호출하면 rate limit 대비 처리량 N배
- 큰 배치 작업을 빨리 끝내야 할 때
- 결과 경쟁 (first-response-wins) 패턴

### 하이브리드 예시 (orchestrate.sh 연동)

```bash
# orchestrate.sh에서 worker 생성 시:
strategy=$(./scripts/account-pool.sh status zai | grep strategy | sed 's/.*: //')

if [[ "$strategy" == "fan_out" ]]; then
    # 모든 계정으로 동시 요청
    accounts=$(./scripts/account-pool.sh fanout zai)
    # ... 병렬 worker 생성
else
    # 순차 계정 선택
    account=$(./scripts/account-pool.sh next zai)
    # ... 단일 worker 생성
fi

# API 에러 발생 시:
./scripts/account-pool.sh cooldown zai zai-primary rate_limit
# → 다음 next 호출에서 자동으로 다른 계정 선택
```

## 상태 파일

`state/account-pool-state.json`에 JSON으로 저장됩니다.

```json
{
  "pools": {
    "zai": {
      "last_index": 1,
      "accounts": {
        "zai-primary": {
          "last_used": 1712678400,
          "use_count": 5
        }
      }
    }
  },
  "last_updated": "2026-04-09T12:00:00Z"
}
```

## 스모크 테스트

```bash
./scripts/account-pool-demo.sh
```

더미 토큰으로 전체 흐름(초기화, round-robin, cooldown, failover, release, fan-out)을 검증합니다.

## 의존성

- `bash` (4.x+)
- `python3` (JSON 상태 관리)
- `grep`, `sed` (YAML 파싱)
