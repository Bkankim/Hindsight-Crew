# Hindsight-Crew

**한국어** · [English](README.en.md)

[Hindsight](https://github.com/vectorize-io/hindsight) 위에 올린 **자체 호스팅(self-hosted) · 에이전트가 부트스트랩 가능한** 팀 메모리 스택 — 무인(unattended) **단일 명령**으로 재현되며, **검증 가능한 테넌트 격리(verifiable tenant isolation)**를 핵심으로 한다.

> 상태: **v1 진행 중.** 성공 기준은 `verify/verify-all.sh`가 `0`으로 종료하는 것.

## 무엇인가 / 언제 쓰나

정책을 강제하는 **게이트웨이**를 앞단에 둔 자체 호스팅 Hindsight 메모리 스택을 세워, 팀이 개인별 `personal` 뱅크와 공유 `team` 뱅크를 **격리**하고 그것을 **증명**할 수 있게 하는 공개 MIT 레퍼런스 패키지. 온프렘 / 외부 클라우드 미사용 배포, 그리고 단일 명령으로 고객 프로젝트에 투입하는 것을 목표로 만들었다.

Hindsight의 기본 인증은 **단일 공유 키** 하나뿐이라 **identity→bank 강제(enforcement)가 없다.** 그래서 "클라이언트를 그냥 8888에 붙이면 된다"는 안일한 가정은 테넌트 간 데이터를 새게 만든다. Hindsight-Crew는 그 앞에 **본문 인지(body-aware) · 기본 거부(deny-by-default) 게이트웨이**를 두어 단일 강제 지점으로 삼는다.

## 빠른 시작 (무인)

```sh
cp .env.example .env.local   # 선택: 없으면 bootstrap이 데모 시크릿을 자동 시딩
./bootstrap                  # 기본 ko-full(한국어, ~4GB+ 필요); 또는 ./bootstrap --cpu-en (경량/2GB/CI)
```

`./bootstrap`은 `verify/verify-all.sh`가 `0`으로 종료할 때 **그리고 그때만(iff)** 통과(green)다 (게이트 6개 + 드리프트 프로브).

## 합격 게이트 (`verify/verify-all.sh`)

| 게이트 | 증명하는 것 |
|---|---|
| ① health | 게이트웨이 프런트가 200 반환 |
| ② banks | personal + team 뱅크 프로비저닝됨 |
| ③ roundtrip | `sync_retain` → `recall`이 적재한 메모리를 반환 |
| ④ isolation + attribution | A 토큰이 B의 뱅크를 못 읽음; team 적재는 해당 멤버로 귀속(round-trip 검증) |
| ⑤ adversarial | 미상/ACL 없는 토큰, 경로 traversal, `X-Bank-Id` + **본문 `arguments.bank`** 스머글링, 귀속 위조를 모두 거부 |
| ⑥ restore | 백업 → 빈 스택 복원 → 적재/recall 동작 |

## 시스템 요구사항

> 아래 최소 수치는 추측이 아니라 `bootstrap` / `verify-all`이 라이브 스택에서 **실측(measured)**한 값(관측된 RAM/디스크)이다.

- **기본 — `ko-full` 프로파일 (한국어, 대상 용도 권장):** `BAAI/bge-m3` (1024차원) + `BAAI/bge-reranker-v2-m3` (공식 다국어 568M; `dragonkue/bge-reranker-v2-m3-ko`는 선택적 한국어 튜닝 핫스왑 — 리랭커는 차원에 묶이지 않아 **언제든 교체 가능**). 오프라인 `LLM=none`. **실측:** 런타임 ~1.5–2.1 GB RAM(hindsight) + ~59 MB(gateway), 디스크 ~14 GB(이미지 ~6.8 GB + 볼륨 ~7.2 GB, 한국어 모델 ~5 GB 포함); **~4 GB+ RAM** 필요. **boot-0에 선택할 것** — 임베딩 모델이 곧 벡터 차원이라, 데이터 적재 후 프로파일을 바꾸면 전체 재색인/폐기가 강제된다.
- **경량 폴백 — `cpu-en` (`./bootstrap --cpu-en`):** 영어 `bge-small-en-v1.5` + `ms-marco-MiniLM` (~217 MB). **실측:** 런타임 ~0.85 GB RAM, 디스크 ~7 GB, **2 GB** Docker VM에서 구동; **CI 검증** 프로파일(verify-all 7/7 GREEN). CI / 제약 호스트 / 영어 코퍼스용.
- **`gpu` 프로파일 _(옵트인)_:** TEI로 한국어 모델 서빙; CUDA GPU 필요.
- **검증 환경(참고):** **`ko-full`** 라이브 검증 — Colima(Apple Silicon, 6 vCPU / 10 GiB), Hindsight `v0.8.3`, `bge-m3`(1024차원) + `bge-reranker-v2-m3`, 완전 오프라인(`LLM=none`)에서 `verify-all` **7/7 GREEN**; 한국어 의미 recall 확인(어휘가 다른 한국어 쿼리도 올바른 메모리로 매칭). **`cpu-en`**은 **2 GB** VM에서 검증(경량 CI 프로파일).

## 위협 모델

정직하지만-호기심-있는(honest-but-curious) 모델 — 동료의 **실수에 의한** 뱅크 간 접근을 막는다. 능동적/악의적 우회(예: 호스트에서 `8888`을 직접 타격)는 **v1 범위 밖** — 잔여 위험과 업그레이드 경로(mTLS / 뱅크별 키 / 레이트 리밋)는 [`docs/THREAT-MODEL.md`](docs/THREAT-MODEL.md) 참조.

## 핀 고정 & 재현성

이미지는 태그가 아니라 **다이제스트(`@sha256`)**로 고정 — Hindsight v0.x는 변화가 빠르다. 임베딩 프로파일은 boot-0에 잠긴다(임베딩 모델을 바꾸면 벡터 차원이 바뀌어 → 재색인 필요).

## v1 범위 밖 (phase 2)

자동 캡처 규칙 · 일일 리포트 · GPU 프로파일 검증 · ko-full CI 자동화 · 오프사이트 백업 · mTLS / 뱅크별 키 / 레이트 리밋.

## 구조

```
gateway/   본문 인지 · 기본 거부 MCP 정책 게이트웨이 (app/policy/acl/audit)
verify/    verify-all.sh + gate1..6 + contract-drift + lib
scripts/   bootstrap 헬퍼: contract-probe, seed-demo, backup, restore-test, secret-hygiene
profiles/  ko-full (기본, 한국어) / cpu-en (CI 검증 경량 폴백) / gpu (옵트인)
tests/     게이트웨이 단위 + adversarial + attribution (프로브 생성 모킹)
docs/      RUNBOOK · THREAT-MODEL · deploy-systemd
```

## 라이선스

MIT.
