# OpenClaw Harness

> OpenClaw 기반 **Plan → Work → Review** 자동화 하네스. 복잡도에 따라 최적 모델을 라우팅하고, 에이전트 기반 팀 워크플로를 구동합니다.

## 🎯 무엇인가요?

OpenClaw 에이전트 환경에서 복잡한 코딩/구현 태스크를 **체계적으로 분해 → 실행 → 검토**하는 워크플로 엔진입니다.

Claude/Gemini 없이 **GLM-5, GLM-5-Turbo, GPT-5.4-Codex** 만으로 구동됩니다.

## 🏗️ 아키텍처

```
사용자 요청
    │
    ▼
┌──────────┐    복잡도 분석     ┌──────────┐
│ 라우터    │ ──────────────▶ │ 모델 선택 │
│ (rules)  │                   │ (tier)   │
└──────────┘                   └──────────┘
    │                              │
    ▼                              ▼
┌──────────┐    모드 판정      ┌──────────┐
│오케스트레이터│ ──────────────▶ │ 실행 모드 │
│          │                   │solo/para │
└──────────┘                   │  /full   │
    │                              │
    ▼                              ▼
┌─── Plan ───┐ ┌── Work ──┐ ┌── Review ──┐
│ Planner    │ │ Worker(s)│ │ Reviewer   │
│ (HIGH)     │ │ (MEDIUM) │ │ (HIGH)     │
└────────────┘ └──────────┘ └────────────┘
    │              │              │
    └──────── Fix Loop ──────────┘
                   │
                   ▼
              ✅ 완료 / 📤 에스컬레이션
```

## 📁 구조

```
openclaw-harness/
├── harness.yaml           # 마스터 설정 (프로파일, 라우팅, 오케스트레이션)
├── CATALOG.md             # 에이전트/스킬/모델 자동 카탈로그
├── agents/                # 에이전트 프롬프트 정의
│   ├── planner.md         #   태스크 분해 + 계획 수립
│   ├── worker.md          #   계획 기반 구현
│   ├── reviewer.md        #   4관점 코드 리뷰
│   └── debugger.md        #   체계적 근본 원인 분석
├── skills/                # OpenClaw 스킬 (자동 인식)
│   ├── plan/SKILL.md      #   /plan 명령
│   ├── work/SKILL.md      #   /work 명령
│   ├── review/SKILL.md    #   /review 명령
│   ├── debug/SKILL.md     #   /debug 명령
│   └── harness-work/SKILL.md  # /harness-work 전체 사이클
├── routing/               # 모델 라우팅
│   ├── routing-rules.yaml #   복잡도×카테고리 매트릭스
│   ├── models.yaml        #   모델 프로필
│   └── budget-profiles.yaml   # 비용 프로필
├── orchestration/         # 워크플로 엔진
│   ├── pipelines.yaml     #   Plan→Work→Review 파이프라인
│   └── message-protocol.md   # 메시지 프로토콜
├── scripts/               # 유틸리티 스크립트
│   ├── install.sh         #   설치 (심볼릭 링크/복사)
│   ├── doctor.sh          #   설치 상태 진단
│   ├── orchestrate.sh     #   오케스트레이터 CLI
│   ├── route-task.sh      #   라우팅 테스트
│   ├── spawn-agent.sh     #   에이전트 스폰
│   └── catalog-gen.sh     #   CATALOG.md 자동 생성
├── examples/              # 사용 예시
│   ├── example-plan.md
│   ├── example-work-result.md
│   └── example-review.md
├── state/                 # 런타임 상태 (gitignore)
└── logs/                  # 실행 로그 (gitignore)
```

## 🚀 설치

