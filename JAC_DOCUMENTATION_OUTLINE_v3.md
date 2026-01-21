# Jac Language Reference

## Complete Single-Page Documentation (v3)

> The AI-Native Full-Stack Programming Language
>
> *One Language for Backend, Frontend, and AI*

---

## How to Use This Document

Single-page reference for Jac. Use browser search (Ctrl+F) to find topics.

**Conventions:**

- `monospace` - Keywords, types, operators
- **Bold** - Key terms
- Notes describe what code examples should show
- Canonical syntax included only for Jac-unique features

---

## Table of Contents

**Part I: Foundation**

1. Introduction
2. Getting Started
3. Language Basics
4. Types and Values
5. Variables and Scope
6. Operators
7. Control Flow

**Part II: Functions and Objects**
8. Functions and Abilities
9. Object-Oriented Programming
10. Implementations and Forward Declarations

**Part III: Object-Spatial Programming (OSP)**
11. Introduction to OSP
12. Nodes
13. Edges
14. Walkers
15. Graph Construction
16. Graph Traversal
17. Data Spatial Queries
18. Typed Context Blocks

**Part IV: Full-Stack Development**
19. Module System
20. Server-Side Development
21. Client-Side Development (JSX)
22. Server-Client Communication
23. Authentication & Users
24. Memory & Persistence
25. Development Tools (HMR, Watcher)

**Part V: AI Integration**
26. Meaning Typed Programming
27. Semantic Strings
28. The `by` Operator and LLM Delegation
29. Agentic AI Patterns

**Part VI: Concurrency**
30. Async/Await
31. Concurrent Expressions (flow/wait)

**Part VII: Advanced Features**
32. Error Handling
33. Testing
34. Filter and Assign Comprehensions
35. Pipe Operators

**Part VIII: Ecosystem**
36. CLI Reference
37. Plugin System
38. Project Configuration
39. Python Interoperability
40. JavaScript/TypeScript Interoperability

**Part IX: Deployment and Scaling**
41. jac-scale Plugin
42. Kubernetes Deployment
43. Production Architecture

**Appendices**

- A. Complete Keyword Reference
- B. Operator Quick Reference
- C. Grammar Summary (BNF)
- D. Common Gotchas
- E. Migration from Python
- F. LLM Provider Reference
- G. Breaking Changes

---

# Part I: Foundation

## 1. Introduction

### 1.1 What is Jac?

**Notes:** Jac is an AI-native full-stack language extending Python and TypeScript with Object-Spatial Programming (OSP).

**Canonical syntax - Hello World:**

```jac
with entry {
    print("Hello, Jac!");
}
```

### 1.2 The Six Principles

| Principle | Description |
|-----------|-------------|
| **AI-Native** | LLMs as first-class types through Meaning Typed Programming |
| **Full-Stack** | Backend and frontend in one unified language |
| **Superset** | Full access to PyPI and npm ecosystems |
| **Object-Spatial** | Graph-based domain modeling with mobile walkers |
| **Cloud-Native** | One-command deployment with automatic scaling |
| **Designed for Humans & AI** | Readable structure that both humans and AI models can work with |

### 1.3 Designed for Humans and AI

**Notes:**

- Language built for readability and architectural clarity
- Features that help both humans and AI models:
  - `has` declarations for clean attribute definitions
  - `impl` separation (interfaces separate from implementations)
- Structure that humans can reason about AND models can reliably generate

### 1.4 When to Use Jac

**Notes:** Graph-structured apps, AI-powered apps, full-stack web, agentic systems, rapid prototyping

### 1.5 Jac vs Python

**Canonical syntax - Object comparison:**

```jac
obj Person {
    has name: str;
    has age: int;

    can greet -> str {
        return f"Hi, I'm {self.name}";
    }
}
```

**Key differences:** Braces `{}`, semicolons required, `has` for fields, `can` for methods, mandatory types

---

## 2. Getting Started

### 2.1 Installation

**Notes:** `pip install jaclang[all]` for full install, individual plugins available

### 2.2 Your First Program

**Notes:** Show function definition, `with entry` block, running with `jac run`

### 2.3 Project Structure

**Notes:** Show `jac.toml`, directory layout, file extensions table:

| Extension | Purpose |
|-----------|---------|
| `.jac` | Universal Jac code |
| `.sv.jac` | Server-side only |
| `.cl.jac` | Client-side only |
| `.impl.jac` | Implementation file |

### 2.4 Editor Setup

**Notes:** VS Code extension, `jac lsp` command

---

## 3. Language Basics

### 3.1 Source Code Encoding

**Notes:** UTF-8, Unicode support in strings

