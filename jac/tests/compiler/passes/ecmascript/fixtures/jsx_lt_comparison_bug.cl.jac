"""Exposes BUG: Lexer treats `<` comparison operator as JSX opening tag.

When the lexer sees `i<points` in a for-loop, it enters JSX_TAG mode
because `<` followed by an alpha char is always treated as a JSX opening
tag.  This corrupts the mode state machine and causes an infinite loop.
"""

cl {
    def filter_points(points: list, limit: int) -> list {
        result = [];
        for i=0 to i<points.length by i+=1 {
            if points[i] < limit {
                result.append(points[i]);
            }
        }
        return result;
    }

    def:pub app() -> any {
        data = [10, 5, 30, 2, 20];
        filtered = filter_points(data, 15);
        items = filtered.map(
            lambda x: any -> any { return <li>{x}</li>; }
        );

        return (
            <div>
                <h1>Results</h1>
                <ul>{items}</ul>
            </div>
        );
    }
}
