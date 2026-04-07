# Icons

jac-shadcn uses **HugeIcons** (`@hugeicons/react` + `@hugeicons/core-free-icons`). Never use lucide-react or other icon libraries.

---

## HugeiconsIcon component pattern

Always use the `HugeiconsIcon` wrapper component with the `icon` prop.

**Incorrect:**

```jac
<SearchIcon className="size-4" />
```

**Correct:**

```jac
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Search01Icon }

<HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-4" />
```

---

## Icon sizing

Use `className` with `size-*` for icon dimensions. Use `strokeWidth` for line thickness.

```jac
# Small icon
<HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-3.5" />

# Default icon
<HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-4" />

# Large icon
<HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-5" />
```

---

## Icons in Buttons

Place the `HugeiconsIcon` inside the Button. For icon-only buttons, use `size="icon"`.

```jac
# Icon + text button
<Button variant="outline" size="sm">
    <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-4" />
    Search
</Button>

# Icon-only button
<Button variant="ghost" size="icon">
    <HugeiconsIcon icon={MoreVerticalIcon} strokeWidth={2} className="size-4" />
</Button>
```

---

## Icons in Radix triggers

Since Jac doesn't support `forwardRef`, apply `buttonVariants()` directly to Radix triggers:

```jac
<DropdownMenuTrigger className={buttonVariants().call(None, {"variant": "ghost", "size": "icon"})}>
    <HugeiconsIcon icon={MoreVerticalIcon} strokeWidth={2} className="size-4" />
</DropdownMenuTrigger>
```

---

## Common icon imports

```jac
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" {
    Search01Icon,
    Menu01Icon,
    Cancel01Icon,
    ArrowLeft01Icon,
    ArrowRight01Icon,
    Add01Icon,
    Delete01Icon,
    Edit01Icon,
    Settings01Icon,
    Home01Icon,
    UserIcon,
    MailIcon,
    CheckIcon,
    AlertCircleIcon,
    ChevronDownIcon,
    ChevronUpIcon,
    TextBoldIcon,
    TextItalicIcon,
    TextUnderlineIcon
}
```

---

## Pass icons as objects, not strings

**Incorrect:**

```jac
glob iconMap: dict = {"check": CheckIcon, "alert": AlertCircleIcon};
icon = iconMap[iconName];
```

**Correct:**

```jac
# Pass icon components directly as props
<StatusBadge icon={CheckIcon} />
```
