cl import from .button {
    CustomButton
}

cl def RelativeImport() -> any {
    return <div>
        <CustomButton />
    </div>;
}

cl def main() -> any {
    return <RelativeImport />;
}