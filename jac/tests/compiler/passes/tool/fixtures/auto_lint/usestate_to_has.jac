"""Fixture for W3038 auto-fix: useState hook to has declaration."""

import from "react" { useState }

def:pub NameInput() -> JsxElement {
    [name, setName] = useState("");

    def handleChange(e: any) {
        setName(str(e.target.value));
    }

    return (
        <div>
            <input
                type="text"
                value={name}
                onChange={handleChange}
            />
            <p>Hello, {name}</p>
        </div>
    );
}
