cl import from .components.button { CustomButton }
cl import from .button { CustomButtonRoot }

cl def RelativeImport -> any {
    return <div>
        <CustomButton />
        <CustomButtonRoot />
    </div>;
}

cl def app -> any {
    return <RelativeImport />;
}
