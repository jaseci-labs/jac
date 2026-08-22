"""Sample Jac module using Ant Design components."""

import from antd { Button }

glob APP_NAME: str = "Ant Design Test";

def ButtonTest {
    <div>
        <h1>{APP_NAME}</h1>
        <p>Testing Ant Design integration</p>
        <Button>Click Me</Button>
    </div>
}

def CardTest {
    <div class="card-wrapper">
        <h2>Card Component</h2>
    </div>
}

def app {
    <div>
        <ButtonTest/>
        <CardTest/>
    </div>
}
