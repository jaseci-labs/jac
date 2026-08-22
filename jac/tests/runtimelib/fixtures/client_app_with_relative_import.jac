"""Test client app with relative import from another cl module."""

import from .client_ui_components { Button, Card, }

def:pub main_page -> JsxElement {
    <div class="app">
        <Card title="Welcome"/>
        <Button label="Click Me"/>
    </div>
}
