"""Test client app with relative import from another cl module."""

cl import from .client_ui_components { Button, Card, }

cl def: pub main_page()  -> any {
    return <div class="app">
        <Card title="Welcome" />
        <Button label="Click Me" />
    </div>;
}
