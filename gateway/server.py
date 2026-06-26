"""Gateway entrypoint — wires create_app() from environment and serves it.

Env:
  HC_ACL_FILE            path to ACL json (default /secrets/acl.json)
  HC_HINDSIGHT_API_KEY   upstream Hindsight shared Bearer key (held ONLY here)
  HC_UPSTREAM_BASE       upstream Hindsight base (default http://hindsight:8888)
  HC_AUDIT_LOG           audit log path (default /audit/gateway.log)
  HC_ATTRIBUTION_MODE    "body-inject" (default) | "audit-only"  (set from contract-probe)
  HC_GATEWAY_PORT        listen port (default 8888)
"""
from __future__ import annotations

import os

import uvicorn

from .acl import ACL
from .audit import Audit
from .app import create_app


def build():
    acl = ACL.load(os.environ.get("HC_ACL_FILE", "/secrets/acl.json"))
    audit = Audit(os.environ.get("HC_AUDIT_LOG", "/audit/gateway.log"))
    mode = os.environ.get("HC_ATTRIBUTION_MODE", "body-inject")
    return create_app(
        acl=acl,
        audit=audit,
        upstream_base=os.environ.get("HC_UPSTREAM_BASE", "http://hindsight:8888"),
        upstream_key=os.environ.get("HC_HINDSIGHT_API_KEY", ""),
        attribution_enabled=(mode != "audit-only"),
    )


app = build()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("HC_GATEWAY_PORT", "8888")))
