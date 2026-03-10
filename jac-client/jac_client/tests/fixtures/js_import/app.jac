"""Test module that imports JavaScript functions."""

cl import from .utils { formatMessage, calculateSum, JS_CONSTANT, MessageFormatter }

cl glob JS_IMPORT_LABEL: str = "JavaScript Import Test";

cl def JsImportTest()  -> JsxElement {
    greeting = formatMessage("Jac");
    sum = calculateSum(5, 3);
    formatter = MessageFormatter("JS");
    formatted = formatter.format("Hello from JS class");

    return <div class="js-import-test">
        <h1>
            {JS_IMPORT_LABEL}
        </h1>
        <p>
            Greeting: {greeting}
        </p>
        <p>
            Sum (5 + 3): {sum}
        </p>
        <p>
            Constant: {JS_CONSTANT}
        </p>
        <p>
            Formatted: {formatted}
        </p>
    </div>;
}

cl def app()  -> JsxElement {
    return <JsImportTest />;
}
