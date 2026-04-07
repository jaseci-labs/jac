# Jac Language Patterns

Essential patterns and gotchas for writing `.cl.jac` components. These are Jac compiler constraints — violating them causes build errors.

## Contents

- Component definition pattern
- Props extraction (no destructuring)
- has = useState
- glob for module-level constants
- CVA + cn() variant pattern
- Sub-component pattern
- Radix trigger styling (no forwardRef)
- Compiler gotchas

---

## Component definition pattern

Components are defined as `def:pub` functions inside a `cl` block, returning `JsxElement`.

```jac
cl import from ...lib.utils { cn }

cl {
    def:pub MyComponent(props: Any) -> JsxElement {
        computedClass = cn("flex items-center gap-2", props.className);
        return <div className={computedClass}>{props.children}</div>;
    }
}
```

---

## Props extraction (no destructuring)

Jac does not support destructuring. Extract props manually with `or` for defaults.

**Incorrect:**

```jac
# This does NOT work in Jac
def:pub Button({variant = "default", size = "default", ...props}) -> JsxElement {
```

**Correct:**

```jac
def:pub Button(props: Any) -> JsxElement {
    variant = props.variant or "default";
    size = props.size or "default";
    return <button {...props}>{props.children}</button>;
}
```

---

## has = useState

`has` declares reactive state. It compiles to React's `useState`.

```jac
cl {
    def:pub Counter(props: Any) -> JsxElement {
        has count: int = 0;
        has isOpen: bool = False;
        has name: str = "";

        return <div>
            <p>{count}</p>
            <button onClick={lambda -> None { count = count + 1; }}>+1</button>
        </div>;
    }
}
```

---

## glob for module-level constants

Use `glob` for values defined outside components. Never use `const`.

```jac
glob _frameworks: list = [
    {"value": "react", "label": "React"},
    {"value": "vue", "label": "Vue"},
    {"value": "angular", "label": "Angular"}
];

glob _buttonVariants: Any = cva("inline-flex items-center ...", {
    "variants": {
        "variant": {
            "default": "bg-primary text-primary-foreground",
            "outline": "border border-border bg-background"
        }
    },
    "defaultVariants": {"variant": "default"}
});
```

---

## CVA + cn() variant pattern

Standard pattern for components with variants:

```jac
cl import from "class-variance-authority" { cva }
cl import from ...lib.utils { cn }

glob _buttonVariants: Any = cva(
    "cn-button inline-flex items-center justify-center rounded-lg border text-sm font-medium",
    {
        "variants": {
            "variant": {
                "default": "cn-button-variant-default bg-primary text-primary-foreground",
                "outline": "cn-button-variant-outline border-border bg-background",
                "ghost": "cn-button-variant-ghost hover:bg-muted"
            },
            "size": {
                "default": "cn-button-size-default h-8 gap-1.5 px-2.5",
                "sm": "cn-button-size-sm h-7 px-2",
                "icon": "cn-button-size-icon size-8"
            }
        },
        "defaultVariants": {"variant": "default", "size": "default"}
    }
);

cl {
    def:pub Button(props: Any) -> JsxElement {
        variant = props.variant or "default";
        size = props.size or "default";
        variantsFn = _buttonVariants;
        computedClass = cn(variantsFn.call(None, {"variant": variant, "size": size, "className": props.className}));
        return <button className={computedClass} {...props}>{props.children}</button>;
    }

    def:pub buttonVariants() -> Any {
        return _buttonVariants;
    }
}
```

---

## Sub-component pattern

For compound components (Card, Dialog, etc.), define each part as a separate function with `data-slot`:

```jac
cl {
    def:pub Card(props: Any) -> JsxElement {
        return <div {...props} data-slot="card" className={cn("cn-card bg-card text-card-foreground", props.className)} />;
    }

    def:pub CardHeader(props: Any) -> JsxElement {
        return <div {...props} data-slot="card-header" className={cn("cn-card-header flex flex-col gap-1.5 pt-6 pl-6 pr-6", props.className)} />;
    }

    def:pub CardTitle(props: Any) -> JsxElement {
        return <div {...props} data-slot="card-title" className={cn("cn-card-title font-semibold leading-none", props.className)} />;
    }

    def:pub CardContent(props: Any) -> JsxElement {
        return <div {...props} data-slot="card-content" className={cn("cn-card-content pl-6 pr-6 pb-6", props.className)} />;
    }
}
```

---

## Radix trigger styling (no forwardRef)

Jac components are plain functions — no `React.forwardRef`. For Radix triggers that need button styles, apply `buttonVariants()` directly:

```jac
# Import the variants function
cl import from .ui.button { buttonVariants }

# Apply directly to trigger className
<DropdownMenuTrigger className={buttonVariants().call(None, {"variant": "ghost", "size": "icon"})}>
    <HugeiconsIcon icon={MoreVerticalIcon} strokeWidth={2} className="size-4" />
</DropdownMenuTrigger>
```

---

## Compiler gotchas

### No tuple unpacking
```jac
# WRONG
a, b = someFunction();

# RIGHT — access by index or use separate calls
result = someFunction();
a = result[0];
b = result[1];
```

### No nested def inside def
```jac
# WRONG
def:pub Parent(props: Any) -> JsxElement {
    def helper() { ... }  # NOT ALLOWED
}

# RIGHT — define at module level
def helper() -> Any { ... }

def:pub Parent(props: Any) -> JsxElement {
    result = helper();
}
```

### No JSX comments
```jac
# WRONG
return <div>
    {/* This is a comment */}
    <p>Hello</p>
</div>;

# RIGHT — no comments in JSX blocks
return <div>
    <p>Hello</p>
</div>;
```

### True/False/None are capitalized
```jac
has isOpen: bool = False;    # not false
has data: Any = None;        # not null/none
if isOpen == True { ... }    # not true
```

### String special chars in JSX must be wrapped
```jac
# WRONG
<p>Terms & Conditions</p>
<p>Ready?</p>

# RIGHT
<p>{"Terms & Conditions"}</p>
<p>{"Ready?"}</p>
```

### Use Reflect.construct() instead of new
```jac
# WRONG
d = new Date();
ws = new WebSocket(url);

# RIGHT
d = Reflect.construct(Date, []);
ws = Reflect.construct(WebSocket, [url]);
```

### Lambda callback gotcha
Function params inside lambdas compile to `new fn()`. Assign to local var and use `.call(None, args)`.

```jac
# WRONG
items.map(lambda(item: Any) -> Any { formatter(item); });

# RIGHT
fmt = formatter;
items.map(lambda(item: Any) -> Any { fmt.call(None, item); });
```

### Boolean in JSX
```jac
# WRONG
{!!value}

# RIGHT
{Boolean(value)}
```

### "\n" bug
`"\n"` compiles to literal `"\\n"`. Use `style.setProperty()` for CSS that needs newlines.