### 3.2 Comments

**Canonical syntax:**

```jac
# Single-line comment

#* Multi-line
   comment *#

"""Docstring"""
```

### 3.3 Statements and Expressions

**Notes:** Semicolons required, statement types

### 3.4 Code Blocks

**Canonical syntax:**

```jac
if condition {
    statement;
}
```

### 3.5 Keywords

**Notes:** Full keyword list table (abstract, and, as, assert, async, await, break, by, can, case, class, continue, def, default, del, disengage, edge, elif, else, entry, enum, except, exit, finally, flow, for, from, glob, has, here, if, impl, import, in, include, init, is, lambda, match, node, nonlocal, not, obj, or, override, postinit, priv, props, protect, pub, raise, report, return, root, self, sem, skip, spawn, static, super, switch, test, to, try, visitor, wait, walker, while, with, yield)

### 3.6 Identifiers

**Notes:** Naming rules, keyword escaping with `<>`

### 3.7 Entry Point Variants

**Canonical syntax:**

```jac
with entry { }              # Default - always runs
with entry:__main__ { }     # Only when file is main
with entry:setup { }        # Named entry
```

**Notes:** `jac run` vs `jac enter file.jac setup`

---

## 4. Types and Values

### 4.1 Builtin Types

**Notes:** Table of int, float, str, bool, bytes, list, tuple, set, dict, any, type, None

### 4.2 Type Annotations

**Canonical syntax:**

```jac
has name: str;
has count: int = 0;
has items: list[str] = [];
```

### 4.3 Generic Types

**Notes:** Show `def first[T](items: list[T]) -> T`

### 4.4 Union Types

**Notes:** Show `int | str | None`

### 4.5 Type References (Backtick)

**Canonical syntax:**

```jac
`TypeName    # Type reference
`root        # Root reference
[-->(`?Person)]  # Filter by type
```

### 4.6 Literals

**Notes:** Numbers (decimal, hex, octal, binary), strings (regular, raw, bytes, f-strings), collections

---

## 5. Variables and Scope

### 5.1 Local Variables

**Notes:** Show typed and inferred declarations

### 5.2 Instance Variables (has)

**Canonical syntax:**

```jac
has name: str;              # Required
has age: int = 0;           # With default
static has count: int = 0;  # Static
has computed: int by postinit;  # Deferred initialization
```

**Deferred Initialization:**

- `by postinit` - Field computed in `postinit` method
- Useful when field depends on other initialized fields

### 5.3 Global Variables (glob)

**Canonical syntax:**

```jac
glob PI: float = 3.14159;

with entry {
    global PI;
    print(PI);
}
```

### 5.4 Scope Rules

**Notes:** Block, function, module, global/nonlocal keywords

---

## 6. Operators

### 6.1 Arithmetic Operators

**Notes:** +, -, *, /, //, %, **, @ (table)

### 6.2 Comparison Operators

**Notes:** ==, !=, <, >, <=, >=, is, is not, in, not in

### 6.3 Logical Operators

**Notes:** and/&&, or/||, not

### 6.4 Bitwise Operators

**Notes:** &, |, ^, ~, <<, >>

### 6.5 Assignment Operators

**Canonical syntax:**

```jac
x = 5;      # Simple
x := 5;     # Walrus (inline)
x += 1;     # Augmented
```

### 6.6 Null-Safe Operators

**Canonical syntax:**

```jac
obj?.field?.nested   # Safe access
list?[0]             # Safe index
```

### 6.7 Graph Operators (OSP)

**Canonical syntax:**

```jac
# Connection
node1 ++> node2              # Forward
node1 <++ node2              # Backward
node1 <++> node2             # Bidirectional
node1 +>: Edge :+> node2     # Typed edge

