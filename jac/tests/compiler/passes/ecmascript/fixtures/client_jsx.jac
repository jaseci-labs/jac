"""Combined JSX fixture covering client declarations and varied JSX patterns."""

cl glob API_URL: str = "https://api.example.com";

cl obj ButtonProps {
    has label: str = "Hello";
    has count: int = 0;
}

cl walker MyComponent {
    has title: str = "My Component";
}

cl def component() {
    return <div class="box">
        <h1>
            Hello
        </h1>
        <p>
            Welcome!
        </p>
    </div>;
}

def server_only() -> str {
    return "not included";
}

cl def jsx_bug_tests() {
    # Constructor calls in JSX
    component = MyComponent(title="Custom Title");
}

with entry {
    # Common values used across scenarios
    name = "World";
    age = 30;
    count = 42;
    props = "dummy_props";
    extraProps = "extra_props";

    # Basic JSX shapes
    basic_div = <div />;
    basic_component = <MyComponent />;
    attribute_button = <button
        id="submit"
        disabled
    />;
    attr_with_expr = <div
        id={name}
        data-age={age}
    >
        User Info
    </div>;

    # Expressions embedded in JSX
    greeting = <h1>
        {"Hello " + name + "!"}
    </h1>;
    button = <button
        id={name}
        count={count}
    >
        {"Click"}
    </button>;
    computed = <div>
        {count + 10}
    </div>;

    # Nested elements and layout
    card = <div>
        <h1>
            {"Title"}
        </h1>
        <p>
            {"Description"}
        </p>
        <button>
            {"Click"}
        </button>
    </div>;

    layout = <div>
        <header>
            <nav>
                <a>
                    {"Home"}
                </a>
                <a>
                    {"About"}
                </a>
            </nav>
        </header>
        <main>
            <article>
                {"Content here"}
            </article>
        </main>
    </div>;

    # Components and namespaces
    comp_props = <Button
        color="blue"
        size="large"
    >
        Submit
    </Button>;
    comp_namespaced = <UI.Button />;
    comp_deep_namespace = <Form.Input.Text />;
    app = <App>
        <Header />
        <Main>
            <Sidebar />
            <Content />
        </Main>
        <Footer />
    </App>;

    # Fragments
    empty_fragment = <></>;
    fragment_with_children = <>
        <h1>
            {"Title"}
        </h1>
        <p>
            {"Paragraph"}
        </p>
    </>;
    mixed_fragment = <>
        {"Some text"}
        <div>
            {"Element"}
        </div>
        {"More text"}
        <span>
            {"Inline"}
        </span>
    </>;

    # Spread attributes
    spread_div = <div
        {...props}
    />;
    spread_button = <button
        {...props}
        {...extraProps}
    >
        {"Click"}
    </button>;
    spread_input = <input
        type="text"
        {...props}
        disabled
    />;
}
