"""{{name}} - a headless Jac API service.

`Note` nodes persist on the graph. `add_note` is a `def:pub` function endpoint
(POST /function/add_note) and `ListNotes` is a `walker:pub` endpoint
(POST /walker/ListNotes) - a walker because it traverses. Both are `:pub`:
no login, every caller shares the guest graph; switch to `:priv` to require a
token and give each user an isolated root. In a workspace, other apps import
these names and the compiler turns the import into a bridge to this service.
"""

node Note {
    has text: str;
}

def:pub add_note(text: str) -> Note {
    return root ++> Note(text=text);
}

walker:pub ListNotes {
    """Report every note on the graph, one report per node."""
    has reports: list[Note] = [];

    can collect with Root entry {
        visit [-->[?:Note]];
    }

    can gather with Note entry {
        report here;
    }
}
