---
description: Components in a browser or hermes space - JSX in Jac, props as keyword arguments, state with has, derived values, effects, refs, hooks, and the rules that keep a component's meaning the same under every UI library.
keywords: component, components, jsx, JSX, JsxElement, Ref, state, effect, effects, hook, props, children, key, new
grammar: jsx_element, jsx_children, jsx_child, jsx_tag_name, jsx_attributes
---
# Components and JSX

A component is a function that returns a `JsxElement`: what part of a page shows, computed from
its parameters (its **props**) and its own **state**. Components are written in the modules of a
`browser` or `hermes` space, and of a module no space holds that such a space imports
([the archwire](archwire.md)).

The language says what a component means; a space's **`ui` plugin** says which library it becomes
(React by default in a browser, React Native on hermes;
[UI plugins and bundlers](ui-bindings.md), `jac docs apps/ui-bindings`). The same component
means the same under each.

JSX is an expression of a JavaScript host only. In a native program `JsxElement` is not a type
(E2018).

## A component

<!-- example: not checked: a component is a module of a browser space, with JSX -->
```jac
def Counter(step: int = 1, label: str = "count") -> JsxElement {
    has count: int = 0;

    doubled = count * 2;

    can with [count] entry {
        document.title = f"{label}: {count}";
    }

    return <button onClick={lambda { count = count + step; }}>{label}: {count} (doubled {doubled})
    </button>;
}
```

`<Counter step={5} />` shows a button reading `count: 0 (doubled 0)`; each click adds 5 to
`count`, the text follows, and the page's title says the count.

- `has count: int = 0;` is state: a value the component keeps between the times it is shown.
- `doubled` is derived from it, and stays current.
- `can with [count] entry` is an effect: code that runs after the component has shown, and again
  whenever `count` changes.
- The `return` is what it shows.

## JSX

```ebnf
jsx_element ::=
    "<>" jsx_children "</>"
    | JSX_OPEN ("@" ("{" expression "}" | JSX_NAME ("." JSX_NAME)*) | jsx_tag_name) jsx_attributes ("/>" | JSX_TAG_END jsx_children "</" ("@" ("{" expression "}" | jsx_tag_name) | jsx_tag_name) JSX_TAG_END)

jsx_children ::= (jsx_child | JSX_TEXT)*

jsx_tag_name ::= JSX_NAME ("." JSX_NAME)*

jsx_attributes ::= (JSX_NAME ("=" ("{" expression "}" | STRING)?)? | "{" ("**" | "...")? expression "}")*

jsx_child ::=
    JSX_TEXT
    | JSX_COMMENT
    | "{" (stmts "}" | expression (";" stmts "}" | "}"))
    | jsx_element
```

A JSX element is an expression of type `JsxElement`, written wherever an expression may be.

| Form | Means |
|---|---|
| `<p>text</p>`, `<input />` | An element of the host, by a lowercase name |
| `<Counter step={5} />` | A component: a function in scope, by its name |
| `<@Tag label="x" />`, `<@{expr}>...</@{expr}>` | An element whose tag is a value: a component held in a variable, or a host element's name as a `str` (`tag = "em"; <@tag>text</@tag>`). It may stand wherever an element may, as a child too |
| `<>...</>` | A fragment: its children, with no element around them |
| `name="text"` | An attribute whose value is a string |
| `name={expr}` | An attribute whose value is an expression |
| `name` alone | The attribute `True` (`<input readOnly />`) |
| `{name}` | Short for `name={name}` |
| `{...props}` | Every entry of a dict as an attribute (`{**props}` is the same; `jac fmt` writes `...`) |
| `{expr}` as a child | The value: text, a number, an element, a list of elements, or `None` for nothing |
| `{#* note *#}` as a child | A comment, which shows nothing |
| Text as a child | JSX's text: a character reference is the character it names (`Tom &amp; Jerry` shows `Tom & Jerry`), and a `>` is text |
| `{for ... { ... }}` as a child | A block of statements: each element written as a statement in it is a child, in order |

