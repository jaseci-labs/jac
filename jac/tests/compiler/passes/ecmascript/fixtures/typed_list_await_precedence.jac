"""Fixture: typed list return via sv import must await before .map().

Regression test for the await precedence bug where:
    await __jacCallFunction("get_items",{}).map(x => Item.__from_wire(x))
is generated instead of:
    (await __jacCallFunction("get_items",{})).map(x => Item.__from_wire(x))

The missing parentheses cause .map() to be called on the Promise
(not the resolved array), breaking typed list returns.
"""

obj Item {
    has name: str,
        done: bool = False;
}

def:pub get_items -> list[Item] {
    return [];
}

def:pub add_item(name: str) -> Item {
    return Item(name=name);
}

cl {
    sv import from .typed_list_await_precedence { get_items, add_item }

    def:pub app -> JsxElement {
        has items: list = [];

        async can with entry {
            items = await get_items();
        }

        async def addItem -> None {
            item = await add_item("test");
            items = items + [item];
        }

        return <div>{[<span key={i.name}>{i.name}</span> for i in items]}</div>;
    }
}
