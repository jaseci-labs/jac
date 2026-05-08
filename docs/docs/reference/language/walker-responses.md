# Walker Response Patterns

Walkers traverse a graph, visiting nodes and executing logic at each step. But how do you get data *out* of a walker after it finishes? That's what the `report` statement is for -- it's the primary mechanism for walkers to communicate results back to the code that spawned them.

This reference covers the `report` mechanism and the common patterns for structuring walker responses. Choosing the right pattern matters because it affects how your client code (whether a `with entry` block, an API endpoint, or another walker) consumes the results.

> **Related:**
>
> - [Graph Operations](osp.md) - Node creation, traversal, and deletion
> - [Part III: OSP](osp.md) - Walker and node fundamentals
> - [Build an AI Day Planner](../../tutorials/first-app/build-ai-day-planner.md) - Full tutorial using these patterns

---

## The `.reports` Array

Every time a walker executes a `report` statement, the value is appended to a `.reports` array on the response object. When you spawn a walker with `root spawn MyWalker()`, the returned object contains this array, giving you access to everything the walker reported during its traversal. Think of `report` as the walker's "return channel" -- except that a walker can report multiple times as it moves through the graph, accumulating results along the way.

!!! note
    The `report` statement also prints each reported value to stdout as a side effect. This means you will see the reported values printed to the console in addition to them being collected in `.reports`.

```jac
walker:priv MyWalker {
    can do_work with Root entry {
        report "first";   # reports[0]
        report "second";  # reports[1]
    }
}

with entry {
    # Spawning the walker
    response = root spawn MyWalker();
    print(response.reports);  # ["first", "second"]
}
```

### Typing Your Reports

**Declare `has reports: list[T]` on every walker.** It is the recommended default, not an opt-in optimization. The declaration is a single-source-of-truth contract: `report X` on the write side and `(spawn W).reports[i]` on the read side both type-check against the same `T`, so a typo or shape drift surfaces at `jac check` time instead of at the call site.

A bare walker assumes `reports: list[any]`. That works, but it propagates `any` into consumer code -- and Jac's [strict gradual-typing rule](foundation.md#the-any-type-and-gradual-typing) will reject the consumer's typed assignment downstream. Typing `reports` at the source is almost always cheaper than annotating every receiving local as `any` and narrowing back.

#### Pattern A: Single typed report (most walkers)

The common case. The walker accumulates results internally and reports once at the end, or mutates state and reports the touched node.

```jac
node Task {
    has title: str;
    has done: bool = False;
}

walker:priv ToggleTask {
    has task_id: str,
        reports: list[Task] = [];   # typed report channel

    can search with Root entry {
        visit [-->];
    }

    can toggle with Task entry {
        if jid(here) == self.task_id {
            here.done = not here.done;
            report here;        # `here` is Task -- type-checked against list[Task]
            disengage;
        }
    }
}

with entry {
    result = root spawn ToggleTask(task_id="abc123");
    toggled: Task = result.reports[0];     # hydrated as Task on the consumer side
}
```

Note that `has reports: list[Task] = [];` sits alongside the walker's other `has` declarations -- it is just another field with a default initializer, declared the same way as `task_id`.

#### Pattern B: Single accumulated list (collection walkers)

When the walker reports a *collection* once at exit, the element type is itself a list. The shape becomes `list[list[T]]` -- one outer slot for the single `report` call, one inner element type for each item in the reported list.

```jac
walker ListTasks {
    has reports: list[list[Task]];

    can collect with Root entry {
        report [-->][?:Task];
    }
}

with entry {
    result = root spawn ListTasks();
    tasks: list[Task] = result.reports[0];   # type-safe single-shot collection
}
```

#### How the type checker enforces the declaration

When `has reports` is declared, two rules are checked:

1. The declaration itself must be a list type. `has reports: int = 0;` is rejected -- `reports` is the walker's report channel, not arbitrary state, so it must be `list[T]` for some `T`.
2. Every `report` statement in the walker body must produce a value compatible with the element type `T`. If you `report "oops"` inside `ListTasks` above, the checker flags it as a type error.

