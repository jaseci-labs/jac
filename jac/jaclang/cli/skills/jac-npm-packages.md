---
name: jac-npm-packages
description: Install and consume npm libraries in client Jac, including refs and hooks. Use for third-party client imports; packaging covers publishing.
---

> **jac-shadcn projects** (has `[jac-shadcn]` in jac.toml): the template ships only `clsx`, `tailwind-merge`, and `tw-animate-css` in `[dependencies.npm]`. Each shadcn component's own peer deps (radix-ui, etc.) are added automatically when you run `jac install --shadcn <component>` - don't add those by hand. Any *other* npm package (charts, icons, ...) you still add yourself, as below.

## Adding npm Packages

Declare all packages in `jac.toml` before running `jac install` (or use `jac install --npm <pkg>` / `jac install --npm --dev <pkg>`, which patches jac.toml for you):

- Regular deps: `[dependencies.npm]`
- Dev deps (build tools): `[dependencies.npm.dev]`

```toml
[dependencies.npm]
"sonner" = "^2.0.0"
"recharts" = "^2.10.0"
"@monaco-editor/react" = "^4.7.0"
"@hugeicons/react" = "*"
"@hugeicons/core-free-icons" = "*"
"lucide-react" = "*"
"radix-ui" = "^1.6.7"
"class-variance-authority" = "^0.7.1"
```

## Import Syntax

Package names in **double quotes**. Named imports only:

```jac
import from "sonner" { toast as sonnerToast, Toaster }
import from "recharts" { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip }
import from "@monaco-editor/react" { Editor }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { File02Icon, Cancel01Icon }
import from "lucide-react" { Search, X, Menu, ChevronDown }
import from "radix-ui" { Dialog as DialogPrimitive }
```

## Refs: `Ref[T]` fields (NOT `useRef(None)`)

Just as `has x: int = 0` is `useState`, a `has` field typed `Ref[T]` is a **ref** - a mutable container that survives re-renders without triggering one. Do NOT import `useRef` for this; the field form is the idiom:

```jac
def:pub TextInput() -> JsxElement {
    has inputRef: Ref[HTMLInputElement] = Ref();   # -> const inputRef = useRef(null)

    def handle_click(e: MouseEvent) {
        if inputRef.current { inputRef.current.focus(); }
    }
    <div>
        <input ref={inputRef} type="text" />
        <button onClick={handle_click}>Focus</button>
    </div>
}
```

- `= Ref()` → `useRef(null)`, an empty DOM ref; wire with `ref={inputRef}` and React fills `.current` on mount.
- `= Ref(initial)` → `useRef(initial)`, a value ref for mutable data that shouldn't re-render (timers, flags, last-seen values).
- `useRef` is **auto-imported** - never import it yourself.
- `.current` is typed `T | None` - null-check before use (`if r.current { ... }`).
- The field must be constructed: a bare `has r: Ref[T];` with no `= Ref()` is rejected (E2025).
- The old `inputRef: any = useRef(None)` pattern still runs but loses typing - replace it with a `Ref[T]` field.

## Ref forwarding (parents pointing refs at YOUR component)

**`ref` is an ordinary prop.** The client runtime is React 19, so a compiled component receives `ref` in its props like any other. The compiler never threads it onto an element for you - a ref reaches a DOM node only where you write `ref=` or spread a bundle that still carries it.

**Props-bundle component (a single `props` param) - already receives it.** `props["ref"]` is set; spread the bundle (or a rest copy that does not exclude `ref`) onto the host tag:

```jac
# jac:ignore[W5015]
def:pub FancyInput(props: dict) -> JsxElement {
    <input className="fancy" {**props} />
}
```

This is the shape every installed `components/ui/` primitive uses, and it is why they work as radix `asChild` anchors with no ref plumbing of their own. A `props` bundle emits **W5015** (`jac-cl-components` tells you to default to named params for that reason) - being a ref target is the intentional forwarding that warning leaves room for, so `# jac:ignore[W5015]` is expected on these and only these.

**Named-param component - declare a trailing `Ref` param.** Named params destructure only what they declare, so `ref` is not among them. A trailing parameter typed `Ref` lowers to React's `forwardRef((props, ref) => ...)`:

```jac
def:pub FancyLabel(text: str, ref: Ref[HTMLElement] = Ref()) -> JsxElement {
    <span ref={ref} className="fancy">{text}</span>
}

# Parent: both shapes are pointed at the same way from the call site
def:pub ParentForm() -> JsxElement {
    has inputRef: Ref[HTMLInputElement] = Ref();
    has labelRef: Ref[HTMLElement] = Ref();
    <div>
        <FancyInput ref={inputRef} placeholder="Type here" />
        <FancyLabel ref={labelRef} text="Hello" />
    </div>
}
```

- Only the **last** parameter qualifies, and it must be typed `Ref` / `Ref[T]` - the lowering keys on the type alone, so a `= Ref()` default changes nothing at runtime but keeps `jac check` happy at call sites that pass `ref=` as a JSX attribute. Params before it stay normal named props; `ref` is never folded into the props bundle. `forwardRef` is auto-imported.
- **This is what makes a component usable as a radix `asChild` trigger child** (`DropdownMenuTrigger`, `Popover.Trigger`, ...) - the trigger attaches a positioning-anchor ref to its child. A child that lands the ref nowhere leaves that anchor null, and the popper positions at the viewport origin instead of at the trigger. Nothing warns about it. See `jac-shadcn-components`.
- Known `jac check` false positive (build + runtime verified correct): if the trailing ref param has NO default, every call site reports `E1102: requires prop 'ref'` (the `ref=` attribute is reserved and not counted toward params) - the `= Ref()` default above avoids this. Likewise `{**props}` of a `props: any` bundle into a host tag reports E1104; `jac build` succeeds and the emitted JS is correct.

## Other React hooks (direct import)

`has` = useState, `can with entry` = useEffect, `Ref[T]` field = useRef. For the rest, import directly:

```jac
import from "react" { useCallback, useMemo, useContext, createContext }
```

```jac
def:pub FileUploader() -> JsxElement {
    has fileInputRef: Ref[HTMLInputElement] = Ref();
    triggerPicker: any = useCallback(lambda {
        if fileInputRef.current { fileInputRef.current.click(); }
    }, []);
    <div>
        <input ref={fileInputRef} type="file" style={{"display": "none"}} />
        <button onClick={triggerPicker}>Upload</button>
    </div>
}
```

Mixing Jac sugar (`has`, `can with entry`) with directly-imported hooks in one component is fine. For `createContext`/`useContext` global state, see `jac-cl-organization`.
