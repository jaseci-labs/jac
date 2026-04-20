"""Component impl scope resolution: has variables from the parent component
function should be visible in impl method bodies without becoming Unknown.

Verifies that impl app.update can see has items: list[dict] declared in app.
"""

def app -> str {
    has items: list[dict] = [],
        label: str = "";

    def update -> None;
    def getLabel -> str;

    return "";
}

impl app.update -> None {
    items = items + [{"key": "value"}];
    label = "updated";
}

impl app.getLabel -> str {
    return label;
}