# Edge reference
[-->]                        # Outgoing
[<--]                        # Incoming
[<-->]                       # All
[-->(`?Type)]                # Filtered
[--> (attr > 5)]             # Condition
```

### 6.8 Pipe Operators

**Canonical syntax:**

```jac
result = data |> transform |> filter;  # Forward
result = filter <| data;               # Backward
```

### 6.9 The `by` Operator

**Canonical syntax:**

```jac
result = "prompt" by llm;
def func() -> str by llm();
```

### 6.10 Operator Precedence

**Notes:** Complete precedence table (lowest to highest)

---

## 7. Control Flow

### 7.1 Conditional Statements

**Canonical syntax:**

```jac
if cond {
} elif cond {
} else {
}

# Ternary
result = x if cond else y;
```

### 7.2 While Loops

**Notes:** While with optional else clause

### 7.3 For Loops

**Canonical syntax:**

```jac
for item in items { }
for (i, item) in enumerate(items) { }
for i = 0 to i < 10 by i += 1 { }
```

### 7.4 Pattern Matching

**Notes:** match/case with literal, sequence, mapping, class patterns

### 7.5 Switch Statement

**Notes:** switch/case/default (no fall-through)

### 7.6 Loop Control

**Notes:** break, continue, skip

### 7.7 Context Managers

**Notes:** with statement, async with

---

# Part II: Functions and Objects

## 8. Functions and Abilities

### 8.1 Function Declaration

**Canonical syntax:**

```jac
def greet(name: str) -> str {
    return f"Hello, {name}!";
}
```

### 8.2 Parameter Types

**Notes:** Positional, keyword, *args, **kwargs

### 8.3 Abilities (Methods)

**Canonical syntax:**

```jac
can greet -> str {
    return f"Hi, I'm {self.name}";
}

can compute -> float abs;  # Abstract
```

### 8.4 Static and Class Methods

**Notes:** static can, @classmethod

### 8.5 Lambda Expressions

**Canonical syntax:**

```jac
add = lambda x: int, y: int -> int: x + y;

process = lambda x: int -> int {
    result = x * 2;
    return result;
};
```

### 8.6 IIFE

**Notes:** Immediately invoked function expressions

### 8.7 Decorators

**Notes:** @decorator syntax

### 8.8 Access Modifiers

**Canonical syntax:**

```jac
def:pub public_method -> None { }
def:priv _helper -> None { }
def:protect _internal -> None { }
```

---

## 9. Object-Oriented Programming

### 9.1 Objects (Classes)

**Canonical syntax:**

```jac
obj Person {
    has name: str;
    has age: int;

    def init(name: str, age: int) { }
    def postinit { }
}
```

### 9.2 Inheritance

**Notes:** Single and multiple inheritance, override keyword

### 9.3 Enumerations

**Canonical syntax:**

```jac
enum Color {
    RED = "red",
    GREEN = "green",
    BLUE = "blue"
}

# With methods
enum Status {
    ACTIVE,
    with entry {
        can is_done -> bool { }
    }
}
```

### 9.4 Enums with Inline Python

**Canonical syntax:**

```jac
enum HttpStatus {
    OK = 200,
    ::py::
    def is_success(self):
        return 200 <= self.value < 300
    ::py::
}
```

### 9.5 Properties and Encapsulation

**Notes:** has:priv, has:protect patterns

---

## 10. Implementations and Forward Declarations

### 10.1 Forward Declarations

**Canonical syntax:**

```jac
obj User;   # Forward declare
obj Post;

obj User {
    has posts: list[Post];
}
```

### 10.2 Implementation Blocks

**Canonical syntax:**

```jac
obj Calculator {
    def add(a: int, b: int) -> int;  # Declaration
}

impl Calculator.add(a: int, b: int) -> int {
    return a + b;
}
```

### 10.3 Separate Implementation Files

**Notes:** `.impl.jac` convention

### 10.4 When to Use

**Notes:** Circular dependencies, code organization, plugin architectures

---

# Part III: Object-Spatial Programming (OSP)

## 11. Introduction to OSP

### 11.1 What is OSP?

**Notes:** Data as graphs, computation via mobile walkers, spatial context

### 11.2 Why OSP?

**Notes:** Natural graph modeling, AI agent architecture, separation of concerns

### 11.3 Core Concepts

| Concept | Description | Keyword |
|---------|-------------|---------|
| **Node** | Graph vertex | `node` |
| **Edge** | Connection | `edge` |
| **Walker** | Mobile agent | `walker` |
| **Root** | Entry point | `root` |
| **Here** | Current location | `here` |
| **Visitor** | Visiting walker | `visitor` |

### 11.4 Complete Example

**Notes:** Show node, edge, walker definitions and graph construction with spawn

---

## 12. Nodes

### 12.1 Node Declaration

**Canonical syntax:**

```jac
node Person {
    has name: str;
    has age: int;

    can greet with Visitor entry { }
}
```

### 12.2 Node Entry/Exit Abilities

**Canonical syntax:**

```jac
can on_enter with entry { }           # Any walker
can handle with MyWalker entry { }    # Specific walker
can on_exit with MyWalker exit { }    # Exit event
can process with Walker1 | Walker2 entry { }  # Union types
```

**Notes:** Union types allow a single ability to respond to multiple walker types

### 12.3 Node Inheritance

**Notes:** node Child(Parent) { }

---

## 13. Edges

### 13.1 Edge Declaration

**Canonical syntax:**

```jac
edge Knows {
    has since: int;
    has strength: float = 1.0;
}

edge Link { }  # No data
```

### 13.2 Edge Entry/Exit

**Notes:** Walkers trigger abilities during traversal

### 13.3 Directed vs Undirected

**Notes:** Direction is determined by connection operators

---

## 14. Walkers

### 14.1 Walker Declaration

**Canonical syntax:**

```jac
walker Collector {
    has items: list = [];

    can collect with `root entry {
        visit [-->];
    }

    can gather with DataNode entry {
        self.items.append(here.value);
        visit [-->];
    }
}
```

### 14.2 Walker State

**Notes:** Walkers maintain state as they traverse

### 14.3 The `visit` Statement

**Canonical syntax:**

```jac
visit [-->];              # All outgoing
visit [<--];              # All incoming
visit [-->(`?Person)];    # Type filter
visit [--> (age > 25)];   # Condition
visit : 0 : [-->];        # First only
visit [-->] else { };     # With fallback
```

### 14.4 The `report` Statement

**Canonical syntax:**

```jac
report here.value;  # Send data back (continues execution)
```

**Notes:** Unlike return, walker continues. Results collected in `.reports`

### 14.5 The `disengage` Statement

**Notes:** Stops walker traversal immediately

### 14.6 Spawning Walkers

**Canonical syntax:**

```jac
result = root spawn MyWalker();
result = node spawn MyWalker(param=value);
all_values = result.reports;

# Multi-target spawn
results = MyWalker() spawn [node1, node2, node3];
```

**Notes:** Multi-target spawn executes walker on multiple starting points concurrently

### 14.7 Walker Inheritance

**Canonical syntax:**

```jac
walker Child(Parent) {
    override can visit with Node entry {
        # Override parent behavior
    }
}
```

**Notes:** Use `override` keyword to replace inherited abilities

### 14.8 The `visitor` Reference

**Canonical syntax:**

```jac
node SecureRoom {
    can check with Inspector entry {
        if visitor.clearance >= self.required {
            print("Access granted");
        }
    }
}
```

**Special References Table:**

| Reference | Context | Description |
|-----------|---------|-------------|
| `self` | Any | Current instance |
| `here` | Walker ability | Current location |
| `visitor` | Node ability | Visiting walker |
| `root` | Anywhere | Root node |
| `super` | Subclass | Parent |

---

## 15. Graph Construction

### 15.1 Creating Nodes

**Notes:** Inline creation, assignment, multiple nodes

### 15.2 Creating Edges

**Canonical syntax:**

```jac
alice ++> bob;                    # Simple
alice +>: Knows(since=2020) :+> bob;  # Typed
```

### 15.3 Chained Construction

**Notes:** Building graph structures in chains

### 15.4 Deleting Nodes and Edges

**Canonical syntax:**

```jac
del here;              # Delete node
del [here --> target]; # Delete edge
```

### 15.5 Built-in Graph Functions

**Canonical syntax:**

```jac
id = jid(node);              # Get Jac ID of object
wrapper = jobj(node);        # Get Jac object wrapper
grant(node, user);           # Grant access permission
revoke(node, user);          # Revoke access permission
roots = allroots();          # Get all root references
save(node);                  # Persist node to storage
commit();                    # Commit pending changes
printgraph(root);            # Print graph for debugging
```

**Notes:** These built-in functions are essential for OSP operations:

| Function | Description |
|----------|-------------|
| `jid()` | Returns unique Jac identifier for any object |
| `jobj()` | Gets internal Jac wrapper for object introspection |
| `grant()`/`revoke()` | Permission management for multi-user graphs |
| `allroots()` | Returns all root nodes (useful for multi-tenant) |
| `save()` | Explicitly persists object to storage layer |
| `commit()` | Commits all pending changes in transaction |
| `printgraph()` | Outputs graph structure for debugging |

---

## 16. Graph Traversal

### 16.1 Basic Traversal

**Notes:** BFS-like queue-based visitation

### 16.2 Filtered Traversal

**Notes:** Type and condition filtering

### 16.3 Entry and Exit Events

**Notes:** Processing on enter vs exit

---

## 17. Data Spatial Queries

### 17.1 Edge Reference Syntax

**Canonical syntax:**

```jac
[-->]                          # Basic
[->: EdgeType :->]             # Typed
[-->(`?NodeType)]              # Node filter
[--> (attr > value)]           # Condition
[->: Edge(attr > x) :->]       # Edge condition
```

### 17.2 Attribute Filtering

**Notes:** Filtering by node and edge attributes

### 17.3 Complex Queries

**Notes:** Combining filters, chained traversal

---

## 18. Typed Context Blocks

### 18.1 What are Typed Context Blocks?

**Canonical syntax:**

```jac
can visit with Animal entry {
    -> Dog {
        print(f"{here.name} is a {here.breed}");
    }
    -> Cat {
        print(f"{here.name} is a cat");
    }
}
```

### 18.2 Tuple-Based Dispatch

**Notes:** `with (Type1, Type2) entry`

### 18.3 Context Blocks in Nodes

**Notes:** Nodes reacting to different walker types

---

# Part IV: Full-Stack Development

## 19. Module System

### 19.1 Import Statements

**Canonical syntax:**

```jac
import math;
import from typing { List, Dict }
import from .utils { helper }
import from react { useState }
import "./styles.css";
```

### 19.2 Include Statements

**Notes:** `include` merges code

### 19.3 npm Package Imports

**Notes:** React, Material UI, lodash examples

### 19.4 Export and Visibility

**Notes:** def:pub, walker:pub, def:priv

---

## 20. Server-Side Development

### 20.1 Server Code Blocks

**Canonical syntax:**

```jac
sv {
    node User { has id: str; }
    walker:priv CreateUser { }
}
```

### 20.2 REST API with jac start

**Notes:** Public walkers become endpoints, `jac start --port 8000`

### 20.3 Module Introspection

**Notes:** Runtime introspection of functions, walkers, API docs generation

### 20.4 Transport Layer

**Notes:** BaseTransport, HTTPTransport, request/response handling

---

## 21. Client-Side Development (JSX)

### 21.1 Client Code Blocks

**Canonical syntax:**

```jac
cl {
    import from react { useState }

    def:pub App -> any {
        has count: int = 0;
        return <div>{count}</div>;
    }
}
```

### 21.2 State Management with `has`

**Notes:** `has` creates reactive state in components

### 21.3 Effects and Lifecycle

**Notes:** useEffect patterns

### 21.4 JSX Syntax

**Notes:** Components, props, children, fragments

### 21.5 Styling Patterns

**Notes:** Multiple styling approaches supported:

- Inline styles with JavaScript objects
- Tailwind CSS classes
- `cn()` utility for conditional class merging (clsx + tailwind-merge)

**Canonical syntax:**

```jac
import from "@jac-client/utils" { cn }

className = cn("base-class", condition && "active", {"error": hasError});
```

### 21.6 Routing

**Notes:** react-router-dom integration

### 21.7 Client Bundle System

**Notes:** Vite-based bundling, ClientBundle/ClientBundleBuilder

---

## 22. Server-Client Communication

### 22.1 Calling Server Walkers

**Canonical syntax:**

```jac
async def addTodo -> None {
    result = root spawn AddTodo(title=text);
    newTodo = result.reports[0];
}
```

### 22.2 jacSpawn() Function

**Notes:** Client-side `jacSpawn()` for walker/function invocation

### 22.3 Starting Full-Stack Server

**Notes:** `jac start main.jac --port 8000 --watch`

---

## 23. Authentication & Users

### 23.1 Built-in Auth Functions

**Canonical syntax:**

```jac
import from "@jac-client/utils" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn }
```

### 23.2 User Management

**Notes:** UserManager, SQLite backing, password hashing, tokens

**User Operations:**

| Operation | Function/Endpoint | Description |
|-----------|-------------------|-------------|
| Register | `jacSignup()` | Create new user account |
| Login | `jacLogin()` | Authenticate and get JWT |
| Logout | `jacLogout()` | Clear client token |
| Update Username | API endpoint | Change username |
| Update Password | API endpoint | Change password |
| Guest Access | `__guest__` account | Anonymous user support |

### 23.3 Per-User Graph Isolation

**Notes:** Each user gets isolated root node

### 23.4 AuthHandler

**Notes:** Token validation, permission checks

### 23.5 Single Sign-On (SSO)

**Notes:** jac-scale supports SSO integration for production authentication:

**Configuration (jac.toml):**

```toml
[plugins.scale.sso.google]
client_id = "your-google-client-id"
client_secret = "your-google-client-secret"
```

**SSO Endpoints:**

| Endpoint | Description |
|----------|-------------|
| `/sso/{platform}/login` | Initiate SSO login flow |
| `/sso/{platform}/register` | Initiate SSO registration |
| `/sso/{platform}/login/callback` | OAuth callback handler |
| `/sso/{platform}/register/callback` | Registration callback |

**Supported Platforms:** Google OAuth (more planned)

**Notes:** SSO registration automatically creates user account with random password

---

## 24. Memory & Persistence

### 24.1 Memory Hierarchy

**Notes:** Tiered memory system:

| Tier | Type | Implementation |
|------|------|----------------|
| L1 | Volatile | VolatileMemory |
| L2 | Cache | LocalCacheMemory (TTL) |
| L3 | Persistent | SqliteMemory |

### 24.2 TieredMemory

**Notes:** Automatic read-through caching, write-through persistence

### 24.3 ExecutionContext

**Notes:** Manages system_root, user_root, entry_node, Memory

### 24.4 Anchor Management

**Notes:** Anchors for persistent object references

---

## 25. Development Tools

### 25.1 Hot Module Replacement (HMR)

**Notes:** `--watch` flag, automatic reloading, HotReloader class

### 25.2 File System Watcher

**Notes:** JacFileWatcher, watchdog integration, debouncing

### 25.3 Debug Mode

**Notes:** `jac debug` command

---

# Part V: AI Integration

## 26. Meaning Typed Programming

### 26.1 The Concept

**Notes:** Semantic intent as first-class type, declare "what" let AI provide "how"

### 26.2 Implicit vs Explicit Semantics

**Notes:** Function names/types vs `sem` descriptions

---

## 27. Semantic Strings

### 27.1 The `sem` Keyword

**Canonical syntax:**

```jac
sem classify_sentiment = """
Analyze emotional tone. Return 'positive', 'negative', or 'neutral'.
""";

