# Card Component on Second Level
# Imports from both above (root) and below (level2)
cl import from ..ButtonRoot {
    ButtonRoot
}
cl import from .level2.ButtonThirdL { ButtonThirdL }

cl def:pub Card -> JsxElement {
    return
        <div
            style={{
                border: "2px solid #007bff",
                borderRadius: "8px",
                padding: "20px",
                margin: "10px 0",
                backgroundColor: "#f8f9fa"
            }}
        >
            <h3>
                Card Component (Second Level)
            </h3>
            <p>
                This card imports from:
            </p>
            <ul>
                <li>
                    Root level: ButtonRoot (using ..)
                </li>
                <li>
                    Third level: ButtonThirdL (using .level2)
                </li>
            </ul>
            <div style={{marginTop: "15px"}}>
                <ButtonRoot/>
            </div>
            <div style={{marginTop: "10px"}}>
                <ButtonThirdL/>
            </div>
        </div>;
}
