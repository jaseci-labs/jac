"""Fixture for W3041 auto-fix: map(lambda -> JSX) to list comprehension."""

def:pub HourGrid(hours: list, items: list) -> JsxElement {
    hourLabels = hours.map(
        lambda hour: any -> any {
            return <div className="text-xs text-center">{hour}</div>;
        }
    );

    return (
        <div>
            <div className="hour-grid">{hourLabels}</div>
            <ul>{itemRows}</ul>
        </div>
    );
}
