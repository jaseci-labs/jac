"""Test module that imports JavaScript functions."""

import from .utils { formatMessage, calculateSum, JS_CONSTANT, MessageFormatter }

glob JS_IMPORT_LABEL: str = "JavaScript Import Test";

def JsImportTest -> JsxElement {
    greeting = formatMessage("Jac");
    sum = calculateSum(5, 3);
    formatter = MessageFormatter("JS");
    formatted = formatter.format("Hello from JS class");

    <div class="js-import-test">
        <h1>{JS_IMPORT_LABEL}</h1>
        <p>Greeting: {greeting}</p>
        <p>Sum (5 + 3): {sum}</p>
        <p>Constant: {JS_CONSTANT}</p>
        <p>Formatted: {formatted}</p>
    </div>
}

def app -> JsxElement {
    <JsImportTest/>
}
