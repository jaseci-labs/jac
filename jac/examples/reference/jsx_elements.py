from __future__ import annotations
from jaclang.lib import jsx


def Button(text: str, onclick: str) -> dict:
    return jsx("button", {"onclick": onclick}, [text])


def Card(title: str, content: str, className: str) -> dict:
    return jsx(
        "div", {"class": className}, [jsx("h2", {}, [title]), jsx("p", {}, [content])]
    )


basic_element = jsx("div", {}, ["Hello World"])
print("Basic element:", basic_element)
with_attrs = jsx("div", {"class": "container", "id": "main"}, ["Content"])
print("With attributes:", with_attrs)
self_closing = jsx("img", {"src": "image.jpg", "alt": "Description"}, [])
print("Self-closing:", self_closing)
nested = jsx("div", {}, [jsx("h1", {}, ["Title"]), jsx("p", {}, ["Paragraph text"])])
print("Nested elements:", nested)
name = "user123"
age = 25
user_element = jsx("div", {"id": name, "data-age": age}, ["User Info"])
print("Expression attributes:", user_element)
count = 42
with_expr_child = jsx("div", {}, ["Count: ", count])
print("Expression children:", with_expr_child)
button = jsx(Button, {"text": "Click Me", "onclick": "handleClick()"}, [])
print("Component:", button)
props = {"class": "btn", "type": "submit"}
with_spread = jsx("button", {**{}, **props}, ["Submit"])
print("Spread attributes:", with_spread)
base_props = {"class": "card"}
card = jsx(
    Card,
    {
        **{**{**{**{}, **base_props}, "title": "Welcome"}, "content": "Hello!"},
        "className": "custom",
    },
    [],
)
print("Mixed spread:", card)
app = jsx(
    "div",
    {"class": "app"},
    [
        jsx(
            "header",
            {},
            [
                jsx("h1", {}, ["My App"]),
                jsx(
                    "nav",
                    {},
                    [
                        jsx("a", {"href": "/home"}, ["Home"]),
                        jsx("a", {"href": "/about"}, ["About"]),
                    ],
                ),
            ],
        ),
        jsx(
            "main",
            {},
            [
                jsx(
                    Card,
                    {
                        "title": "Card 1",
                        "content": "First card",
                        "className": "card-primary",
                    },
                    [],
                ),
                jsx(
                    Card,
                    {
                        "title": "Card 2",
                        "content": "Second card",
                        "className": "card-secondary",
                    },
                    [],
                ),
            ],
        ),
        jsx("footer", {}, [jsx("p", {}, ["Footer text"])]),
    ],
)
print("Complex structure:", app)
fragment = jsx(None, {}, [jsx("div", {}, ["First"]), jsx("div", {}, ["Second"])])
print("Fragment:", fragment)
items = ["Apple", "Banana", "Cherry"]
list_items = [jsx("li", {"key": i}, [item]) for i, item in enumerate(items)]
list_element = jsx("ul", {}, [list_items])
print("Dynamic list:", list_element)
is_logged_in = True
user_name = "Alice"
greeting = jsx(
    "div", {}, [f"Welcome, {user_name}!" if is_logged_in else "Please log in"]
)
print("Conditional:", greeting)
print("\nAll JSX examples completed successfully!")
