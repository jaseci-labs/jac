"""Shared UI under no app root, reached by the `portal` client app; spawns the feed walker."""

import from .feed_app { Feed, Item }

def:pub Panel -> JsxElement {
    has items: list[Item] = [];

    can with entry {
        got = root spawn Feed(text="hi");
        items = got.reports;
    }

    return <div>{len(items)}</div>;
}
