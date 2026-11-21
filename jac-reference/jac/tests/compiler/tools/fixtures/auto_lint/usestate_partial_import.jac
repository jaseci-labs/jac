"""Fixture for W3038: useState is NOT the only import — partial removal, comma edge cases."""

import from "react" { JsxElement, useState, useEffect }

def:pub NameInput() -> JsxElement {
    [name, setName] = useState("");

    def handleChange(e: any) {
        setName(str(e.target.value));
    }

    return (
        <div>
            <input type="text" value={name} onChange={handleChange}/>
            <p>Hello, {name}</p>
        </div>
    );
}
