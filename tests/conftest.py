"""Test harness: gateway with a MOCK Hindsight upstream (no Docker).

The mock records every forwarded request (path, headers, body) so tests can assert
path-pinning, header allowlist, upstream-key injection, body sanitization, and
attribution overwrite. This stands in for contract-probe-generated fixtures in unit tests.
"""
import json
import os
import sys

import httpx
import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))  # repo root on path

from gateway.acl import ACL
from gateway.audit import Audit
from gateway.app import create_app

UPSTREAM_KEY = "UPSTREAM-SECRET-do-not-leak"

ACL_DATA = {
    "tokens": {
        "tok-alice": {"identity": "alice", "personal": "personal-alice", "teams": ["team-eng"]},
        "tok-bob": {"identity": "bob", "personal": "personal-bob", "teams": ["team-eng"]},
    }
}


class Recorder:
    def __init__(self):
        self.calls = []

    def handler(self, request: httpx.Request) -> httpx.Response:
        body = request.content.decode("utf-8") if request.content else ""
        try:
            parsed = json.loads(body) if body else None
        except json.JSONDecodeError:
            parsed = None
        self.calls.append({
            "path": request.url.path,
            "headers": {k.lower(): v for k, v in request.headers.items()},
            "body": parsed,
        })
        return httpx.Response(
            200,
            content=b'{"jsonrpc":"2.0","id":1,"result":{"ok":true}}',
            headers={"content-type": "application/json"},
        )

    @property
    def last(self):
        return self.calls[-1] if self.calls else None


@pytest.fixture
def recorder():
    return Recorder()


@pytest.fixture
def make_app(recorder, tmp_path):
    def _make(attribution_enabled=True):
        client = httpx.AsyncClient(
            transport=httpx.MockTransport(recorder.handler),
            base_url="http://upstream",
            timeout=5.0,
        )
        audit = Audit(path=str(tmp_path / "audit.log"))
        app = create_app(
            acl=ACL.from_dict(ACL_DATA),
            audit=audit,
            upstream_key=UPSTREAM_KEY,
            http_client=client,
            attribution_enabled=attribution_enabled,
        )
        app.state._audit_path = str(tmp_path / "audit.log")
        return app
    return _make


@pytest.fixture
def client(make_app):
    return TestClient(make_app())


def call(client, bank, token, method="tools/call", name="recall", arguments=None, headers=None, raw=None):
    body = raw if raw is not None else {
        "jsonrpc": "2.0", "id": 1, "method": method,
        "params": ({"name": name, "arguments": arguments or {}} if method == "tools/call" else {}),
    }
    h = {"content-type": "application/json"}
    if token:
        h["authorization"] = f"Bearer {token}"
    if headers:
        h.update(headers)
    return client.post(f"/mcp/{bank}/", content=json.dumps(body), headers=h)
