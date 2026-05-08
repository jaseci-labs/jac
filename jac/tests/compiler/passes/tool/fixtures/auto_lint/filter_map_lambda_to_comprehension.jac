"""Fixture for W3042 auto-fix: filter-map lambda chain to filtered list comprehension."""

def:pub ActiveItems(items: list) -> JsxElement {
    activeRows = items.filter(
        lambda item: any -> bool {
            return item.active;
        }
    ).map(
        lambda item: any -> any {
            return <li className="active">{item.name}</li>;
        }
    );
    return <ul>{activeRows}</ul>;
}
