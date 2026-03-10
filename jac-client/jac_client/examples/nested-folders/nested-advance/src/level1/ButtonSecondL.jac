# Second Level Button (level1/)
cl import from antd { Button }
cl import from ..ButtonRoot { ButtonRoot }

cl def:pub ButtonSecondL -> JsxElement {
    return
        <div>
            <Button type="default" size="large">
                Second Level Button (imports from root)
            </Button>
            <div style={{marginTop: "10px"}}>
                <ButtonRoot/>
            </div>
        </div>;
}
