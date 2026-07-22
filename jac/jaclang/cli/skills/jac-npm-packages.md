---
name: jac-npm-packages
description: How to add npm packages to jac.toml and import them in client `.jac` files, plus DOM/value refs with `Ref[T]` fields, ref forwarding, and React hooks (useCallback, useMemo). Load when a task uses third-party npm libraries or needs a ref. This covers CONSUMING npm packages - to PUBLISH a Jac package to npm, see `jac-packaging`.
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
"radix-ui" = "^1.4.3"
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
    return <div>
        <input ref={inputRef} type="text" />
        <button onClick={handle_click}>Focus</button>
    </div>;
}
```

- `= Ref()` → `useRef(null)`, an empty DOM ref; wire with `ref={inputRef}` and React fills `.current` on mount.
- `= Ref(initial)` → `useRef(initial)`, a value ref for mutable data that shouldn't re-render (timers, flags, last-seen values).
- `useRef` is **auto-imported** - never import it yourself.
- `.current` is typed `T | None` - null-check before use (`if r.current { ... }`).
- The field must be constructed: a bare `has r: Ref[T];` with no `= Ref()` is rejected (E2025).
- The old `inputRef: any = useRef(None)` pattern still runs but loses typing - replace it with a `Ref[T]` field.

## Ref forwarding (parents pointing refs at YOUR component)

A component opts into receiving a ref by declaring a **trailing parameter typed `Ref`** - it lowers to React's `forwardRef((props, ref) => ...)`:

```jac
def:pub FancyInput(placeholder: str, ref: Ref[HTMLInputElement] = Ref()) -> JsxElement {
    return <input ref={ref} placeholder={placeholder} className="fancy" />;
}

# Parent: point a ref at the component, reach the inner <input>
def:pub ParentForm() -> JsxElement {
    has inputRef: Ref[HTMLInputElement] = Ref();
    return <FancyInput ref={inputRef} placeholder="Type here" />;
}
```

- Only the **last** parameter qualifies, and it must be typed `Ref` / `Ref[T]` - the lowering keys on the type alone, so a `= Ref()` default changes nothing at runtime but keeps `jac check` happy at call sites that pass `ref=` as a JSX attribute. Params before it stay normal named props; `ref` is never folded into the props bundle. `forwardRef` is auto-imported.
- **This is what makes a component usable as a radix `asChild` trigger child** (`DropdownMenuTrigger`, `Popover.Trigger`, ...) - the trigger attaches a positioning-anchor ref to its child; a component that can't forward it leaves the anchor null and the menu **silently never opens**. See `jac-shadcn-components`.
- Known `jac check` false positive (build + runtime verified correct): if the trailing ref param has NO default, every call site reports `E1102: requires prop 'ref'` (the `ref=` attribute is reserved and not counted toward params) - the `= Ref()` default above avoids this. Likewise `{**props}` of a `props: any` bundle into a host tag reports E1104; `jac build` succeeds and the emitted JS is correct.

## Other React hooks (direct import)

`has` = useState, `can with entry` = useEffect, `Ref[T]` field = useRef. For the rest, import directly:

```jac
import from react { useCallback, useMemo, useContext, createContext }
```

```jac
def:pub FileUploader() -> JsxElement {
    has fileInputRef: Ref[HTMLInputElement] = Ref();
    triggerPicker: any = useCallback(lambda {
        if fileInputRef.current { fileInputRef.current.click(); }
    }, []);
    return <div>
        <input ref={fileInputRef} type="file" style={{"display": "none"}} />
        <button onClick={triggerPicker}>Upload</button>
    </div>;
}
```

Mixing Jac sugar (`has`, `can with entry`) with directly-imported hooks in one component is fine. For `createContext`/`useContext` global state, see `jac-cl-organization`.
