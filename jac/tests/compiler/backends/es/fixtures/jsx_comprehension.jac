"""Test fixture for JSX comprehension syntax.

Two syntaxes are supported:
1. Double-brace {{ }} - set comprehension inside JSX expression
2. List comprehension [] - can be used directly or embedded in JSX with {[...]}
"""

# Double-brace syntax (set comprehension in JSX)
def:pub todo_list(items: list[any]) -> JsxElement {
    return <ul>{{<li key={item.id}>{item.title}</li> for item in items}}</ul>;
}

def:pub filtered_list(items: list[any]) -> JsxElement {
    return
        <ul>
            {{
                <li key={item.id}>{item.title}</li>
                for item in items
                if item.active
            }}
        </ul>;
}

def:pub nested_comprehension(rows: list[any]) -> JsxElement {
    return
        <table>
            {{
                <tr key={row.id}>
                    {{<td key={cell.id}>{cell.value}</td> for cell in row.cells}}
                </tr> for row in rows
            }}
        </table>;
}

# List comprehension syntax
def:pub todo_list_array(items: list[any]) -> JsxElement {
    return <ul>{[<li key={item.id}>{item.title}</li> for item in items]}</ul>;
}

def:pub filtered_list_array(items: list[any]) -> JsxElement {
    return
        <ul>
            {[
                <li key={item.id}>{item.title}</li>
                for item in items
                if item.active
            ]}
        </ul>;
}

def:pub standalone_list_compr(items: list[any]) -> JsxElement {
    return [<li key={item.id}>{item.title}</li> for item in items];
}

def:pub standalone_filtered_list_compr(items: list[any]) -> JsxElement {
    return [
        <li key={item.id}>{item.title}</li>
        for item in items
        if item.active
    ];
}
