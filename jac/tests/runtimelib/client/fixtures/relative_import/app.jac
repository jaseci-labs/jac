import from .button { CustomButton }

def RelativeImport -> JsxElement {
    <div>
        <CustomButton/>
    </div>
}

def app -> JsxElement {
    <RelativeImport/>
}
