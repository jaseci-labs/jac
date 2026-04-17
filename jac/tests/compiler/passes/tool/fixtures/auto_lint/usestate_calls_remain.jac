"""Fixture for W3038: useState call inside JSX (not a destructure assignment) — should NOT be converted, import must stay."""

import from "react" { useState }

def:pub RawUseState -> JsxElement {
    result = useState("kept");

    return (<div>{result}</div>);
}
