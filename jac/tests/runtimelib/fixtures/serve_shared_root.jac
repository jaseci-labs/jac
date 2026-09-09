"""Fixture exercising the shared root surfaced as `root.shared`.

The shared root is the root every unauthenticated request runs on, and the
runtime floors its access at AccessLevel.CONNECT: any user can read the public
graph and attach to it with no app-side arming. Nodes a user hangs there
stay owned by that user - the author opens them (AccessLevel.READ) for everyone.
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
        fresh = root.shared +>:HasNote():+> Note(text=self.text);
        if fresh {
            # The note is owned by its author; open it to all readers.
            grant(fresh, level=AccessLevel.READ);
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
        grant(root.shared, level=AccessLevel.READ);
        report "locked";
    }
}

# Commons state deletable by anyone: the archetype opens WRITE to all, so
# any identity can clear stale generations regardless of who created them.
node Bin {
    has tag: str = "";

    def __jac_access__ -> any {
        return AccessLevel.WRITE;
    }
}

edge HasBin {}

walker:pub leave_bin {
    has tag: str = "";

    can run with Root entry {
        fresh = root.shared +>:HasBin():+> Bin(tag=self.tag);
        report 1 if fresh is not None else 0;
    }
}

walker:pub read_bins {
    can run with Root entry {
        report sorted([b.tag for b in [root.shared-->[?:Bin]]]);
        report len(root.shared.__jac__.edges);
    }
}

# Reports the shared root's edge count from the same request that deleted,
# before any traversal can quarantine a dangling ref - the direct witness
# that a node delete takes cross-owner incident edges with it.
walker:pub clear_bins {
    can run with Root entry {
        bins = [root.shared-->[?:Bin]];
        for b in bins {
            del b;
        }
        report len(bins);
        report len(root.shared.__jac__.edges);
    }
}

walker:pub clear_notes {
    can run with Root entry {
        notes = [root.shared-->[?:Note]];
        for n in notes {
            del n;
        }
        report len(notes);
    }
}

# The commons' stored deployment-wide level: the CONNECT floor is policy in
# the access check, so a reader's touch must leave this untouched.
walker:pub shared_level {
    can run with Root entry {
        acc = root.shared.__jac__.access;
        report acc.all.name if acc is not None else "NONE";
    }
}

# Walk back from a commons note to the root it hangs on through a typed hop,
# the shape the store-side ACL pushdown filters in SQL.
walker:pub note_home {
    has text: str = "";

    can run with Root entry {
        notes = [
            n
            for n in [root.shared-->[?:Note]]
            if n.text == self.text
        ];
        homes = [notes[0]<-:HasNote:<-[?:Root]] if notes else [];
        report [jid(h) for h in homes];
    }
}
