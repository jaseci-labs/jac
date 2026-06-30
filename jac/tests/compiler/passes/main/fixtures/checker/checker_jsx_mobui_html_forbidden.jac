"""Fixture: mobUI projects forbid raw HTML host tags in JSX (E1105).

Lowercase intrinsic tags (``<div>``, ``<span>``, ``<button>``, ``<img>``)
must each raise E1105 when compiled as a mobUI project. The uppercase
component ``<Card>`` is a user component and must NOT be flagged."""

def Card(title: str) -> JsxElement {
    return <span>{title}</span>;
}

def App -> JsxElement {
    return
        <div>
            <Card title="hi"/>
            <button>Add</button>
            <img src="x.png"/>
        </div>;
}

# Lowercase component defined in the same module — must NOT trigger E1105.
# The guard resolves `myCard` via scope and sees it as a user component.
def myCard(title: str) -> JsxElement {
    return <></>;
}

def App2 -> JsxElement {
    return <myCard title="hello"/>;
}
