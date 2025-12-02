# JSX Elements with Contextual Lexing
# Demonstrates various JSX features supported in Jac

# Simple component function that returns JSX
def Button(text: str, onclick: str) -> dict {
    return <button
        onclick={onclick}
    >
        {text}
    </button>;
}

# Component with multiple props
def Card(
    title: str, content: str, className: str
) -> dict {
    return (
        <div
            class={className}
        >
            <h2>
                {title}
            </h2>
            <p>
                {content}
            </p>
        </div>
    );
}

with entry {
    # 1. Basic HTML element with text
    let basic_element = <div>
        Hello World
    </div>;
    print("Basic element:", basic_element);

    # 2. Element with attributes
    let with_attrs = <div
        class="container"
        id="main"
    >
        Content
    </div>;
    print("With attributes:", with_attrs);

    # 3. Self-closing element
    let self_closing = <img
        src="image.jpg"
        alt="Description"
    />;
    print("Self-closing:", self_closing);

    # 4. Nested elements
    let nested = (
        <div>
            <h1>
                Title
            </h1>
            <p>
                Paragraph text
            </p>
        </div>
    );
    print("Nested elements:", nested);

    # 5. Elements with expression attributes
    let name = "user123";
    let age = 25;
    let user_element = <div
        id={name}
        data-age={age}
    >
        User Info
    </div>;
    print("Expression attributes:", user_element);

    # 6. Elements with expression children
    let count = 42;
    let with_expr_child = <div>
        Count: {count}
    </div>;
    print("Expression children:", with_expr_child);

    # 7. Component usage (capitalized names)
    let button = <Button
        text="Click Me"
        onclick="handleClick()"
    />;
    print("Component:", button);

    # 8. Spread attributes
    let props = {"class": "btn", "type": "submit"};
    let with_spread = <button
        {...props}
    >
        Submit
    </button>;
    print("Spread attributes:", with_spread);

    # 9. Mixed attributes and spread
    let base_props = {"class": "card"};
    let card = <Card
        {...base_props}
        title="Welcome"
        content="Hello!"
        className="custom"
    />;
    print("Mixed spread:", card);

    # 10. Complex nested structure
    let app = (
        <div class="app">
            <header>
                <h1>
                    My App
                </h1>
                <nav>
                    <a href="/home">
                        Home
                    </a>
                    <a href="/about">
                        About
                    </a>
                </nav>
            </header>
            <main>
                <Card
                    title="Card 1"
                    content="First card"
                    className="card-primary"
                />
                <Card
                    title="Card 2"
                    content="Second card"
                    className="card-secondary"
                />
            </main>
            <footer>
                <p>
                    Footer text
                </p>
            </footer>
        </div>
    );
    print("Complex structure:", app);

    # 11. Fragment (no tag name)
    let fragment = (
        <>
            <div>
                First
            </div>
            <div>
                Second
            </div>
        </>
    );
    print("Fragment:", fragment);

    # 12. Dynamic list rendering
    let items = ["Apple", "Banana", "Cherry"];
    let list_items = [
        (
            <li
                key={i}
            >
                {item}
            </li>
        ) for (i, item) in enumerate(items)
    ];
    let list_element = <ul>
        {list_items}
    </ul>;
    print("Dynamic list:", list_element);

    # 13. Conditional rendering with expressions
    let is_logged_in = True;
    let user_name = "Alice";
    let greeting = <div>
        {f"Welcome, {user_name}!" if is_logged_in else "Please log in"}
    </div>;
    print("Conditional:", greeting);

    print("\nAll JSX examples completed successfully!");
}
