cl import from .components.button { CustomButton }
cl import from .button { CustomButtonRoot }

cl def RelativeImport -> JsxElement {
    return
        <div>
            <CustomButton/>
            <CustomButtonRoot/>
        </div>;
}

cl def:pub app -> JsxElement {
    return
        <RelativeImport/>;
}
