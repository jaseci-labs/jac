"""Fixture for JSX goto-definition tests."""

def MyButton(label: str, disabled: bool = False) -> JsxElement {
    return <button disabled={disabled}>
        {label}
    </button>;
}

def App() -> JsxElement {
    return <div>
        <MyButton label="Click me" />
    </div>;
}
