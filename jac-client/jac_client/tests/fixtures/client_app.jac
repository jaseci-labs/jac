"""Sample Jac module containing client-side declarations."""

cl let API_LABEL: str = "Runtime Test";

cl obj ButtonProps {
    has label: str = "Tap Me";
    has color: str = "primary";
}

cl def client_page() {
    let props = ButtonProps(label="Tap Me", color="primary");
    return <div class="app">
        <h1>{API_LABEL}</h1>
        <button class={props.color} data-id="button">
            {props.label}
        </button>
    </div>;
}
