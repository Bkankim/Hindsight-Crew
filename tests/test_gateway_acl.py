"""Gate ⑤ (positive ACL) + core forwarding contract — unit, mock upstream."""
import json

from conftest import call, UPSTREAM_KEY


def test_allowed_recall_forwards_pinned_path_and_injects_key(client, recorder):
    r = call(client, "personal-alice", "tok-alice", name="recall", arguments={"query": "x"})
    assert r.status_code == 200
    fwd = recorder.last
    assert fwd["path"] == "/mcp/personal-alice/"                  # path-pinned
    assert fwd["headers"]["authorization"] == f"Bearer {UPSTREAM_KEY}"  # upstream key injected
    # client token must NOT appear anywhere in forwarded headers
    assert "tok-alice" not in json.dumps(fwd["headers"])


def test_team_recall_allowed(client, recorder):
    r = call(client, "team-eng", "tok-alice", name="recall", arguments={"query": "x"})
    assert r.status_code == 200
    assert recorder.last["path"] == "/mcp/team-eng/"


def test_batch_all_allowed_forwards_list(client, recorder):
    batch = [
        {"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "recall", "arguments": {"query": "a"}}},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "list_memories", "arguments": {}}},
    ]
    r = call(client, "personal-alice", "tok-alice", raw=batch)
    assert r.status_code == 200
    assert isinstance(recorder.last["body"], list) and len(recorder.last["body"]) == 2


def test_root_multibank_blocked(client, recorder):
    r = client.post("/mcp/", content="{}", headers={"authorization": "Bearer tok-alice", "content-type": "application/json"})
    assert r.status_code == 403
    assert recorder.last is None  # never forwarded


def test_destructive_on_own_personal_allowed(client, recorder):
    r = call(client, "personal-alice", "tok-alice", name="delete_bank", arguments={})
    assert r.status_code == 200
    assert recorder.last["path"] == "/mcp/personal-alice/"


def test_destructive_on_team_denied(client, recorder):
    r = call(client, "team-eng", "tok-alice", name="delete_bank", arguments={})
    assert r.status_code == 403
    assert recorder.last is None


def test_unknown_tool_denied(client, recorder):
    r = call(client, "personal-alice", "tok-alice", name="exfiltrate_everything", arguments={})
    assert r.status_code == 403
    assert recorder.last is None


def test_xbankid_header_not_forwarded(client, recorder):
    r = call(client, "personal-alice", "tok-alice", name="recall", arguments={"query": "x"},
             headers={"x-bank-id": "team-eng"})
    assert r.status_code == 200
    assert "x-bank-id" not in recorder.last["headers"]   # stripped by allowlist
    assert recorder.last["path"] == "/mcp/personal-alice/"  # path bank wins, header ignored