If you omit the declaration, the walker falls back to `reports: list[any]` and any value can be reported -- but downstream code that receives those values into typed destinations will hit Jac's strict-`any` rule. See [The `any` Type and Gradual Typing](foundation.md#the-any-type-and-gradual-typing) for the consumer side.

## Common Patterns

### Pattern 1: Single Report (Recommended)

The cleanest pattern accumulates data internally and reports once at the end:

```jac
node Item {
    has data: str;
}

walker:priv ListItems {
    has reports: list[list[str]];
    has items: list[str] = [];

    can collect with Root entry {
        visit [-->];
    }

    can gather with Item entry {
        self.items.append(here.data);
    }

    can finish with Root exit {
        report self.items;  # Single report with all data (type-checked)
    }
}

with entry {
    # Usage
    result = root spawn ListItems();
    items = result.reports[0];  # The complete list
}
```

**When to use:** Most read operations, listing data, aggregations.

This is the **accumulator pattern** -- the standard approach for collecting data from a graph traversal. The walker flows through three stages:

1. **Enter root** → initiate traversal with `visit [-->]`
2. **Visit each node** → gather data into walker state (`self.items`)
3. **Exit root** → report the accumulated result

The `with Root exit` ability fires after the walker has finished visiting all queued nodes and returns to root, making it the ideal place for a single consolidated report.

!!! tip "Accumulator in Frontend"
    When calling this pattern from client code, access the result with `result.reports[0]` -- there is always exactly one report containing the full collection.

For a complete walkthrough of this pattern in a full-stack app, see [Build an AI Day Planner](../../tutorials/first-app/build-ai-day-planner.md).

### Pattern 2: Report Per Node

Reports each item as it's found during traversal:

```jac
node Item {
    has name: str;
}

walker:priv FindMatches {
    has search_term: str,
        reports: list[Item] = [];   # one Item per match

    can search with Root entry {
        visit [-->];
    }

    can check with Item entry {
        if self.search_term in here.name {
            report here;  # `here` is Item -- type-checked against list[Item]
        }
    }
}

with entry {
    # Usage
    result = root spawn FindMatches(search_term="test");
    matches: list[Item] = result.reports;  # typed end-to-end
}
```

**When to use:** Search operations, filtering, finding specific nodes.

### Pattern 3: Operation + Result

Performs an operation and reports a summary:

```jac
node Item {
    has name: str;
}

walker:priv CreateItem {
    has name: str,
        reports: list[Item] = [];   # the created Item flows back typed

    can create with Root entry {
        new_item = here ++> Item(name=self.name);
        report new_item[0];  # Report the created item
    }
}

with entry {
    # Usage
    result = root spawn CreateItem(name="New Item");
    created: Item = result.reports[0];  # hydrated as Item on the client
}
```

**When to use:** Create, update, delete operations.

### Pattern 4: Nested Walker Spawning

When one walker spawns another, use `has` attributes to pass data between them instead of relying on `reports`:

```jac
walker:priv InnerWalker {
    has result: str = "";

    can work with Root entry {
        self.result = "inner data";
    }
}

walker:priv OuterWalker {
    can work with Root entry {
        # Spawn inner walker
        inner = InnerWalker();
        root spawn inner;

        # Access inner walker's data via its attributes
        report {"outer": "data", "inner": inner.result};
    }
}

with entry {
    # Usage
    result = root spawn OuterWalker();
    # result.reports[0] = {"outer": "data", "inner": "inner data"}
}
```

**Important:** When spawning walkers from within other walkers, the inner walker's `reports` list may not be accessible from the parent context. Use `has` attributes on the inner walker to communicate results back to the outer walker.

### Pattern 5: Multiple Reports (Complex Operations)

Some operations naturally produce multiple reports:

```jac
def do_processing(input: str) -> list {
    return [input, input + "_processed"];
}

walker:priv ProcessAndSummarize {
    has input: str;

    can process with Root entry {
        # First report: raw results
        results = do_processing(self.input);
        report results;

        # Second report: summary
        report {
            "count": len(results),
            "status": "complete"
        };
    }
}

with entry {
    # Usage
    result = root spawn ProcessAndSummarize(input="data");
    raw_results = result.reports[0];  # First report
    summary = result.reports[1];       # Second report
}
```

