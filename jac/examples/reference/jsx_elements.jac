# JSX Elements with Contextual Lexing
# Demonstrates various JSX features supported in Jac

# Simple component function that returns JSX
def Button(text: str, onclick: str) -> dict {
    return
        <button onclick={onclick}>
            {text}
        </button>;
}

# Component with multiple props
def Card(
    title: str, content: str, className: str
) -> dict {
    return (
        <div class={className}>
            <h2>
                {title}
            </h2>
            <p>
                {content}
            </p>
        </div>
    );
}

# 1. Basic HTML element with text
glob basic_element = <div>
         Hello World
     </div>;

with entry {
    print("Basic element:", basic_element);
}

# 2. Element with attributes
glob with_attrs = <div class="container" id="main">
         Content
     </div>;

with entry {
    print("With attributes:", with_attrs);
}

# 3. Self-closing element
glob self_closing = <img
         src="image.jpg"
         alt="Description"
     />;

with entry {
    print("Self-closing:", self_closing);
}

# 4. Nested elements
glob nested = (
         <div>
             <h1>
                 Title
             </h1>
             <p>
                 Paragraph text
             </p>
         </div>
     );

with entry {
    print("Nested elements:", nested);
}

# 5. Elements with expression attributes
glob name = "user123",
     age = 25,
     user_element = <div id={name} data-age={age}>
         User Info
     </div>;

with entry {
    print("Expression attributes:", user_element);
}

# 6. Elements with expression children
glob count = 42,
     with_expr_child = <div>
         Count: {count}
     </div>;

with entry {
    print("Expression children:", with_expr_child);
}

# 7. Component usage (capitalized names)
glob button = <Button
         text="Click Me"
         onclick="handleClick()"
     />;

with entry {
    print("Component:", button);
}

# 8. Spread attributes
glob props = {"class": "btn", "type": "submit"},
     with_spread = <button {...props}>
         Submit
     </button>;

with entry {
    print("Spread attributes:", with_spread);
}

# 9. Mixed attributes and spread
glob base_props = {"class": "card"},
     card = <Card
         {...base_props}
         title="Welcome"
         content="Hello!"
         className="custom"
     />;

with entry {
    print("Mixed spread:", card);
}

# 10. Complex nested structure
glob app = (
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
                 <Card title="Card 1" content="First card" className="card-primary" />
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

with entry {
    print("Complex structure:", app);
}

# 11. Fragment (no tag name)
glob fragment = (
         <>
             <div>
                 First
             </div>
             <div>
                 Second
             </div>
         </>
     );

with entry {
    print("Fragment:", fragment);
}

# 12. Dynamic list rendering
glob items = ["Apple", "Banana", "Cherry"],
     list_items = [
         (
             <li key={i}>
                 {item}
             </li>
         ) for (i, item) in enumerate(items)
     ],
     list_element = <ul>
         {list_items}
     </ul>;

with entry {
    print("Dynamic list:", list_element);
}

# 13. Conditional rendering with expressions
glob is_logged_in = True,
     user_name = "Alice",
     greeting = <div>
         {f"Welcome, {user_name}!" if is_logged_in else "Please log in"}
     </div>;

with entry {
    print("Conditional:", greeting);

    print("\nAll JSX examples completed successfully!");
}
