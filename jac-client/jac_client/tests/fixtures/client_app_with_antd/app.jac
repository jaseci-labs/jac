"""Sample Jac module using Ant Design components."""

cl import from antd { Button }

cl glob APP_NAME: str = "Ant Design Test";

cl def ButtonTest() {
    return <div>
        <h1>
            {APP_NAME}
        </h1>
        <p>
            Testing Ant Design integration
        </p>
        <Button>
            Click Me
        </Button>
    </div>;
}

cl def CardTest() {
    return <div class="card-wrapper">
        <h2>
            Card Component
        </h2>
    </div>;
}

cl def app() {
    return <div>
        <ButtonTest />
        <CardTest />
    </div>;
}
