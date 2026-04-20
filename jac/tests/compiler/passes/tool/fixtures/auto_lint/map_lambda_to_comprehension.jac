"""Fixture for W3039 auto-fix: map(lambda -> JSX) to list comprehension."""

def:pub HourGrid(hours: list, items: list) -> JsxElement {
    hourLabels = hours.map(
        lambda hour: any, idx: int -> any {
            return <div key={idx} className="text-xs text-center">{hour}</div>;
        }
    );
    itemRows = items.map(
        lambda item: any -> any {
            return <li className="item">{item.name}</li>;
        }
    );
    return (
        <div>
            <div className="hour-grid">{hourLabels}</div>
            <ul>{itemRows}</ul>
        </div>
    );
}