**When to use:** Operations that produce both detailed results and summaries.

## Safe Access Patterns

Always handle the possibility of empty reports:

```jac
walker:priv MyWalker {
    can work with Root entry {
        report "data";
    }
}

def process(item: any) {
    print(item);
}

with entry {
    # Safe single report access
    result = root spawn MyWalker();
    data = result.reports[0] if result.reports else None;

    # Safe with default value
    data = result.reports[0] if result.reports else [];

    # Check length for multiple reports
    if result.reports and len(result.reports) > 1 {
        first = result.reports[0];
        second = result.reports[1];
    }

    # Iterate all reports
    for item in (result.reports if result.reports else []) {
        process(item);
    }
}
```

## Response Object Structure

The full response object from `root spawn Walker()`:

```jac
walker:priv MyWalker {
    can work with Root entry {
        report "result";
    }
}

with entry {
    response = root spawn MyWalker();

    # Available properties
    print(response.reports);    # Array of all reported values
}
```

## Best Practices

1. **Always declare `has reports: list[T]`** - The default `list[any]` propagates `any` into consumer code, and Jac's strict gradual-typing rule rejects `any` flowing into typed destinations. Typing the report channel at the walker is almost always cheaper than annotating every receiving local as `any` and narrowing back. See [The `any` Type and Gradual Typing](foundation.md#the-any-type-and-gradual-typing).
2. **Prefer single reports** - Accumulate data and report once at the end
3. **Use `with Root exit`** - Best place for final reports after traversal
4. **Report typed objects directly** - Return node/obj instances instead of manually constructing dicts. The runtime automatically serializes typed objects with field metadata, and client code receives them as hydrated typed instances with proper field access (e.g., `task.title` instead of `task["title"]`)
5. **Always check `.reports`** - It may be empty or undefined
6. **Use typed return annotations** - For `def:pub` functions, annotate with `-> Task` or `-> list[Task]` instead of `-> dict` or `-> list` to enable automatic type hydration on the client

## Anti-Patterns

### Don't: Manually construct dicts from typed objects

```jac
# Bad: Manual dict construction loses type information
walker:priv BadCreate {
    has name: str;

    can create with Root entry {
        item = here ++> Item(name=self.name);
        report {"name": item[0].name, "data": item[0].data};  # Don't do this
    }
}

# Good: Report the typed object directly
walker:priv GoodCreate {
    has name: str;

    can create with Root entry {
        item = here ++> Item(name=self.name);
        report item[0];  # The runtime handles serialization automatically
    }
}
```

The same applies to `def:pub` functions -- return typed objects instead of manually constructed dicts:

```jac
# Bad: Manual dict return
def:pub get_task(id: str) -> dict {
    task = find_task(id);
    return {"id": jid(task), "title": task.title, "done": task.done};
}

# Good: Typed return -- client receives a hydrated Task instance
def:pub get_task(id: str) -> Task {
    return find_task(id);
}
```

### Don't: Report in a loop without accumulation

```jac
node Item {
    has data: str;
}

# Bad: Creates many small reports
walker:priv BadPattern {
    can process with Item entry {
        report here.data;  # N reports for N items
    }
}

# Good: Accumulate and report once
walker:priv GoodPattern {
    has items: list = [];

    can start with Root entry {
        visit [-->];
    }

    can process with Item entry {
        self.items.append(here.data);
    }

    can finish with Root exit {
        report self.items;  # One report with all items
    }
}
```

### Don't: Assume report order without documentation

```jac
walker:priv MyWalker {
    can work with Root entry {
        report ["item1", "item2"];
        report {"count": 2};
    }
}

with entry {
    result = root spawn MyWalker();

    # Bad: Magic indices
    data = result.reports[0];
    meta = result.reports[1];

    # Good: Document or structure clearly
    # reports[0]: List of items
    # reports[1]: Metadata object
    data = result.reports[0] if result.reports else [];
    meta = result.reports[1] if len(result.reports) > 1 else {};
}
```
