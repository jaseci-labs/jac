"""Combined JSX fixture covering client declarations and varied JSX patterns."""

cl let API_URL: str = "https://api.example.com";

cl obj ButtonProps {
    has label: str = "Hello";
    has count: int = 0;
}

cl def component() {
    return <div class="box">
        <h1>Hello</h1>
        <p>Welcome!</p>
    </div>;
}

def server_only() {
    return "not included";
}

with entry {
    # Common values used across scenarios
    let name = "World";
    let age = 30;
    let count = 42;
    let props = "dummy_props";
    let extraProps = "extra_props";

    # Basic JSX shapes
    let basic_div = <div />;
    let basic_component = <MyComponent />;
    let attribute_button = <button id="submit" disabled />;
    let attr_with_expr = <div id={name} data-age={age}>User Info</div>;

    # Expressions embedded in JSX
    let greeting = <h1>{"Hello " + name + "!"}</h1>;
    let button = <button id={name} count={count}>{"Click"}</button>;
    let computed = <div>{count + 10}</div>;

    # Nested elements and layout
    let card = <div>
        <h1>{"Title"}</h1>
        <p>{"Description"}</p>
        <button>{"Click"}</button>
    </div>;

    let layout = <div>
        <header>
            <nav>
                <a>{"Home"}</a>
                <a>{"About"}</a>
            </nav>
        </header>
        <main>
            <article>{"Content here"}</article>
        </main>
    </div>;

    # Components and namespaces
    let comp_props = <Button color="blue" size="large">Submit</Button>;
    let comp_namespaced = <UI.Button />;
    let comp_deep_namespace = <Form.Input.Text />;
    let app = <App>
        <Header />
        <Main>
            <Sidebar />
            <Content />
        </Main>
        <Footer />
    </App>;

    # Fragments
    let empty_fragment = <></>;
    let fragment_with_children = <>
        <h1>{"Title"}</h1>
        <p>{"Paragraph"}</p>
    </>;
    let mixed_fragment = <>
        {"Some text"}
        <div>{"Element"}</div>
        {"More text"}
        <span>{"Inline"}</span>
    </>;

    # Spread attributes
    let spread_div = <div {...props} />;
    let spread_button = <button {...props} {...extraProps}>{"Click"}</button>;
    let spread_input = <input type="text" {...props} disabled />;
}
