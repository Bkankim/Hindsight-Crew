# Threat Model — Hindsight-Crew

## Posture: honest-but-curious

The gateway stops a colleague from **accidentally or curiously** reading another tenant's bank. It is **not** hardened against a determined malicious actor with host access. This is a deliberate, documented v1 scope — stated honestly because a security reviewer distinguishes "RBAC" from "verifiable isolation."

## What is enforced (the single enforcement point)

Hindsight's built-in auth is a **single shared Bearer key** and resolves the target bank from client-controlled inputs (URL path > `X-Bank-Id` header > env, and — per `contract-probe` — possibly the body `arguments.bank`). It has **no identity→bank enforcement**. Therefore the gateway is the *only* place isolation is enforced. It:

1. Holds the upstream Hindsight key; **clients never receive it**.
2. Resolves the bank **only** from the token→ACL mapping; ignores/strips/overwrites client URL bank, `X-Bank-Id`, and body `arguments.bank`.
3. Denies by default: a call passes only if `(method, tool_name, target_bank)` matches the token's ACL; everything else is `403`.
4. Blocks the root multi-bank `/mcp/` (enumeration) and whitelists destructive tools to the owner's bank only.
5. Overwrites the team-retain attribution field with the token's identity (members cannot forge attribution).

## Residual risks (accepted in v1)

- **Host-local `8888` bypass.** "Single enforcement point" holds **only at the network-exposure boundary.** Hindsight runs on the internal Docker network and is not host-published; but any process/user on the host that can reach the internal network or the upstream key bypasses the gateway. Accepted under honest-but-curious.
- **No transport encryption between client and gateway** beyond the deployment's own network controls.
- **Audit log is append-only at the application layer**, not tamper-proof storage.

## Upgrade path → malicious-resistant (phase 2)

- mTLS or per-bank upstream keys (removes the single-shared-key blast radius).
- Rate-limiting + anomaly alerts on the gateway.
- Network policy so only the gateway can reach Hindsight, plus host-level isolation of the upstream key.
- Tamper-evident audit sink (append-only external store).
