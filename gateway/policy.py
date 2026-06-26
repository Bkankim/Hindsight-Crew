"""Authorization policy + body sanitization (pure, unit-testable).

The gateway is body-aware deny-by-default. Bank is resolved ONLY from the
client-requested path bank checked against the ACL; the request body's
`arguments.bank` is never trusted — it is stripped/overwritten. Team-retain
attribution is overwritten with the caller's identity (no forgery).

Order contract (enforced by app.py): decide() FIRST; only on allow do we mutate.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Tuple

from .acl import Principal

# Tools that mutate/destroy — allowed ONLY on the caller's personal bank (never team).
DESTRUCTIVE_TOOLS = frozenset({
    "delete_bank", "clear_memories", "delete_document", "update_bank",
})
# Retain-family tools carry content; on a team bank we inject member attribution.
RETAIN_TOOLS = frozenset({"retain", "sync_retain"})
# Read/recall family — allowed on any bank the principal may access.
READ_TOOLS = frozenset({"recall", "reflect", "list_memories", "get_memory"})

# Field in tools/call arguments that names a bank (client-controlled → must sanitize).
BANK_ARG_KEYS = ("bank", "bank_id", "bankId")
# Where we stamp the authenticated member identity for team-retain attribution.
ATTRIBUTION_KEY = "hc_member"


@dataclass(frozen=True)
class Decision:
    allow: bool
    reason: str
    resolved_bank: Optional[str] = None
    tool: Optional[str] = None


def decide(
    principal: Optional[Principal],
    requested_bank: Optional[str],
    method: str,
    tool: Optional[str],
) -> Decision:
    """Deny-by-default authorization. requested_bank is the URL-path bank."""
    if principal is None:
        return Decision(False, "unknown-or-missing-token", None, tool)
    # Root multi-bank surface (no bank in path) → enumeration risk, always deny.
    if not requested_bank:
        return Decision(False, "root-multibank-blocked", None, tool)
    if requested_bank not in principal.allowed_banks():
        return Decision(False, f"bank-not-in-acl:{requested_bank}", None, tool)

    if method == "tools/list":
        return Decision(True, "list", requested_bank, tool)
    if method != "tools/call":
        return Decision(False, f"method-not-allowed:{method}", requested_bank, tool)
    if not tool:
        return Decision(False, "missing-tool-name", requested_bank, tool)

    if tool in DESTRUCTIVE_TOOLS:
        # Destructive only on the caller's own personal bank.
        if requested_bank != principal.personal:
            return Decision(False, f"destructive-on-nonpersonal:{tool}", requested_bank, tool)
        return Decision(True, f"destructive-own:{tool}", requested_bank, tool)

    if tool in RETAIN_TOOLS or tool in READ_TOOLS:
        return Decision(True, f"allow:{tool}", requested_bank, tool)

    # Unknown tool → deny-by-default (fail-closed; new tools are not auto-trusted).
    return Decision(False, f"tool-not-whitelisted:{tool}", requested_bank, tool)


def sanitize_arguments(
    arguments: Optional[dict],
    *,
    resolved_bank: str,
    principal: Principal,
    tool: Optional[str],
    attribution_enabled: bool,
) -> dict:
    """Strip client bank hints; stamp team-retain attribution. Returns a NEW dict."""
    args = dict(arguments or {})
    # 1) Remove any client-supplied bank field (gateway pins bank via URL path).
    for k in BANK_ARG_KEYS:
        args.pop(k, None)
    # 2) Team-retain attribution: overwrite (never trust) member identity.
    if attribution_enabled and tool in RETAIN_TOOLS and principal.is_team_bank(resolved_bank):
        md = dict(args.get("metadata") or {})
        md[ATTRIBUTION_KEY] = principal.identity  # overwrite any client-provided value
        args["metadata"] = md
    return args


# Header allowlist: only these are forwarded upstream; everything else is dropped.
# Authorization is injected by the gateway (upstream key), never forwarded from client.
FORWARD_HEADER_ALLOWLIST = frozenset({"content-type", "accept"})