def classify_sentiment(text: str) -> str by llm;
```

### 27.2 Parameter Semantics

**Notes:** sem func.param, sem func.return

### 27.3 Complex Semantic Types

**Notes:** Structured return types with semantic descriptions

---

## 28. The `by` Operator and LLM Delegation

### 28.1 Basic Usage

**Canonical syntax:**

```jac
def translate(text: str, lang: str) -> str by llm;

response = "Explain quantum computing" by llm;
```

### 28.2 Chained Transformations

**Notes:** Piping through multiple LLM transformations

### 28.3 Model Configuration

**Canonical syntax:**

```jac
def summarize(text: str) -> str by llm(
    model_name="gpt-4",
    temperature=0.7,
    max_tokens=2000
);
```

**Parameters Table:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `model_name` | str | LLM provider/model |
| `temperature` | float | Creativity (0.0-2.0) |
| `max_tokens` | int | Max response tokens |
| `stream` | bool | Enable streaming |
| `tools` | list | Functions for LLM |
| `method` | str | ReAct, Reason, Chain-of-Thoughts |
| `context` | list[str] | Additional instructions |

### 28.4 Tool Calling (ReAct)

**Canonical syntax:**

```jac
def get_weather(city: str) -> str { }
def search(query: str) -> list { }

def answer(question: str) -> str by llm(
    tools=[get_weather, search],
    method="ReAct"
);
```

**Notes:** ReAct loop explanation, max_react_iterations

### 28.5 Streaming Responses

**Notes:** `stream=True`, generator return, str type only

### 28.6 Multimodal Input

**Canonical syntax:**

```jac
import from byllm { Image, Video }

