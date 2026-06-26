"""Body-aware deny-by-default MCP gateway — the single isolation enforcement point.

Clients POST JSON-RPC to /mcp/<bank>/ with their member token (Bearer). The gateway:
  1. resolves the principal from the ACL (never trusts client bank hints),
  2. decides per JSON-RPC element (batch-aware) deny-by-default — any deny → 403 whole request,
  3. only on allow: sanitizes the body (strip client bank, stamp team-retain attribution),
  4. forwards with header allowlist + injected upstream Bearer key to /mcp/<bank>/,
  5. streams the response back (SSE/streamable HTTP passthrough),
  6. audits every decision (token fingerprint, attempted vs resolved bank, allow/deny+reason).

create_app(...) takes an injectable httpx client so unit tests run with a mock upstream
(no Docker). Body mutation invariant: single canonical json.dumps re-serialization, so
Content-Length is recomputed by httpx from the new bytes.
"""
from __future__ import annotations

import json
import re
import os
from typing import List, Optional

import httpx
from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse

from .acl import ACL
from .audit import Audit
from . import policy

_BANK_RE = re.compile(r"^[A-Za-z0-9_-]{1,128}$")


def _bearer(request: Request) -> Optional[str]:
    h = request.headers.get("authorization", "")
    if h.lower().startswith("bearer "):
        return h[7:].strip() or None
    return None


def create_app(
    *,
    acl: ACL,
    audit: Optional[Audit] = None,
    upstream_base: str = "http://hindsight:8888",
    upstream_key: str = "",
    http_client: Optional[httpx.AsyncClient] = None,
    attribution_enabled: bool = True,
) -> FastAPI:
    app = FastAPI(title="hindsight-crew-gateway")
    audit = audit or Audit()
    client = http_client or httpx.AsyncClient(base_url=upstream_base, timeout=30.0)
    app.state.http_client = client

    @app.get("/healthz")
    async def healthz():
        return {"ok": True}

    # Root multi-bank surface is never exposed (enumeration). Explicit 403.
    @app.post("/mcp/")
    @app.post("/mcp")
    async def root_blocked(request: Request):
        token = _bearer(request)
        p = acl.principal_for(token)
        audit.record(token=token, identity=(p.identity if p else None), method="*",
                     tool=None, attempted_bank=None, resolved_bank=None,
                     decision="deny", reason="root-multibank-blocked")
        return JSONResponse({"error": "multi-bank endpoint disabled"}, status_code=403)

    @app.post("/mcp/{bank}/")
    @app.post("/mcp/{bank}")
    async def proxy(bank: str, request: Request):
        token = _bearer(request)
        principal = acl.principal_for(token)

        # Bank format guard (defense-in-depth vs traversal/encoding).
        if not _BANK_RE.match(bank or ""):
            audit.record(token=token, identity=(principal.identity if principal else None),
                         method="tools/call", tool=None, attempted_bank=bank,
                         resolved_bank=None, decision="deny", reason="bad-bank-format")
            return JSONResponse({"error": "forbidden"}, status_code=403)

        raw = await request.body()
        try:
            payload = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            return JSONResponse({"error": "bad json"}, status_code=400)

        batch = payload if isinstance(payload, list) else [payload]

        # --- DECIDE first (fail-closed): any denied element rejects the whole request ---
        decisions = []
        for el in batch:
            method = (el or {}).get("method", "")
            params = (el or {}).get("params") or {}
            tool = params.get("name") if method == "tools/call" else None
            d = policy.decide(principal, bank, method, tool)
            audit.record(token=token, identity=(principal.identity if principal else None),
                         method=method, tool=tool, attempted_bank=bank,
                         resolved_bank=(d.resolved_bank), decision=("allow" if d.allow else "deny"),
                         reason=d.reason)
            decisions.append(d)
            if not d.allow:
                return JSONResponse({"error": "forbidden", "reason": d.reason}, status_code=403)

        # --- MUTATE only after all allowed ---
        for el, d in zip(batch, decisions):
            if (el or {}).get("method") == "tools/call":
                params = el.get("params") or {}
                params["arguments"] = policy.sanitize_arguments(
                    params.get("arguments"),
                    resolved_bank=bank,
                    principal=principal,
                    tool=d.tool,
                    attribution_enabled=attribution_enabled,
                )
                el["params"] = params

        out_payload = batch if isinstance(payload, list) else batch[0]
        body_bytes = json.dumps(out_payload).encode("utf-8")  # canonical re-serialization

        # Header allowlist + inject upstream key (client token never forwarded).
        fwd_headers = {
            k: v for k, v in request.headers.items()
            if k.lower() in policy.FORWARD_HEADER_ALLOWLIST
        }
        fwd_headers["content-type"] = "application/json"
        if upstream_key:
            fwd_headers["authorization"] = f"Bearer {upstream_key}"

        up_req = client.build_request("POST", f"/mcp/{bank}/", content=body_bytes, headers=fwd_headers)
        # MCP tools/call returns a single (possibly SSE-framed) response then closes, so we
        # read it fully and pass the bytes + content-type through. SSE framing (data: lines)
        # is preserved verbatim for the client to parse; incremental push-streaming is a
        # phase-2 refinement (not an MCP tools/call pattern here).
        up_resp = await client.send(up_req)
        media = up_resp.headers.get("content-type", "application/json")
        return Response(content=up_resp.content, status_code=up_resp.status_code, media_type=media)

    return app
