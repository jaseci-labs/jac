# Forms & Inputs

## Contents

- Form layout with Field + Label
- InputGroup requires InputGroupInput/InputGroupTextarea
- Buttons inside inputs use InputGroup + InputGroupAddon
- Option sets (2–5 choices) use ToggleGroup
- Field validation and disabled states

---

## Form layout with Field + Label

Use proper `Label` and semantic layout — never raw `div` with `space-y-*`:

```jac
<div className="flex flex-col gap-4">
    <div className="flex flex-col gap-2">
        <Label htmlFor="email">Email</Label>
        <Input id="email" type="email" />
    </div>
    <div className="flex flex-col gap-2">
        <Label htmlFor="password">Password</Label>
        <Input id="password" type="password" />
    </div>
</div>
```

**Choosing form controls:**

- Simple text input → `Input`
- Dropdown with predefined options → `Select`
- Searchable dropdown → `Combobox`
- Native HTML select (no JS) → `NativeSelect`
- Boolean toggle → `Switch` (for settings) or `Checkbox` (for forms)
- Single choice from few options → `RadioGroup`
- Toggle between 2–5 options → `ToggleGroup` + `ToggleGroupItem`
- OTP/verification code → `InputOTP`
- Multi-line text → `Textarea`

---

## InputGroup requires InputGroupInput/InputGroupTextarea

Never use raw `Input` or `Textarea` inside an `InputGroup`.

**Incorrect:**

```jac
<InputGroup>
    <Input placeholder="Search..." />
</InputGroup>
```

**Correct:**

```jac
cl import from .ui.input-group { InputGroup, InputGroupInput }

<InputGroup>
    <InputGroupInput placeholder="Search..." />
</InputGroup>
```

---

## Buttons inside inputs use InputGroup + InputGroupAddon

Never place a `Button` directly inside or adjacent to an `Input` with custom positioning.

**Incorrect:**

```jac
<div className="relative">
    <Input placeholder="Search..." className="pr-10" />
    <Button className="absolute right-0 top-0" size="icon">
        <HugeiconsIcon icon={Search01Icon} />
    </Button>
</div>
```

**Correct:**

```jac
cl import from .ui.input-group { InputGroup, InputGroupInput, InputGroupAddon }

<InputGroup>
    <InputGroupInput placeholder="Search..." />
    <InputGroupAddon>
        <Button size="icon">
            <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-4" />
        </Button>
    </InputGroupAddon>
</InputGroup>
```

---

## Option sets (2–5 choices) use ToggleGroup

Don't manually loop `Button` components with active state.

**Incorrect:**

```jac
has selected: str = "daily";

<div className="flex gap-2">
    <Button variant={selected == "daily" and "default" or "outline"} onClick={lambda -> None { selected = "daily"; }}>Daily</Button>
    <Button variant={selected == "weekly" and "default" or "outline"} onClick={lambda -> None { selected = "weekly"; }}>Weekly</Button>
    <Button variant={selected == "monthly" and "default" or "outline"} onClick={lambda -> None { selected = "monthly"; }}>Monthly</Button>
</div>
```

**Correct:**

```jac
cl import from .ui.toggle-group { ToggleGroup, ToggleGroupItem }

<ToggleGroup type="single" defaultValue="daily">
    <ToggleGroupItem value="daily">Daily</ToggleGroupItem>
    <ToggleGroupItem value="weekly">Weekly</ToggleGroupItem>
    <ToggleGroupItem value="monthly">Monthly</ToggleGroupItem>
</ToggleGroup>
```

---

## Field validation and disabled states

Use `aria-invalid` on the control for invalid state, `disabled` for disabled state.

```jac
# Invalid field
<div className="flex flex-col gap-2">
    <Label htmlFor="email">Email</Label>
    <Input id="email" aria-invalid={True} />
    <p className="text-sm text-destructive">Invalid email address.</p>
</div>

# Disabled field
<div className="flex flex-col gap-2">
    <Label htmlFor="email" className="text-muted-foreground">Email</Label>
    <Input id="email" disabled={True} />
</div>
```