def describe(image: Image) -> str by llm;
def analyze(video: Video) -> str by llm;
```

**Notes:** Supported sources (paths, URLs, PIL, bytes, gs://)

### 28.7 Reasoning Methods

**Notes:** Chain-of-Thoughts, Reason, ReAct differences

### 28.8 Testing with MockLLM

**Canonical syntax:**

```jac
def classify(text: str) -> str by llm(
    model_name="mockllm",
    config={"outputs": ["positive", "negative"]}
);
```

### 28.9 Configuration via jac.toml

**Notes:** [plugins.byllm.model], [plugins.byllm.call_params], [plugins.byllm.litellm]

### 28.10 Python Library Mode

**Notes:** `@by(Model(...))` decorator for pure Python usage

---

## 29. Agentic AI Patterns

### 29.1 AI Agents as Walkers

**Notes:** Walkers with LLM-powered decision making

### 29.2 Tool-Using Agents

**Notes:** Walkers that use tools via ReAct

### 29.3 Multi-Agent Systems

**Notes:** Coordinating multiple walkers

---

# Part VI: Concurrency

## 30. Async/Await

### 30.1 Async Functions

**Canonical syntax:**

```jac
async def fetch(url: str) -> dict { }
await response.json();
```

### 30.2 Async Walkers

**Notes:** async walker, async can

### 30.3 Async For Loops

**Notes:** async for pattern

---

## 31. Concurrent Expressions (flow/wait)

### 31.1 flow Keyword

**Canonical syntax:**

```jac
future = flow slow_operation();
# Do other work
result = wait future;
```

### 31.2 Parallel Operations

**Notes:** Multiple flow/wait for parallelism

### 31.3 flow vs async

| Feature | async/await | flow/wait |
|---------|-------------|-----------|
| Model | Event loop | Thread pool |
| Best for | I/O-bound, many | CPU-bound, few |

---

# Part VII: Advanced Features

## 32. Error Handling

### 32.1 Try/Except/Finally

**Notes:** Standard exception handling

### 32.2 Raising Exceptions

**Notes:** raise, raise from

### 32.3 Assertions

**Notes:** assert with message

---

## 33. Testing

### 33.1 Test Blocks

**Canonical syntax:**

```jac
test addition_works {
    assert add(2, 3) == 5;
}
```

### 33.2 Testing Walkers

**Notes:** Graph setup, spawn, assert on reports

### 33.3 Float Comparison

**Notes:** almostEqual function

### 33.4 JacTestClient

**Notes:** In-memory API testing without ports:

- `JacTestClient.from_file()`
- `.get()`, `.post()`, `.put()`
- `.register_user()`, `.login()`
- Response assertions

### 33.5 Running Tests

**Notes:** `jac test`, --test-name, --xit, --verbose

---

## 34. Filter and Assign Comprehensions

### 34.1 Standard Comprehensions

**Notes:** List, dict, set, generator comprehensions

### 34.2 Filter Comprehension Syntax

**Canonical syntax:**

```jac
adults = people(?age >= 30);
high_scorers = people(?score > 80, active == True);
```

### 34.3 Assign Comprehension Syntax

**Canonical syntax:**

```jac
people(=score=100);                    # All get score=100
people(?age < 30)(=score=95);          # Chained filter+assign
```

---

## 35. Pipe Operators

### 35.1 Forward Pipe

**Notes:** `|>` left-to-right

### 35.2 Backward Pipe

**Notes:** `<|` right-to-left

### 35.3 Atomic Pipes

**Notes:** `:>` and `<:` for graph operations

---

# Part VIII: Ecosystem

## 36. CLI Reference

### 36.1 Execution Commands

| Command | Description |
|---------|-------------|
| `jac run <file>` | Execute program |
| `jac enter <file> <entry>` | Run named entry |
| `jac start [file]` | Start server |
| `jac debug <file>` | Debug mode |

### 36.2 Analysis Commands

| Command | Description |
|---------|-------------|
| `jac check` | Type check |
| `jac format` | Format code |
| `jac test` | Run tests |

### 36.3 Transform Commands

| Command | Description |
|---------|-------------|
| `jac py2jac` | Python → Jac |
| `jac jac2py` | Jac → Python |
| `jac js` | Jac → JavaScript |

### 36.4 Project Commands

| Command | Description |
|---------|-------------|
| `jac create` | New project |
| `jac install` | Install deps |
| `jac add` | Add dep |
| `jac remove` | Remove dep |
| `jac clean` | Clean artifacts |
| `jac script` | Run script |

### 36.5 JacPack Commands

**Notes:** `jac jacpack pack`, template creation, `jac create --use template`

### 36.6 Tool Commands

| Command | Description |
|---------|-------------|
| `jac dot` | Graph visualization |
| `jac lsp` | Language server |
| `jac config` | Configuration |
| `jac plugins` | Plugin management |

---

## 37. Plugin System

### 37.1 Available Plugins

| Plugin | Package | Description |
|--------|---------|-------------|
| byllm | `pip install byllm` | LLM integration |
| jac-client | `pip install jac-client` | Full-stack web |
| jac-scale | `pip install jac-scale` | Deployment |
| jac-super | `pip install jac-super` | Console output |

### 37.2 Managing Plugins

**Notes:** `jac plugins list/enable/disable/info`

### 37.3 Plugin Configuration

**Notes:** [plugins.X] in jac.toml

### 37.4 CLI Plugin Extension System

**Notes:** CommandSpec, HookContext, add_extension_arg, pre/post hooks, priority system (CORE, PLUGIN, USER)

---

## 38. Project Configuration

### 38.1 jac.toml Structure

**Notes:** [project], [dependencies], [dependencies.dev], [dependencies.npm], [plugins.X], [scripts], [environments.X]

### 38.2 Running Scripts

**Notes:** `jac script dev`

### 38.3 Environment Profiles

**Notes:** JAC_ENV variable

### 38.4 Environment Variables

**Notes:** Both server and client support environment variables via `.env` files

**Server Environment Variables:**

| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | OpenAI API key for byllm |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `REDIS_HOST`, `REDIS_PORT` | Redis connection |
| `MONGO_URI`, `MONGO_DB` | MongoDB connection |
| `JWT_SECRET` | JWT signing secret |
| `JWT_EXP_DELTA_DAYS` | Token expiration (default: 7) |

**Client Environment Variables:**

- Vite exposes variables prefixed with `VITE_` to client code
- Access via `import.meta.env.VITE_*`

**Notes:** `.env` files are loaded automatically; use `.env.local` for secrets not committed to git

---

## 39. Python Interoperability

### 39.1 Using Python Libraries

**Notes:** Direct import, numpy/pandas examples

### 39.2 Inline Python Blocks

**Canonical syntax:**

```jac
::py::
import numpy as np

