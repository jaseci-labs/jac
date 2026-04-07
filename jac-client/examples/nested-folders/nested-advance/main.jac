# Nested Folder Levels Example
cl import from .ButtonRoot { ButtonRoot }
cl import from .level1.ButtonSecondL { ButtonSecondL }
cl import from .level1.level2.ButtonThirdL { ButtonThirdL }
cl import from .level1.Card { Card }

cl def:pub app -> JsxElement {
    return
        <div style={{padding: "20px"}}>
            <h1>
                Nested Folder Levels Demo
            </h1>
            <div style={{margin: "10px 0"}}>
                <ButtonRoot/>
            </div>
            <div style={{margin: "10px 0"}}>
                <ButtonSecondL/>
            </div>
            <div style={{margin: "10px 0"}}>
                <ButtonThirdL/>
            </div>
            <div style={{margin: "10px 0"}}>
                <Card/>
            </div>
        </div>;
}
