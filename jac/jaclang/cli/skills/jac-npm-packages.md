---
name: jac-npm-packages
description: How to add npm packages to jac.toml and import them in .cl.jac files, including React hooks (useRef, useCallback, useMemo). Load when a task uses third-party npm libraries.
---

> **jac-shadcn projects** (has `[jac-shadcn]` in jac.toml): all npm packages are pre-configured - tailwindcss, radix-ui, clsx, tailwind-merge, hugeicons, recharts, and more. Do **NOT** add packages to `[dependencies.npm]` manually; they ship with the template.

## Adding npm Packages

Declare all packages in `jac.toml` before running `jac install`. Add under the correct section:

- Regular deps: `[dependencies.npm]`
- Dev deps (build tools): `[dependencies.npm.dev]`

```toml
[dependencies.npm]
"sonner" = "^2.0.0"
"recharts" = "^2.10.0"
"clsx" = "*"
"tailwind-merge" = "*"
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
import from "clsx" { clsx }
import from "tailwind-merge" { twMerge }
```

## React Hooks (Direct Import)

`has` = useState, `async can with entry` = useEffect. For others, import directly:

```jac
import from react { useRef, useCallback, useMemo, useContext }
```

**useRef** - DOM reference or mutable value without re-render. `jac check` reports E1032 on `.current` access - known type-stub gap for `useRef`'s return type; works correctly at runtime:

```
import from react { useRef }

def:pub TextInput() -> JsxElement {
    inputRef: Any = useRef(None);
    def handle_click(e: MouseEvent) -> None {
        if inputRef.current { inputRef.current.focus(); }
    }
    return <div>
        <input ref={inputRef} type="text" />
        <button onClick={handle_click}>Focus</button>
    </div>;
}
```

**useCallback** - stable function reference (same `.current` caveat applies):

```
import from react { useRef, useCallback }

def:pub FileUploader() -> JsxElement {
    fileInputRef: Any = useRef(None);
    triggerPicker: Any = useCallback(lambda -> None {
        if fileInputRef.current { fileInputRef.current.click(); }
    }, []);
    return <div>
        <input ref={fileInputRef} type="file" style={{"display": "none"}} />
        <button onClick={triggerPicker}>Upload</button>
    </div>;
}
```

**Mixing with Jac sugar** - freely allowed in the same component (same `.current` caveat applies):

```
import from react { useRef }

def:pub SearchBox() -> JsxElement {
    has query: str = "";
    inputRef: Any = useRef(None);
    async can with [query] entry {
        if inputRef.current { inputRef.current.focus(); }
    }
    return <div><input value={query} /></div>;
}
```
