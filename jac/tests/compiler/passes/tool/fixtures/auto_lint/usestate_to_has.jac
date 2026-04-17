"""Fixture for W3038 auto-fix: useState hook to has declaration (Multiple useState hooks)."""

import from "react" { useState }

def:pub Counter() -> JsxElement {
    [count, setCount] = useState(0);
    [label, setLabel] = useState("hello");

    def handleClick(e: any) {
        setCount(count + 1);
        setLabel("clicked");
    }

    return (
        <div>
            <p>{label}: {count}</p>
            <button onClick={handleClick}>Click</button>
        </div>
    );
}
