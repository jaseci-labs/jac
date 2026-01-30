"""Sample Jac module containing client-side declarations."""

cl import from "@jac/runtime" { renderJsxTree, }

cl glob: pub API_LABEL: str = "Runtime Test";

cl obj: pub ButtonProps {
    has label: str = "Tap Me";
    has color: str = "primary";
}

cl def: pub client_page() {
    props = ButtonProps(label="Tap Me", color="primary");
    return <div class="app">
        <h1>
            {API_LABEL}
        </h1>
        <button
            class={props.color}
            data-id="button"
        >
            {props.label}
        </button>
    </div>;
}
