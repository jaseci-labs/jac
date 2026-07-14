"""Fixture exercising the shared root surfaced as `root.shared`.

The shared root is the root every unauthenticated request runs on, and the
runtime floors its access at ConnectPerm: any user can read the public
graph and attach to it with no app-side arming. Nodes a user hangs there
stay owned by that user - the author opens them (ReadPerm) for everyone.
"""

node Note {
    has text: str = "";
}

edge HasNote {}

walker:pub whereami {
    can run with Root entry {
        report jid(here);
        report jid(root.shared);
    }
}

walker:pub leave_note {
    has text: str = "";

    can run with Root entry {
        # Connect denial no-ops with an empty result (plus a diagnostic) -
        # guard so a denied write reports cleanly instead of crashing.
        fresh = root.shared +>: HasNote() :+> Note(text=self.text);
        if fresh {
            # The note is owned by its author; open it to all readers.
            grant(fresh, level=ReadPerm);
        }
        report jid(root.shared);
    }
}

walker:pub read_notes {
    can run with Root entry {
        report sorted([n.text for n in [root.shared-->[?:Note]]]);
        report jid(root.shared);
    }
}

# Lock the commons down to read-only. Run anonymously: the caller IS the
# shared root's owner, so the lowered level persists - and because it is
# an explicit non-NO_ACCESS level, the runtime's CONNECT floor respects it.
walker:pub make_readonly {
    can run with Root entry {
        grant(root.shared, level=ReadPerm);
        report "locked";
    }
}
