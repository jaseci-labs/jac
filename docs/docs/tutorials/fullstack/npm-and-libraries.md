# NPM Packages & UI Libraries

Jac's client-side compiler gives you full access to the npm ecosystem. You can import React hooks, UI component libraries, utility packages, and any other npm module directly into your `.cl.jac` files. This tutorial covers how to add npm dependencies, import them, and integrate popular UI libraries like Tailwind CSS and shadcn/ui.

> **Prerequisites**
>
> - Completed: [State Management](state.md)
> - Time: ~30 minutes

!!! note "npm imports and `jac check`"
    npm packages bundle correctly under `jac start`, but the static checker has no `.d.ts`-equivalent stubs for them yet, so attribute access on imported npm symbols (`useRef().current`, `axios.get`, lodash methods, shadcn primitives, etc.) shows up as Unknown under isolated `jac check`. The snippets below run as written; a typed-stub story for npm imports lands as a separate type-checker improvement.

---

## Adding NPM Dependencies

### Via jac.toml

Declare dependencies in your `jac.toml` file under `[dependencies.npm]`:

```toml
[dependencies.npm]
"@radix-ui/react-slot" = "*"
"class-variance-authority" = "^0.7.1"
"sonner" = "^2.0.0"
"react-markdown" = "latest"
"@monaco-editor/react" = "^4.7.0"
"@hugeicons/react" = "*"
"@hugeicons/core-free-icons" = "*"

[dependencies.npm.dev]
"@tailwindcss/vite" = "latest"
tailwindcss = "latest"
```

Then run `jac start` or `jac install --npm` to install them.

### Via CLI

```bash
# Add a runtime dependency
jac install --npm sonner

# Add a dev dependency
jac install --npm --dev tailwindcss

# Remove a dependency
jac remove --npm sonner
```

### What Packages Are Supported?

Any npm package that works with React and Vite is supported. This includes:

- **React ecosystem** -- React Router, React Query, Zustand, Jotai
- **UI component libraries** -- Radix UI, shadcn/ui, Material UI, Ant Design, Chakra UI
- **Styling** -- Tailwind CSS, Emotion, styled-components, CSS Modules
- **Utilities** -- lodash, date-fns, clsx, tailwind-merge, class-variance-authority
- **Editors** -- Monaco Editor, CodeMirror
- **Charts** -- Recharts, Chart.js, D3
- **Icons** -- HugeIcons, Lucide, React Icons, Heroicons
- **Terminals** -- xterm.js
- **Markdown** -- react-markdown, MDX

If a package works in a standard Vite + React project, it works in Jac.

---

## Importing NPM Packages

### Basic Import Syntax

```jac
# Named imports
import from "sonner" { toast as sonnerToast }
import from "clsx" { clsx }
import from "tailwind-merge" { twMerge }

# Scoped packages
import from "@monaco-editor/react" { Editor, DiffEditor }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { File02Icon, Cancel01Icon }

# Radix UI primitives
import from "radix-ui" { Dialog as DialogPrimitive }
import from "radix-ui" { Select as SelectPrimitive }
```

### Importing React Hooks Directly

While Jac provides idiomatic syntax for `useState` (`has`) and `useEffect` (`can with entry`), you can also import and use React hooks directly:

```jac
import from react { useState, useEffect, useRef, useCallback, useMemo }
```

This is useful when:

- You need `useRef` for DOM element references or mutable values
- You need `useCallback` to memoize event handlers
- You need `useMemo` for expensive computations
- You prefer the explicit React API over Jac's sugar syntax

### useRef

`useRef` creates a mutable reference that persists across renders without triggering re-renders:

```jac
import from react { useRef }

def:pub TextInput() -> JsxElement {
    inputRef = useRef(None);

    def focusInput() -> None {
        if inputRef.current {
            inputRef.current.focus();
        }
    }

    return <div>
        <input ref={inputRef} type="text" />
        <button onClick={lambda -> None { focusInput(); }}>Focus</button>
    </div>;
}
```

!!! tip "Prefer the `Ref[T]` field form for component refs"
    For a ref you hold for the life of a component, declare it as a typed
    `has`-field instead of a manual import: `has inputRef: Ref[HTMLInputElement] = Ref();`
    compiles to the same `useRef(null)`, auto-imports `useRef`, and gives
    `.current` a real type (`HTMLInputElement | None`). See
    [Refs with `Ref[T]`](state.md). The manual `import from react { useRef }`
    form shown here is still useful for inline locals and value refs created
    mid-function.

Common uses for `useRef`:

<!-- jac-skip -->
```jac
# DOM element reference
scrollRef = useRef(None);

# Mutable value that doesn't trigger re-render
timerRef = useRef(None);
prevValueRef = useRef("");

# Track a state value without re-rendering
isMountedRef = useRef(False);
```

### useCallback

`useCallback` memoizes a function so it only changes when dependencies change:

```jac
import from react { useCallback }

def:pub FileUploader() -> JsxElement {
    fileInputRef = useRef(None);

    triggerPicker = useCallback(lambda -> None {
        if fileInputRef.current {
            fileInputRef.current.click();
        }
    }, []);

    return <div>
        <input ref={fileInputRef} type="file" style={{"display": "none"}} />
        <button onClick={triggerPicker}>Upload File</button>
    </div>;
}
```

### Mixing Jac Sugar with Direct React Hooks

You can freely mix `has` (useState sugar) with direct React hook imports in the same component:

```jac
import from react { useRef, useCallback, useEffect }

def:pub SearchBox() -> JsxElement {
    has query: str = "";           # Jac sugar for useState
    has results: list = [];        # Jac sugar for useState
    inputRef = useRef(None);       # Direct React hook

    # Jac sugar for useEffect with dependency
    async can with [query] entry {
        if query {
            results = await search_api(query);
        }
    }

    # Direct React useEffect for DOM manipulation
    useEffect(lambda -> None {
        if inputRef.current {
            inputRef.current.focus();
        }
    }, []);

    return <div>
        <input
            ref={inputRef}
            value={query}
            onChange={lambda e: ChangeEvent { query = e.target.value; }}
        />
        <ul>{[<li key={r.id}>{r.title}</li> for r in results]}</ul>
    </div>;
}
```

---

## Tailwind CSS

### Setup (v4 -- Recommended)

1. Add dependencies:

```bash
jac install --npm --dev tailwindcss @tailwindcss/vite
```

1. Configure in `jac.toml`:

```toml
[dependencies.npm.dev]
tailwindcss = "latest"
"@tailwindcss/vite" = "latest"

[client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]
```

1. Create your CSS entry point (e.g., `assets/main.css`):

```css
@import "tailwindcss";
```

1. Import it in your app:

```jac
import "./assets/main.css";

def:pub app() -> JsxElement {
    return <div className="min-h-screen bg-gray-100 p-8">
        <h1 className="text-3xl font-bold text-gray-900">Hello from Jac</h1>
        <p className="mt-4 text-gray-600">Tailwind CSS is working.</p>
    </div>;
}
```

### Conditional Classes

Use ternary expressions for dynamic Tailwind classes:

```jac
def:pub Tab(props: any) -> JsxElement {
    activeCls = "border-primary text-foreground";
    inactiveCls = "border-transparent text-muted-foreground hover:text-foreground";

    return <button
        className={"px-2.5 py-1.5 text-sm font-medium border-b-2 " +
            (activeCls if props.active else inactiveCls)}
        onClick={props.onClick}
    >
        {props.children}
    </button>;
}
```

---

## shadcn/ui Integration