### 전제 조건
- [OpenClaw](https://github.com/openclaw/openclaw) 설치됨
- GLM-5, GPT-5.4-Codex API 접근 가능

### 설치 (심볼릭 링크)

```bash
git clone https://github.com/conanssam/openclaw-harness.git
cd openclaw-harness

# 심볼릭 링크 (권장 — 업데이트가 자동 반영됨)
./scripts/install.sh --link

# 또는 복사
./scripts/install.sh --copy
```

### 스킬 배포

OpenClaw가 "하네스" 키워드를 인식하도록 스킬을 배포합니다:

```bash
# ~/.openclaw/skills/harness/ 에 심볼릭 링크 생성
ln -s ~/conanssamm4/harness/openclaw-harness/skills/* ~/.openclaw/skills/harness/
```

### 설치 확인

```bash
./scripts/doctor.sh
```

## 📋 사용법

### 자연어 요청 (권장)

하네스 스킬이 설치되면, 그냥 자연어로 요청하면 됩니다:

```
"이 PR을 리뷰해줘"         → /review 자동 트리거
"이 기능 구현 계획해줘"    → /plan 자동 트리거
"하네스로 이거 만들어줘"   → /harness-work 전체 사이클
```

### 슬래시 명령

| 명령 | 설명 |
|------|------|
| `/plan` | 태스크를 분해하고 구현 계획 생성 |
| `/work` | 계획을 실행하여 코드 작성 |
| `/work all` | 전체 태스크 구현 |
| `/review` | 4관점 코드 리뷰 실행 |
| `/debug` | 4단계 체계적 디버깅 |
| `/harness-work` | Plan→Work→Review 전체 사이클 |

### CLI 직접 실행

```bash
# 오케스트레이터
./scripts/orchestrate.sh full "유저 인증 시스템 구현"
./scripts/orchestrate.sh solo "버그 수정: 로그인 500 에러"

# 라우팅 테스트
./scripts/route-task.sh "React 컴포넌트 리팩토링"
```

## 🤖 모델 라우팅

복잡도 × 카테고리 매트릭스로 최적 모델을 자동 선택합니다:

| 카테고리 | LOW | MEDIUM | HIGH |
|----------|-----|--------|------|
| 코딩 (일반) | GLM-5-Turbo | GPT-5.4-Codex | GPT-5.4-Codex |
| 코딩 (아키텍처) | GPT-5.4-Codex | GPT-5.4-Codex | GPT-5.4-Codex |
| 한국어 NLP | GLM-5-Turbo | GLM-5 | GLM-5 |
| 콘텐츠 생성 | GLM-5-Turbo | GLM-5 | GLM-5 |
| 보안 | GPT-5.4-Codex | GPT-5.4-Codex | GPT-5.4-Codex |
| 디버깅 | GLM-5-Turbo | GPT-5.4-Codex | GPT-5.4-Codex |

### 한국어 감지
- 한국어 비율 > 70%: GLM 계열 자동 추천
- 코딩 태스크에서도 한국어 주문/주석 고려

## ⚙️ 프로파일

| 프로파일 | 설명 | 에이전트 | 라우팅 | 오케스트레이션 |
|----------|------|---------|--------|--------------|
| `minimal` | 가드레일만 | 없음 | 꺼짐 | 꺼짐 |
| `standard` | 핵심 워크플로 | planner, worker, reviewer | 켜짐 | 꺼짐 |
| `full` | 전체 팀 오케스트레이션 | + debugger | 켜짐 | 켜짐 |

`harness.yaml`에서 `profile` 설정으로 변경.

## 🔄 Fix Loop

Reviewer가 `REQUEST_CHANGES`를 반환하면 자동 수정 루프가 작동합니다:

1. **1차**: findings 기반 직접 수정
2. **2차**: 접근 방식 변경
3. **3차**: 최종 시도 + 부분 완료 보고 → 사용자 에스컬레이션

## 🛡️ 안전 가드레일

- `evidence_required`: 완료 주장 시 증거(파일/커밋/테스트) 필수
- `hitl` (Human-in-the-Loop): 계획 승인, 리뷰 알림, 수정 제어
- 회로 차단기(circuit breaker): 동일 에러 5회 연속 → 자동 중단

## 📝 작업 예시

```bash
# 전체 사이클 — 유저 인증 시스템
./scripts/orchestrate.sh full "JWT 기반 유저 인증 API 구현"

# 단일 태스크 — 버그 수정
./scripts/orchestrate.sh solo "로그인 시 500 에러 수정"

# 병렬 — 독립 태스크 2개
./scripts/orchestrate.sh parallel "회원가입 폼 검증 추가, 비밀번호 재설정 API 구현"
```

## ⚠️ 제한 사항

- Claude/Gemini 미지원 (GLM + OpenAI Codex만)
- 오케스트레이션은 OpenClaw 서브에이전트 환경 필요
- 고비용 모델(GPT-5.4-Codex) 동시 실행 수 제한: 3

## 📄 라이선스

MIT

## 👤 작성자

[conanssam](https://github.com/conanssam)