Attribute names are passed to the library as written: under React, `className`, `onClick`,
`readOnly`.

<!-- example: not checked: a component is a module of a browser space, with JSX -->
```jac
def Badge(label: str, tone: str = "info") -> JsxElement {
    return <span className={"badge " + tone}>{label}</span>;
}

def Panel(title: str, children: any) -> JsxElement {
    return <section><h2>{title}</h2>{children}</section>;
}

def:pub page -> JsxPage {
    items = ["a", "b", "c"];
    label = "shorthand";
    extra = {"tone": "warn"};
    return <>
        <Panel title="forms">
            {#* a comment, which renders nothing *#}
            <Badge label="plain" />
            <Badge {label} />
            <Badge label="spread" {...extra} />
            <input disabled />
        </Panel>
        <ul>{[<li key={x}>{x}</li> for x in items]}</ul>
        <ol>
            {
                for x in items {
                    if x != "b" {
                        <li key={x}>{x}</li>
                    }
                }
            }
        </ol>
        {<b>yes</b> if len(items) > 2 else <i>no</i>}
    </>;
}
```

renders:

```html
<section><h2>forms</h2><span class="badge info">plain</span><span class="badge info">shorthand</span><span class="badge warn">spread</span><input disabled=""></section><ul><li>a</li><li>b</li><li>c</li></ul><ol><li>a</li><li>c</li></ol><b>yes</b>
```

### Props

A component's parameters are its props, and its attributes are passed as keyword arguments, so a
tag is checked as a call is:

| Mistake | Code |
|---|---|
| `<Badge label={3} />` with `label: str` | E1053 (`Badge()'s parameter 'label' expects str, found int`) |
| `<Badge name="x" />` | E1052 (`Badge() takes no keyword argument 'name'`) |
| `<Badge />` | E1050 (`Badge() is missing 1 required keyword argument: 'label'`) |
| `<Row onPick={save} />`, `save` an `async def`, with `onPick: Callable[[int], None]` | E1053 (`Row()'s parameter 'onPick' expects Callable[[int], None], found Callable[[int], Coroutine[any, any, None]]`): a function that makes a coroutine is not one that gives nothing, whose caller would drop the coroutine |

What is written between a component's tags is its `children` parameter.

Props keep their Jac types: a `dict` passed as a prop is a `dict` in the component, not a
JavaScript object. A function passed as a prop is one JavaScript can call too (a library that
calls what it finds on an element calls it), and an `async` one passed where
`Callable[[str], Coroutine[any, any, None]]` is declared runs its coroutine when called.

A `**` parameter collects the props no other parameter takes, as a dict, and `{...rest}` spreads
it on to an element:

<!-- example: not checked: a component is a module of a browser space, with JSX -->
```jac
def Row(label: str, **rest: any) -> JsxElement {
    return <li {...rest}>{label}</li>;
}

def:pub page -> JsxPage {
    return <ul><Row label="first" className="pick" title="the first row" /></ul>;
}
```

renders `<ul><li class="pick" title="the first row">first</li></ul>`.

### Lists and keys