def complex_calc(data):
    return np.array(data).mean()
::py::
```

**When to use:** Complex Python-only APIs, performance code, legacy integration
**When NOT to use:** Simple imports, new code, code needing Jac features

### 39.3 Type Compatibility

**Notes:** Jac-Python type mapping table

### 39.4 Using Jac from Python

**Notes:** jac_import() function

---

## 40. JavaScript/TypeScript Interoperability

### 40.1 npm Packages

**Notes:** React, query libraries, utility imports

### 40.2 TypeScript Support

**Notes:** [plugins.client] typescript=true

### 40.3 Browser APIs

**Notes:** window, localStorage, document, fetch

---

# Part IX: Deployment and Scaling

## 41. jac-scale Plugin

### 41.1 Overview

**Notes:** Production deployment with FastAPI, Redis, MongoDB, Kubernetes

### 41.2 Installation

**Notes:** `pip install jac-scale`, `jac plugins enable scale`

### 41.3 Basic Deployment

**Notes:** `jac start main.jac --port 8000` vs `jac start --scale`

### 41.4 Environment Configuration

**Notes:** REDIS_HOST, REDIS_PORT, MONGO_URI, MONGO_DB, K8S_NAMESPACE, K8S_REPLICAS

### 41.5 CORS Configuration

**Notes:** jac-scale includes CORS middleware for cross-origin requests

**Configuration (jac.toml):**

```toml
[plugins.scale.cors]
allow_origins = ["*"]  # Or specific domains
allow_methods = ["GET", "POST", "PUT", "DELETE"]
allow_headers = ["*"]
```

**Notes:** CORS is enabled by default for development; configure explicitly for production security

---

## 42. Kubernetes Deployment

### 42.1 Auto-Scaling

**Notes:** `jac start --scale`, auto-provisioning

### 42.2 Generated Resources

**Notes:** Deployment, Service, ConfigMap, StatefulSets

### 42.3 Health Checks

**Notes:** Liveness, readiness probes

---

## 43. Production Architecture

### 43.1 Multi-Layer Memory

**Notes:** Redis caching + MongoDB persistence

### 43.2 FastAPI Integration

**Notes:** Auto-generated endpoints, Swagger docs

### 43.3 Service Discovery

**Notes:** Kubernetes service mesh integration

---

# Appendices

## Appendix A: Complete Keyword Reference

**Notes:** Full table of all keywords with category and description

---

## Appendix B: Operator Quick Reference

**Notes:** Tables for arithmetic, comparison, graph, pipe operators

---

## Appendix C: Grammar Summary (BNF)

**Notes:** Key grammar rules in BNF notation

---

## Appendix D: Common Gotchas

**Notes:**

1. Semicolons required
2. Braces required for blocks
3. Type annotations required
4. `has` vs local variables
5. Walker `visit` is queued
6. `report` vs `return`
7. Global modification requires declaration

---

## Appendix E: Migration from Python

**Notes:** Syntax comparison tables, class migration, function migration

---

## Appendix F: LLM Provider Reference

| Provider | Models | Notes |
|----------|--------|-------|
| OpenAI | gpt-4, gpt-4o | Default |
| Anthropic | claude-3-opus | ANTHROPIC_API_KEY |
| Google | gemini-pro | GOOGLE_API_KEY |
| Azure | azure/gpt-4 | Azure config |
| Ollama | ollama/llama2 | Local |

**Notes:** Model name format, environment variables

---

## Appendix G: Breaking Changes

### G.1 jac build Command Removed

**Notes:** `jac build` and .jir files removed. Direct Python bytecode compilation.

### G.2 Migration Guide

**Notes:** How to migrate from older versions

---

## Document Information

**Jac Language Reference v3**
Last Updated: 2025

**Resources:**

- Website: https://jaseci.org
- Documentation: https://jac-lang.org
- GitHub: https://github.com/Jaseci-Labs/jaseci
- Discord: https://discord.gg/6j3QNdtcN6
