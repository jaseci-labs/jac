"""Minimal full-stack backend for cl test-runner integration tests.

Two authenticated walkers over a tiny note graph -- just enough surface to
exercise the cl->sv fetch bridge (signup -> login -> walker spawn) against a
real jac-scale server booted by the cl test runner.
"""

node Note {
    has text: str = "";
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
