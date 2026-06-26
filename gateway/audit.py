"""Append-only audit log for the gateway.

Records token FINGERPRINT (never the raw token — public-repo secret hygiene),
attempted vs resolved bank, action, allow/deny + reason, and timestamp. A single
process-wide lock serializes writes so concurrent requests cannot interleave lines.
"""
from __future__ import annotations

import hashlib
import json
import os
import threading
import time
from typing import Optional

_LOCK = threading.Lock()


def fingerprint(token: Optional[str]) -> str:
    if not token:
        return "anon"
    return "sha256:" + hashlib.sha256(token.encode("utf-8")).hexdigest()[:16]


class Audit:
    def __init__(self, path: Optional[str] = None):
        self.path = path or os.environ.get("HC_AUDIT_LOG", "audit/gateway.log")
        os.makedirs(os.path.dirname(self.path) or ".", exist_ok=True)

    def record(
        self,
        *,
        token: Optional[str],
        identity: Optional[str],
        method: str,
        tool: Optional[str],
        attempted_bank: Optional[str],
        resolved_bank: Optional[str],
        decision: str,           # "allow" | "deny"
        reason: str,
    ) -> dict:
        entry = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "token_fp": fingerprint(token),
            "identity": identity,
            "method": method,
            "tool": tool,
            "attempted_bank": attempted_bank,
            "resolved_bank": resolved_bank,
            "decision": decision,
            "reason": reason,
        }
        line = json.dumps(entry, ensure_ascii=False, sort_keys=True)
        with _LOCK:
            with open(self.path, "a", encoding="utf-8") as fh:
                fh.write(line + "\n")
        return entry
