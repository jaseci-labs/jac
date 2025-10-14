# <span style="color: orange; font-weight: bold">Jac in a Flash</span>

This mini tutorial uses a single toy program to highlight the major pieces of
the Jac language. We start with a simple Python program that finds friends in a
social network and gradually evolve it into a fully object‑spatial Jac
implementation. Each iteration introduces a new Jac feature while keeping the
overall behaviour identical.

## Step&nbsp;0 – The Python version

Our starting point is a regular Python program that finds all friends within a
social network. Given a person, it discovers their direct friends and friends of
friends.

=== "friends.py"
    ```python linenums="1"
    --8<-- "jac/examples/friends_finder/friends.py"
    ```

## Step&nbsp;1 – A direct Jac translation

`friends1.jac` mirrors the Python code almost line for line. Classes are
declared with `obj` and methods with `def`. Statements end with a semicolon.
Program execution happens inside a `with entry { ... }` block, which replaces
Python's `if __name__ == "__main__":` section. This step shows how familiar
Python concepts map directly to Jac syntax.

=== "friends1.jac"
    ```jac linenums="1"
    --8<-- "jac/examples/friends_finder/friends1.jac"
    ```

## Step&nbsp;2 – Declaring fields with `has`

The second version moves attribute definitions into the class body using the
`has` keyword. Fields may specify types and default values directly on the
declaration. Methods that take no parameters can omit parentheses in their
signature, making the code more concise.

=== "friends2.jac"
    ```jac linenums="1"
    --8<-- "jac/examples/friends_finder/friends2.jac"
    ```

## Step&nbsp;3 – Separating implementation with `impl`

The third version splits object declarations from their implementations using
`impl`. The object lists method signatures, and the actual bodies are provided
later in `impl ClassName.method` blocks. This separation keeps the interface
clean and helps organize larger codebases.

=== "friends3.jac"
    ```jac linenums="1"
    --8<-- "jac/examples/friends_finder/friends3.jac"
    ```
=== "friends3.impl.jac"
    ```jac linenums="1"
    --8<-- "jac/examples/friends_finder/friends3.impl.jac"
    ```

## Step&nbsp;4 – Object Spatial Programming with walkers and nodes

Now we introduce **Object Spatial Programming (OSP)**, one of Jac's most
powerful features. Instead of recursively calling methods on a list of friends,
we model the social network as a **graph** and use a **walker** to traverse it.

Key OSP concepts:
- **`node`**: Represents entities (people) in a graph structure
- **`edge`**: Represents relationships (friendships) between nodes
- **`walker`**: An object that traverses the graph and performs actions
- **`++>`**: Connects nodes with edges to build the graph
- **`spawn`**: Launches a walker to start traversing from a specific node
- **`visit`**: Makes the walker move to connected nodes
- **`here`**: References the current node the walker is visiting

This version is actually **simpler** than the object-oriented approach because
Jac handles the traversal logic for you—no manual recursion needed!

=== "friends4.jac"
    ```jac linenums="1"
    --8<-- "jac/examples/friends_finder/friends4.jac"
    ```

In this OSP version:
- People are **nodes** in a graph, not isolated objects
- Friendships are **edges** that connect nodes
- The **walker** automatically traverses the graph structure
- `visit [-->]` moves to all connected nodes—no manual loops!
- The walker's **abilities** (`can` blocks) trigger when visiting specific node types

## Step&nbsp;5 – Scale Agnostic Approach

The fifth version demonstrates Jac's scale-agnostic design. The same code that
runs locally can seamlessly scale to cloud deployment without modification. By
running the command `jac serve friends5.jac`, the walker becomes an API
endpoint that can be called via HTTP requests. The graph structure persists
across requests using Jac's built-in `root` node, which is unique per user.

=== "friends5.jac"
    ```jac linenums="1"
    --8<-- "jac/examples/friends_finder/friends5.jac"
    ```

When you run `jac serve friends5.jac`, you can call the walkers via HTTP:
```bash
curl -X POST http://localhost:8000/walker/FriendFinder \
  -H "Content-Type: application/json" \
  -d '{"starting_person": "Alice"}'
```

## Step&nbsp;6 – AI-Enhanced with byLLM

The final version integrates AI capabilities using byLLM. Instead of just
listing friends, the walker now generates personalized messages for each friend
using an LLM. This demonstrates how easily AI can be woven into Jac
applications.

=== "friends6.jac"
    ```jac linenums="1"
    --8<-- "jac/examples/friends_finder/friends6.jac"
    ```

??? info "How To Run"
    1. Install the byLLM plugin: `pip install byllm`
    2. Get a free API key from [OpenAI](https://platform.openai.com/api-keys) or [Google AI Studio](https://aistudio.google.com/app/apikey)
    3. Set your API key as an environment variable: `export OPENAI_API_KEY="xxxxxxxx"`
    4. Run with: `jac run friends6.jac`

Happy coding!
