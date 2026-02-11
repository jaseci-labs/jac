# Third Level Button (level1/level2/)
cl import from antd { Button }
cl import from ...ButtonRoot { ButtonRoot }
cl import from ..ButtonSecondL { ButtonSecondL }

cl def:pub ButtonThirdL -> JsxElement {
    return
        <div>
            <Button type="dashed" size="large">
                Third Level Button (imports from root and second level)
            </Button>
            <div style={{marginTop: "10px"}}>
                <ButtonRoot />
            </div>
            <div style={{marginTop: "10px"}}>
                <ButtonSecondL />
            </div>
        </div>;
}
