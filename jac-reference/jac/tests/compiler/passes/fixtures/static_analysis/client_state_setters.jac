"""A component's state fields bind setters the user never names."""

def:pub Counter(label: str) -> JsxElement {
    has count: int = 0,
        title: str = "";

    stale = 1;

    <button onClick={lambda { count = count + 1; }}>{label}{count}{title}</button>
}
