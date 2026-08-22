"""Minimal full-stack backend for cl test-runner integration tests.

Two authenticated walkers over a tiny note graph -- just enough surface to
exercise the cl->sv fetch bridge (signup -> login -> walker spawn) against a
real jac-scale server booted by the cl test runner.

`whoami` is an auth-required FUNCTION endpoint (served at /function/whoami),
used to exercise the function-call fetch path (`__doFuncFetch`) and its 401
self-heal.
"""

node Note {
    has text: str = "";
}

def whoami -> dict[str, str] {
    return {"who": "authenticated"};
}

walker save_note {
    has text: str = "";

    can run with Root entry {
        here ++> Note(text=self.text);
        report {"text": self.text};
    }
}

walker list_notes {
    can run with Root entry {
        for n in [-->[?:Note]] {
            report {"text": n.text};
        }
    }
}