A list of elements is shown in order. Give each a `key` that names its row
(`<li key={x}>`), so that the library keeps each row's state with its row when the list changes.
`key` is the language's and never a prop or an attribute of the element: a rerender library is
given it, and a fine-grained one, whose keyed list keeps each row by the item it shows, is not
([UI plugins and bundlers](ui-bindings.md#what-each-model-does-with-a-component)).

## State

`has` in a function's body declares state:

<!-- example: not checked: a component is a module of a browser space, with JSX -->
```jac
def:pub page -> JsxPage {
    has items: list[str] = [];

    return <div>
        <button onClick={lambda { items = items + ["x" + str(len(items))]; }}>add</button>
        <ul>{[<li key={x}>{x}</li> for x in items]}</ul>
    </div>;
}
```

- **Its initial value** is evaluated the first time the component is shown.
- **Assigning it** (`items = ...`) changes it, and the component shows the new value.
- **Changing it in place** (`items.append(x)`, `d[k] = v`, `obj.field = v`) is E1217: nothing sees
  such a change. Assign a new value instead: `items = items + [x]`.
- **It belongs at the top of the body.** `has` inside an `if`, a loop or another block is E1215.
- A function made in the component (a `lambda`, or a `def` in its body or in one of its effects)
  sees the state of the time the component was last shown, whenever it is called: an event
  handler (`lambda { ... }`, or a function of the component passed as `onClick={f}`), and a
  callback an effect handed to a timer long before. An `async def` in the component may be a
  handler; what it assigns after an `await` is shown when it assigns it.

## Derived values

A local computed from state or props, `doubled = count * 2;`, stays current: it is the value for
the state the component shows. A component's body is setup and derivations; it cannot depend on
how many times it runs. So the only statements its body may hold are:

- `has`, effects (`can with ...`) and a final `return`;
- assignments;
- calls of hooks (below), and calls of functions of the packages its `ui` plugin owns.

Any other statement, `print("rendering");` for one, is E1216: move it into an effect.

## Effects

An ability in a component's body is an effect: code that runs after the component has shown, never
while it is being worked out.

| Form | Runs |
|---|---|
| `can with entry { ... }` | Once, after the component is first shown |
| `can with [a, b] entry { ... }` | After it is first shown, and after each time `a` or `b` changes |
| `can with exit { ... }` | When the component is removed |
| `can with [a] exit { ... }` | Before the `[a]` entry runs again, and when the component is removed |
| `async can with entry { ... }` | As `can with entry`, its body a coroutine that may `await` |

The list says what the effect depends on, and must name every piece of state the effect's body
reads: an effect reading state its list leaves out is E1225. A function the effect makes
(a timer's callback) is not its body: it reads the state as last shown when it is called, and
what it reads is not listed.

<!-- example: not checked: a component is a module of a browser space, with JSX -->
```jac
def Watch(n: int) -> JsxElement {
    can with [n] entry {
        print("start", n);
    }

    can with [n] exit {
        print("stop", n);
    }

    return <p>watching {n}</p>;
}
```

Shown with `n` 0, then changed to 1, then removed, it prints (to the browser's console):

```text
start 0
stop 0
start 1
stop 1
```

An exit sees the values it had when its entry last ran.

An effect's own body reads the state the component showed when the effect ran. A function the
effect makes is called later, and reads the state as last shown then, so a timer started once
counts on, under every `ui` plugin:

<!-- example: not checked: a component is a module of a browser space, with JSX -->
```jac
def Clock -> JsxElement {
    has ticks: int = 0;
    has timer: Ref[any] = Ref(None);

    can with entry {
        timer.current = setInterval(lambda { ticks = ticks + 1; }, 100);
    }

    can with exit {
        clearInterval(timer.current);
    }

    return <p>ticks {ticks}</p>;
}
```

## Refs

A `Ref[T]` holds a value across the times a component is shown without being state: changing
`.current` shows nothing new. Declare it with `has`:

<!-- example: not checked: a component is a module of a browser space, with JSX -->
```jac
def:pub page -> JsxPage {
    has count: int = 0;
    has runs: Ref[int] = Ref(0);

    can with [count] entry {
        runs.current = runs.current + 1;
        print("count is", count, "effect runs", runs.current);
    }

    return <button onClick={lambda { count = count + 1; }}>{count}</button>;
}
```

What a ref holds is dynamic (`current` is an `any`).

## Hooks

A function that holds state (`has`) and does not return a `JsxElement` is a **hook**: state a
component borrows. It returns a typed object built with keywords, whose fields stay current where
the component reads them:

<!-- example: not checked: a component is a module of a browser space, with JSX -->
```jac
obj Tally {
    has total: int,
        bump: Callable[[int], None];
}

def use_tally(start: int) -> Tally {
    has total: int = start;

    return Tally(total=total, bump=lambda (n: int) { total = total + n; });
}

def:pub page -> JsxPage {
    tally = use_tally(10);

    return <button onClick={lambda { tally.bump(5) }}>tally {tally.total}</button>;
}
```

The button reads `tally 10`, then `tally 15` after a click. A hook is called in a component's body,
as an assignment or a statement of its own.

## Forms and events

A form's fields are state that each field shows and its event handler assigns: `value={title}`
with `onInput={lambda (e: any) { title = e.target.value; }}`, and `onSubmit` with
`e.preventDefault()`. [Forms and events](components-forms.md) (`jac docs form`) has a complete
form, the event's type, and handlers that await the server.

## Calling JavaScript

The host's globals are typed from its declarations: `document`, `window`, `setTimeout`,
`console`. A name that is neither the program's nor a declared global (`windw.alert(n)`) is W2001,
reported as an error ([Pages](pages.md#npm-packages-and-style-sheets)). `new(cls, *args)` is JavaScript's `new`: `new(Date, 86400000).toISOString()` gives
`"1970-01-02T00:00:00.000Z"`. An npm package's functions are imported by its name in a string
([Pages](pages.md#npm-packages-and-style-sheets)).

`print` writes to the browser's console.

## Rules a ui plugin adds

A fine-grained library (Solid) runs a component's body once and updates only what changed, so
under such a `ui` plugin a body must also say outright which locals follow state:

| Under a fine-grained `ui` plugin | Code |
|---|---|
| A `return` before the end of the body, or inside a block | E1222 |
| A block (an `if`, a loop) that reads state or props | E1222 |
| A local that follows state assigned more than once, or a prop assigned | E1224 |
| A hook whose last statement is not `return T(field=..., ...)` | E1223 |

Write such code as one expression instead: `return <p>big</p> if count > 3 else <p>{count}</p>;`.
Code that keeps these rules runs the same under every `ui` plugin.

React Native has no lowercase elements and shows no bare text in a `View`:

| Under `react_native` | Code |
|---|---|
| `<div>` or another lowercase tag | E1221 |
| Text directly inside `<View>`, `<ScrollView>` or `<Pressable>` | E1220: put it in a `<Text>` |

Under the `none` plugin, `has` and effects in a function are E1218: the library's own functions
are used instead ([UI plugins and bundlers](ui-bindings.md)).

## What is rejected

Each of these is reported by `jac check --space <space>` and by the build, with its file and
line:

```text
pages/index.jac:4:38: error[E1217]: 'items' is state, and append changes it in place without anyone seeing: assign a new value
```

| Code | Cause |
|---|---|
| E1215 | `has` inside a block of a function |
| E1216 | A statement in a component's body other than setup and derivations |
| E1217 | State changed in place |
| E1218 | `has` or an effect under the `none` plugin |
| E1220 | Text directly in an element that shows none (React Native) |
| E1221 | A lowercase tag under a `ui` plugin with none (React Native) |
| E1222 | A `return` before the end, or a block reading state, under a fine-grained `ui` plugin |
| E1223 | A hook not returning a typed object built with keywords, under a fine-grained `ui` plugin |
| E1224 | A local following state assigned twice, or a prop assigned, under a fine-grained `ui` plugin |
| E1225 | An effect reading state its list does not name |
| E1050, E1052, E1053 | A component's tag missing a prop, with an unknown one, or with one of the wrong type |
| E2018 | `JsxElement` in a native program |

## Where it differs from React

- In React a component calls `useState`, `useEffect` and `useRef`; here it writes `has`,
  `can with [deps] entry` and `has r: Ref[T]`, and the space's `ui` plugin chooses the functions. The same
  source runs under Solid, where the body runs once.
- A state change is an assignment, never a setter call, and changing state in place is a compile
  error rather than a change nothing shows.
- An effect's dependency list is checked against what its body reads (E1225).
