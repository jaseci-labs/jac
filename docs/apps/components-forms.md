---
description: Forms in a browser space's components - fields bound to state, event handlers and the event they take, submitting without reloading the page, handlers that await the server, and what each UI binding does with onChange.
keywords: form, forms, event handler, event handlers, onChange, onInput, onSubmit, onClick, preventDefault, checkbox, controlled input
---
# Forms and events

An **event handler** is a function given to an element's `on...` attribute (`onClick`, `onInput`,
`onSubmit`). The library calls it with the event when the event happens. A form's fields are
**controlled**: each shows a piece of state, and its handler assigns that state from the event.
State, handlers and the rest of a component are on [Components and JSX](components.md)
(`jac docs component`).

## A form

<!-- example: not checked: a page is a module of a browser space, with JSX -->
```jac
def:pub page -> JsxPage {
    has title: str = "";
    has urgent: bool = False;
    has size: str = "small";
    has items: list[str] = [];

    def add(e: any) {
        e.preventDefault();
        text = title.strip();
        if text == "" {
            return;
        }
        mark = "! " if urgent else "";
        items = items + [f"{mark}{text} ({size})"];
        title = "";
        urgent = False;
    }

    return <form onSubmit={add}>
        <input
            value={title}
            placeholder="something to do"
            onInput={lambda (e: any) { title = e.target.value; }}
        />
        <label>urgent <input
            type="checkbox"
            checked={urgent}
            onChange={lambda (e: any) { urgent = e.target.checked; }}
        /></label>
        <select value={size} onChange={lambda (e: any) { size = e.target.value; }}>
            <option value="small">small</option>
            <option value="large">large</option>
        </select>
        <button type="submit">add</button>
        <ul>{[<li key={n}>{item}</li> for (n, item) in enumerate(items)]}</ul>
    </form>;
}
```

Typing `buy milk` and pressing Enter (or clicking `add`) adds `buy milk (small)` to the list and
empties the field; the page does not reload. With `urgent` ticked and `large` chosen, `walk dog`
adds `! walk dog (large)`. The same body, as a component rendered from a Solid space's entry, does
the same.

| Field | Shows its state with | Handler | Reads |
|---|---|---|---|
| Text, `<input>` | `value={s}` | `onInput` | `e.target.value`, a `str` |
| Checkbox, `<input type="checkbox">` | `checked={b}` | `onChange` | `e.target.checked`, a `bool` |
| `<select>` | `value={s}` | `onChange` | `e.target.value`, the chosen option's `value` |
| `<form>` | | `onSubmit` | Call `e.preventDefault()` |

## Events

- **The event is `any`.** A handler's parameter is the library's event object, a JavaScript value:
  declare it `e: any`, and what is read from it (`e.target.value`) is looked up as the program
  runs. The browser's type names (`Event`, `SubmitEvent`) are accepted as annotations too, but only
  the name is checked, not what is read through it, and under React the object is React's event,
  not the browser's. A handler with no use for the event takes no parameter:
  `onClick={lambda { count = count + 1; }}`.
- **`e.preventDefault()` in `onSubmit`** stops the browser's own submission, which would load the
  page again and lose its state. Enter in a field of a form with a submit button submits it, as the
  button does.
- **Use `onInput` for a text field.** Attributes are passed to the library as written, and the
  libraries differ on `onChange`: under React (the default) it runs at each key, as `onInput` does; under Solid it
  is the browser's `change`, which runs only when the field is left or the form submitted.
  `onInput` runs at each key under both.

## Handlers that await

A handler that calls the server is an `async def`, given to the attribute as it is. The code before
its first `await` runs while the browser is still handling the event, so `e.preventDefault()` goes
first: after an `await` it is too late, and the browser has already submitted the form and reloaded
the page. Here `add_item`, `list_items` and `mark_done` are functions of a server space, wired into
the page with `Item` (`obj Item { has id: str; has title: str; has done: bool = False; }`, in a
module both sides share; see [Crossings](crossings.md)):

<!-- example: not checked: a page is a module of a browser space, with JSX and crossings -->
```jac
import from "@jac/runtime" { RemoteError }

def:pub page -> JsxPage {
    has items: list[Item] = [];
    has draft: str = "";
    has problem: str = "";

    async can with entry {
        items = await list_items();
    }

    async def submit(e: any) {
        e.preventDefault();
        title = draft.strip();
        if title == "" {
            return;
        }
        try {
            added: Item = await add_item(title);
            items = items + [added];
            draft = "";
        } except RemoteError as err {
            problem = err.detail;
        }
    }

    async def finish(id: str) {
        await mark_done(id);
        items = await list_items();
    }

    return <main>
        <form onSubmit={submit}>
            <input value={draft} onInput={lambda (e: any) { draft = e.target.value; }} />
            <button type="submit">add</button>
        </form>
        <p>{problem}</p>
        <ul>
            {[
                <li key={it.id}>
                    {it.title}
                    <button disabled={it.done} onClick={lambda { finish(it.id) }}>done</button>
                </li>
                for it in items
            ]}
        </ul>
    </main>;
}
```

Adding `buy milk` and `walk dog` lists both, and `done` on the first disables its button. With the
server stopped, a submit shows `TypeError: Failed to fetch` under the form and leaves the text in the
field.

- **`onClick={lambda { finish(it.id) }}`** gives an async handler an argument. A lambda whose body
  is one expression has that expression as its value, so the lambda gives back `finish`'s
  coroutine, and the library runs it as it runs an `async def` handler.
- **A coroutine made and dropped is E1278**, in a handler as anywhere: `lambda { finish(it.id); }`,
  `lambda { finish(it.id); n = 1; }` and a `def` handler whose statement is `finish(it.id);` are
  refused. Write an `async def` that awaits the call.
- **An exception a handler raises**, async or not, is reported in the browser's console as an
  uncaught error, and the page goes on. Catch what the user should see: a call to the server that
  fails raises a `RemoteError` ([Crossings](crossings.md#how-a-crossing-fails)), whose `detail` here,
  with the server stopped, is `TypeError: Failed to fetch`.

## What goes wrong

| Symptom | Cause | Fix |
|---|---|---|
| The page reloads on submit, and its state is lost | No `e.preventDefault()`, or one after an `await` | Call it first in the `onSubmit` handler |
| Under Solid, the state follows a text field only when the field is left | `onChange` on the field | `onInput` |
| E1278 | A handler calls an `async def` and drops its coroutine | Await it in an `async def` handler |
| E1217 | A handler changes state in place (`items.append(x)`) | Assign a new value: `items = items + [x]` |
| An error in the browser's console, nothing on the page | A handler raised | Catch it in the handler and set state that shows it |
