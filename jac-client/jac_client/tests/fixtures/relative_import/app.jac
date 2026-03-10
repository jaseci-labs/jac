cl import from .button { CustomButton }

cl def RelativeImport()  -> JsxElement {
    return <div>
        <CustomButton />
    </div>;
}

cl def app()  -> JsxElement {
    return <RelativeImport />;
}
