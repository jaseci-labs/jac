"""Minimal `sv` backend fixture for the in-process dispatch round-trip test.

This is the `sv` half of a Jac-native desktop app: one walker (carrying a field,
to exercise the `fields` part of the request contract) and one `sv` function.
The `cl` half -- the client runtime routing a call through `window.__jac_invoke`
instead of `fetch` -- is covered by `jac/tests/runtimelib/test_native_invoke.cl.jac`.
Together the two tests exercise the full `cl` -> `sv` in-process path (#6596)
without needing a live webview, a display, or `nacompile`.
"""

walker:pub greet {
    has name: str = "world";

    can run with Root entry {
        report {"greeting": f"hello {self.name}"};
    }
}

def:pub add(a: int, b: int) -> int {
    return a + b;
}


# `root.shared` round-trip (#6685): a note written to the shared root by one
# request must be readable by a later one, proving the shared-root resolver the
# no-serve seam installs works on the desktop in-process path. Mirrors
# jac/tests/runtimelib/fixtures/serve_shared_root.jac.
node Note {
    has text: str = "";
}

edge HasNote {}

walker:pub leave_note {
    has text: str = "";

    can run with Root entry {
        fresh = root.shared +>: HasNote() :+> Note(text=self.text);
        if fresh {
            # The note is owned by its author; open it to all readers.
            grant(fresh, level=ReadPerm);
        }
        report {"saved": self.text};
    }
}

walker:pub read_notes {
    can run with Root entry {
        report {"notes": sorted([n.text for n in [root.shared-->[?:Note]]])};
    }
}
