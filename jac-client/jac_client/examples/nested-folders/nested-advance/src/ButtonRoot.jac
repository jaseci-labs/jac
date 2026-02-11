# Root Level Button
cl import from antd { Button }

cl def:pub ButtonRoot -> JsxElement {
    return
        <Button type="primary" size="large">
            Root Level Button
        </Button>;
}
