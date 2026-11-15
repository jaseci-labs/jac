"""`jacSignup` and the registration proof-of-work challenge.

With `[serve.auth.registration] challenge = true` the server refuses any
`POST /user/register` that lacks a solved challenge, and `jacSignup` once never
fetched one, so every app with challenges on had to hand-roll registration.

These compile the real web runtime core and its `auth_contract` to JS and run
them under a JS runtime against a scripted `fetch`. The challenge is minted here
with Python's `hashlib`, exactly as `registration_challenge.issue_challenge`
does, so a client SHA-256 that drifts from the server's fails the solve. The
native (React Native) core shares the same solver; its wiring is pinned in
`test_client_runtime_parity.jac`.
"""

import hashlib;
import json;
import shutil;
import subprocess;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.client.runtime_source { resolve_client_runtime_cl_path }
import from tests.support { js_runtime_or_none }
import from .react_jsdom_harness { compile_react, write_runtime_support }

glob _SALT: str = "5f1c0ffee5a1t",
     _HARNESS: str = """
import { readFileSync } from "node:fs";

const config = JSON.parse(readFileSync(process.argv[2], "utf8"));
const core = await import("./client_runtime_core.js");
const contract = await import("./auth_contract.js");

const out = { hashes: config.hash_inputs.map((s) => contract.__sha256Hex(s)), runs: [] };
for (const scenario of config.scenarios) {
  delete globalThis.__jacAuthPolicy__;
  const calls = [];
  let registered = null;
  globalThis.fetch = async (url, init = {}) => {
    const path = String(url);
    calls.push(path);
    const reply = (body, status = 200) => new Response(JSON.stringify(body), { status });
    if (path === "/user/auth-policy") {
      return reply({ ok: true, data: scenario.policy });
    }
    if (path === "/user/register/challenge") {
      return reply(scenario.challenge_reply, scenario.challenge_status || 200);
    }
    if (path === "/user/register") {
      registered = JSON.parse(init.body);
      return reply({ ok: true, data: { user_id: "user-1" } }, 201);
    }
    return reply({ ok: false, error: { message: "unexpected " + path } }, 404);
  };
  const result = await core.jacSignup("alice", "correct horse battery");
  out.runs.push({
    name: scenario.name,
    result: { success: result.success, error: result.error, user_id: result.user_id },
    calls,
    registered,
  });
}
console.log(JSON.stringify(out));
""";

"""A challenge as the server issues it: `target = sha256(salt + str(number))`."""
def _challenge(number: int, max_number: int, expires_in: int = 300) -> dict[str, any] {
    target = hashlib.sha256((_SALT + str(number)).encode()).hexdigest();
    return {
        "ok": True,
        "data": {
            "required": True,
            "challenge": {
                "token": "challenge-token",
                "salt": _SALT,
                "target": target,
                "max_number": max_number,
                "expires_in": expires_in
            }
        }
    };
}

def _policy(challenge: bool) -> dict[str, any] {
    return {
        "identifiers": {"username": "required", "email": "off"},
        "registration": {"enabled": True, "challenge": challenge}
    };
}

"""Compile the web core into `work`, run the harness over `config`, and return
its JSON report."""
def _run(config: dict[str, any]) -> dict[str, any] {
    js = js_runtime_or_none();
    if js is None {
        testskip("a JS runtime is required but could not be located");
    }
    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        runtime_path = resolve_client_runtime_cl_path("react");
        write_runtime_support(work, runtime_path);
        (work / "client_runtime_core.js").write_text(
            compile_react(str(Path(runtime_path).parent / "client_runtime_core.jac")),
            encoding="utf-8"
        );
        (work / "harness.mjs").write_text(_HARNESS, encoding="utf-8");
        (work / "config.json").write_text(json.dumps(config), encoding="utf-8");
        node_bin = shutil.which("node");
        cmd = [node_bin or js]
            + ([] if node_bin else ["run"])
            + [str(work / "harness.mjs"), str(work / "config.json")];
        run = subprocess.run(
            cmd, cwd=str(work), capture_output=True, text=True, timeout=120
        );
        assert run.returncode == 0 , (
            f"harness failed (exit {run.returncode}):\n{run.stdout}\n{run.stderr}"
        );
        return json.loads(run.stdout.strip().splitlines()[-1]);
    }
}

def _by_name(outcome: dict[str, any]) -> dict[str, any] {
    return {run["name"]: run for run in outcome["runs"]};
}

test "jacSignup solves the registration challenge only when the policy requires one" {
    # 2345 sits past two event-loop yields, so the search really iterates.
    outcome = _run(
        {
            "hash_inputs": [],
            "scenarios": [
                {
                    "name": "required",
                    "policy": _policy(True),
                    "challenge_reply": _challenge(2345, 3000)
                },
                {
                    "name": "off",
                    "policy": _policy(False),
                    "challenge_reply": _challenge(1, 10)
                }
            ]
        }
    );
    runs = _by_name(outcome);

    required = runs["required"];
    assert required["result"]["success"] , required;
    assert required["result"]["user_id"] == "user-1" , required;
    assert required["calls"]
        == ["/user/auth-policy", "/user/register/challenge", "/user/register"] , required[
        "calls"
    ];
    assert required["registered"]["challenge"]
        == {"token": "challenge-token", "number": 2345} , required["registered"];
    assert required["registered"]["identities"]
        == [{"type": "username", "value": "alice"}];

    off = runs["off"];
    assert off["result"]["success"] , off;
    assert "/user/register/challenge" not in off["calls"] , off["calls"];
    assert "challenge" not in off["registered"] , off["registered"];
}

test "jacSignup reports an unsolvable or expired challenge without registering" {
    unsolvable = _challenge(5000, 3000);
    expired = _challenge(2500, 3000, expires_in=0);
    outcome = _run(
        {
            "hash_inputs": [],
            "scenarios": [
                {
                    "name": "unsolvable",
                    "policy": _policy(True),
                    "challenge_reply": unsolvable
                },
                {
                    "name": "expired",
                    "policy": _policy(True),
                    "challenge_reply": expired
                },
                {
                    "name": "refused",
                    "policy": _policy(True),
                    "challenge_reply": {
                        "ok": False,
                        "error": {"message": "Too many registration attempts."}
                    },
                    "challenge_status": 429
                }
            ]
        }
    );
    runs = _by_name(outcome);
    expectations = {
        "unsolvable": "Verification failed. Please try again.",
        "expired": "Verification expired. Please try again.",
        "refused": "Too many registration attempts."
    };
    for (name, message) in expectations.items() {
        run = runs[name];
        assert not run["result"]["success"] , run;
        assert run["result"]["error"] == message , run;
        assert "/user/register" not in run["calls"] , run["calls"];
    }
}

test "the client runtime's sha256 matches hashlib" {
    inputs = [
        "",
        "abc",
        "a" * 55,
        "a" * 56,
        "a" * 64,
        "a" * 1000,
        _SALT + "2345",
        "héllo wörld ✓ \U0001d11e"
    ];
    outcome = _run({"hash_inputs": inputs, "scenarios": []});
    expected = [hashlib.sha256(text.encode()).hexdigest() for text in inputs];
    assert outcome["hashes"] == expected , list(
        zip(inputs, outcome["hashes"], expected)
    );
}
