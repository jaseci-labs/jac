"""Server provider: a def:pub function reader and a walker writer.

Paired with sv_walker_effects_client.cl.jac to check that an sv-imported walker
reaches the client endpoint-effects manifest as a writer (#7650).
"""

node Item {
    has text: str;
}

def:pub list_items -> list[Item] {
    return [it for it in [root-->[?:Item]]];
}

walker:pub AddItem {
    has text: str,
        reports: list[Item] = [];

    can add with Root entry {
        report here ++> Item(text=self.text);
    }
}
