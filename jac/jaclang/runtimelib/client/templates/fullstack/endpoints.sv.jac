"""{{name}} - Server-Side Data Layer.

Messages are stored as `Message` nodes on the graph and persist across
restarts. The walkers below are the API the client calls with `root spawn`.

They are `:pub`, so they need no login: `root` is the shared global graph and
every visitor reads and writes the same guestbook. Switch a walker to `:priv`
to require authentication and give each user their own isolated `root`.

The walkers report `Message` nodes directly. Typing `reports` as
`list[Message]` makes `(spawn W).reports` a typed `list[Message]` on the client,
so the UI gets `.author` / `.text` dot access instead of untyped dict keys.
"""

node Message {
    has author: str,
        text: str;
}

walker:pub PostMessage {
    """Append a new message and report the created node."""
    has author: str,
        text: str,
        reports: list[Message] = [];

    can post with Root entry {
        report here ++> Message(author=self.author, text=self.text);
    }
}

walker:pub ListMessages {
    """Report every message in the guestbook, one report per node."""
    has reports: list[Message] = [];

    can collect with Root entry {
        visit [-->];
    }

    can gather with Message entry {
        report here;
    }
}