[shadcn/ui](https://ui.shadcn.com/) is a popular component library built on Radix UI primitives and Tailwind CSS. shadcn support is built into **jaclang** -- the full component set ships bundled with jaclang, so `jac install --shadcn` installs pre-built, themed components **offline** (no registry fetch).

### Setup

Create a new themed project (fully offline -- the component set, styles, and color themes all ship with jaclang):

```bash
jac create --use jac-shadcn --theme rose --font inter myapp
cd myapp
jac install
```

This scaffolds a themed starter: a generated `global.css` (theme colors + font + radius), `lib/utils.cl.jac`, and `button`/`card` components for the chosen style, plus a `main.jac` that demos them. All theme flags are optional and default to `nova`/`neutral`/`figtree`:

| Flag | Values | Default |
|------|--------|---------|
| `--style` | `nova`, `vega`, `maia`, `lyra`, `mira` | `nova` |
| `--baseColor` | `neutral`, `stone`, `zinc`, `gray` | `neutral` |
| `--theme` | `rose`, `emerald`, `blue`, `amber`, … | `neutral` |
| `--font` | `inter`, `outfit`, `geist`, … | `figtree` |
| `--radius` | `none`, `small`, `medium`, `large` | `default` |
| `--menuAccent` | `subtle`, `bold` | `subtle` |

The chosen values are written to the `[jac-shadcn]` section of `jac.toml`.

### Re-theme in place

Change the theme of an existing project without recreating it -- `jac retheme` regenerates `global.css` from `[jac-shadcn]` (and, when `--style` changes, re-resolves the components already in `components/ui/`):

```bash
jac retheme --theme emerald --font outfit   # switch accent + font
jac retheme --style mira                     # switch style, restyle installed components
jac retheme                                  # regenerate from the current jac.toml config
```

### Add more components

```bash
jac install --shadcn button card dialog
```

This resolves the chosen style's `.cl.jac` components into `components/ui/`, installs peer dependencies automatically, and creates the `cn()` utility if needed -- all from the bundled component set, no network required.

### Adding Components to Your Code

Components install as `components/ui/<name>.cl.jac`, keeping their hyphenated registry names (`button.cl.jac`, `dropdown-menu.cl.jac`). **Quote the import path** -- it is required for hyphenated names (an unquoted `dropdown-menu` is a parse error) -- and make the leading dots relative to the importing file's folder: `.components.ui.<name>` from a root file like `main.jac`, `.ui.<name>` from a file in `components/`.

```jac
cl {
    import from ".components.ui.button" { Button }
    import from ".components.ui.dropdown-menu" { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent }

    def:pub MyPage() -> JsxElement {
        return <div>
            <Button variant="outline">Click me</Button>
        </div>;
    }
}
```

### The cn() Utility in Jac

`jac install --shadcn` and `jac create --use jac-shadcn` generate `lib/utils.cl.jac` for you, so you rarely write this by hand. For reference, the standard shadcn `cn()` utility is written entirely in Jac (no TypeScript needed) using a variadic parameter:

```jac
# lib/utils.cl.jac
cl import from "clsx" { clsx }
cl import from "tailwind-merge" { twMerge }

def:pub cn(*inputs: any) -> str {
    return twMerge(clsx(inputs));
}
```

Required dependencies (added automatically by `jac install --shadcn`):

```toml
[dependencies.npm]
clsx = "*"
tailwind-merge = "*"
```

### Building shadcn Components in Jac

`jac install --shadcn` already installs the full, production-ready primitives into `components/ui/`, so you don't normally hand-write them -- build your own higher-level components on top instead. The simplified examples below are illustrative: they show how a bundled component is structured (CVA for variants, a `...lib.utils` import for `cn()`, JSX prop spread) and how you'd author a custom one.

Here's how the shadcn Button component looks in Jac, using Class Variance Authority (CVA) for variant management:

```jac
# components/ui/button.cl.jac
import from "class-variance-authority" { cva }
import from ...lib.utils { cn }

glob _buttonVariants: any = cva(
    "inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors",
    {
        "variants": {
            "variant": {
                "default": "bg-primary text-primary-foreground hover:bg-primary/80",
                "outline": "border border-border bg-background hover:bg-muted",
                "ghost": "hover:bg-muted hover:text-foreground",
                "destructive": "bg-destructive/10 hover:bg-destructive/20 text-destructive"
            },
            "size": {
                "default": "h-8 gap-1.5 px-2.5",
                "sm": "h-7 gap-1 px-2.5 text-xs",
                "lg": "h-10 gap-2 px-4",
                "icon": "size-8"
            }
        },
        "defaultVariants": {
            "variant": "default",
            "size": "default"
        }
    }
);

def:pub Button(props: any, ref: Ref[HTMLButtonElement]) -> JsxElement {
    variant = props.variant or "default";
    size = props.size or "default";
    computedClass = cn(
        _buttonVariants.call(None, {"variant": variant, "size": size}),
        props.className
    );

    return <button ref={ref} className={computedClass} {**props}>
        {props.children}
    </button>;
}
```

The trailing `ref: Ref[HTMLButtonElement]` parameter is what lets this `Button` be used as a radix `asChild` trigger (`DropdownMenuTrigger`, `Tooltip.Trigger`, ...). It forwards the anchor ref radix needs for positioning down to the real `<button>`; without it the trigger would silently never open. See [forwarding a ref into your component](state.md#forwarding-a-ref-into-your-component) for the details.

Required dependencies:

```toml
[dependencies.npm]
"class-variance-authority" = "^0.7.1"
```

### Wrapping Radix UI Primitives

shadcn components wrap Radix UI primitives. Each wrapper that renders a DOM node **forwards a ref** to it (via a trailing `ref: Ref` parameter) so the primitive stays a valid `asChild` / positioning target -- exactly as upstream shadcn does with `React.forwardRef`. The exception is a wrapper around a context-only primitive like `Dialog.Root`, which renders no element and takes no ref. Here's a Dialog example in Jac:

```jac
# components/ui/dialog.cl.jac
import from "radix-ui" { Dialog as DialogPrimitive }
import from ...lib.utils { cn }

# Root is a context provider -- it renders no DOM node, so it takes no ref.
def:pub Dialog(props: any) -> JsxElement {
    return <DialogPrimitive.Root {**props}>
        {props.children}
    </DialogPrimitive.Root>;
}

def:pub DialogTrigger(props: any, ref: Ref[HTMLButtonElement]) -> JsxElement {
    return <DialogPrimitive.Trigger ref={ref} {**props}>
        {props.children}
    </DialogPrimitive.Trigger>;
}

def:pub DialogContent(props: any, ref: Ref[HTMLElement]) -> JsxElement {
    return <DialogPrimitive.Portal>
        <DialogPrimitive.Overlay
            className={cn("fixed inset-0 z-50 bg-black/50", props.overlayClassName)}
        />
        <DialogPrimitive.Content
            ref={ref}
            className={cn(
                "fixed left-1/2 top-1/2 z-50 -translate-x-1/2 -translate-y-1/2",
                "w-full max-w-lg rounded-lg bg-background p-6 shadow-lg",
                props.className
            )}
        >
            {props.children}
        </DialogPrimitive.Content>
    </DialogPrimitive.Portal>;
}
```

Forwarding the ref on `DialogTrigger` is what lets `<DialogTrigger asChild>` wrap your own `Button` and still open: radix attaches the anchor ref through the trigger down to the host node. See [forwarding a ref into your component](state.md#forwarding-a-ref-into-your-component) for how the trailing `ref: Ref` parameter lowers to `forwardRef`.

Required dependencies:

```toml
[dependencies.npm]
"radix-ui" = "^1.4.3"
```

### Using shadcn Semantic Color Tokens

shadcn uses semantic color tokens (not hardcoded hex values) so themes work automatically:

<!-- jac-skip -->
```jac
# Good - semantic tokens that adapt to theme
<div className="text-foreground bg-background border-border" />
<div className="text-success bg-success/10 border-success/30" />
<div className="text-destructive bg-destructive/10" />
<div className="text-muted-foreground bg-muted" />

# Avoid - hardcoded colors
<div className="text-gray-900 bg-white border-gray-200" />
```

---

## Icon Libraries

### HugeIcons

```jac
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    File02Icon,
    Cancel01Icon,
    ComputerTerminal01Icon
}

def:pub IconDemo() -> JsxElement {
    return <div>
        <HugeiconsIcon icon={File02Icon} strokeWidth={2} />
        <HugeiconsIcon icon={Cancel01Icon} size={20} />
    </div>;
}
```

### Lucide (Alternative)

```jac
import from "lucide-react" { Search, X, Menu, ChevronDown }

def:pub NavBar() -> JsxElement {
    return <nav>
        <button><Menu size={24} /></button>
        <button><Search size={20} /></button>
    </nav>;
}
```

---

## Rich Components

### Monaco Editor

```jac
import from "@monaco-editor/react" { Editor }

def:pub CodeEditor() -> JsxElement {
    has code: str = "print('hello')";

    return <Editor
        height="400px"
        language="python"
        theme="vs-dark"
        value={code}
        onChange={lambda value: any -> None { code = value; }}
    />;
}
```

```toml
[dependencies.npm]
"@monaco-editor/react" = "^4.7.0"
```

### Toast Notifications (Sonner)

```jac
import from "sonner" { toast as sonnerToast, Toaster }

def:pub app() -> JsxElement {
    def showToast() -> None {
        sonnerToast.success("Changes saved!");
    }

    return <div>
        <Toaster position="top-right" />
        <button onClick={lambda -> None { showToast(); }}>Save</button>
    </div>;
}
```

```toml
[dependencies.npm]
sonner = "^2.0.0"
```

### Resizable Panels

```jac
import from "react-resizable-panels" {
    Panel, PanelGroup, PanelResizeHandle
}

def:pub SplitView() -> JsxElement {
    return <PanelGroup direction="horizontal">
        <Panel defaultSize={30} minSize={20}>
            <Sidebar />
        </Panel>
        <PanelResizeHandle className="w-1 bg-border" />
        <Panel>
            <MainContent />
        </Panel>
    </PanelGroup>;
}
```

---

## Key Takeaways

| Task | How |
|------|-----|
| Add npm package | `jac install --npm <pkg>` or `[dependencies.npm]` in jac.toml |
| Import package | `import from "<package>" { named_export }` |
| Import React hooks | `import from react { useRef, useCallback }` |
| Setup Tailwind | Add vite plugin config + CSS import |
| Setup shadcn | `[jac-shadcn]` in jac.toml |
| Use cn() utility | Write in Jac with clsx + tailwind-merge |

---

## Next Steps

- [Advanced Patterns & JS Interop](advanced-patterns.md) - WebSockets, debugging, JavaScript gotchas
- [Backend Integration](backend.md) - Connect your UI to walkers
