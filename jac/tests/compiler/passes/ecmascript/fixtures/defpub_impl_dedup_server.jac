"""Server module with def:pub functions for testing import deduplication."""

node Item {
    has id: str,
        name: str;
}

def:pub create_item(name: str) -> dict {
    item = root ++> Item(id="1", name=name);
    return {"id": item[0].id, "name": item[0].name};
}

def:pub list_items -> list {
    return [{"id": i.id, "name": i.name} for i in [root-->](?:Item)];
}
