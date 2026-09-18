glob global_title: str = "module";

obj InlineWidget {
    has inline_title: str = "field";

    def size -> int {
        # A field is not an implicit lexical binding inside a method.
        return len(inline_title.strip());
    }
}

obj AnnexWidget {
    has annex_title: str = "field";

    def size -> int;
}

impl AnnexWidget.size -> int {
    # Annex methods must follow the same name-resolution rule.
    return len(annex_title.strip());
}

obj GlobalControl {
    has global_title: str = "field";

    def read_global -> str {
        # Runtime lexical lookup skips the field and finds the module global.
        return global_title.strip();
    }
}

obj RebindControl {
    has rebound_title: str = "field";

    def size -> int {
        # An assignment records this field as a valid implicit rebind.
        rebound_title = "local";
        return len(rebound_title.strip());
    }
}

obj NestedRebindControl {
    has nested_title: str = "field";

    def size -> int;
}

impl NestedRebindControl.size -> int {
    # A nested assignment still creates a function scope local.
    if True {
        nested_title = "local";
        return len(nested_title.strip());
    }
    return 0;
}

node NodeWidget {
    has node_title: str = "field";

    def size -> int {
        # Graph archetypes follow the same explicit-receiver rule.
        return len(node_title.strip());
    }
}
