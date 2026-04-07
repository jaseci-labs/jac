# Component Composition

## Contents

- Items always inside their Group component
- Callouts use Alert
- Empty states use Empty component
- Choosing between overlay components
- Dialog, Sheet, and Drawer always need a Title
- Card structure
- Button loading state
- TabsTrigger must be inside TabsList
- Avatar always needs AvatarFallback
- Use existing components instead of custom markup
- ButtonGroup uses nested groups for gaps

---

## Items always inside their Group component

Never render items directly inside the content container.

**Incorrect:**

```jac
<SelectContent>
    <SelectItem value="apple">Apple</SelectItem>
    <SelectItem value="banana">Banana</SelectItem>
</SelectContent>
```

**Correct:**

```jac
<SelectContent>
    <SelectGroup>
        <SelectItem value="apple">Apple</SelectItem>
        <SelectItem value="banana">Banana</SelectItem>
    </SelectGroup>
</SelectContent>
```

This applies to all group-based components:

| Item | Group |
|------|-------|
| `SelectItem`, `SelectLabel` | `SelectGroup` |
| `DropdownMenuItem`, `DropdownMenuLabel` | `DropdownMenuGroup` |
| `MenubarItem` | `MenubarGroup` |
| `ContextMenuItem` | `ContextMenuGroup` |
| `CommandItem` | `CommandGroup` |

---

## Callouts use Alert

```jac
<Alert>
    <AlertTitle>Warning</AlertTitle>
    <AlertDescription>Something needs attention.</AlertDescription>
</Alert>
```

---

## Empty states use Empty component

```jac
<Empty>
    <EmptyHeader>
        <EmptyMedia variant="icon"><HugeiconsIcon icon={FolderIcon} /></EmptyMedia>
        <EmptyTitle>No projects yet</EmptyTitle>
        <EmptyDescription>Get started by creating a new project.</EmptyDescription>
    </EmptyHeader>
    <EmptyContent>
        <Button>Create Project</Button>
    </EmptyContent>
</Empty>
```

---

## Choosing between overlay components

| Use case | Component |
|----------|-----------|
| Focused task that requires input | `Dialog` |
| Destructive action confirmation | `AlertDialog` |
| Side panel with details or filters | `Sheet` |
| Mobile-first bottom panel | `Drawer` |
| Quick info on hover | `HoverCard` |
| Small contextual content on click | `Popover` |

---

## Dialog, Sheet, and Drawer always need a Title

`DialogTitle`, `SheetTitle`, `DrawerTitle` are required for accessibility. Use `className="sr-only"` if visually hidden.

```jac
<DialogContent>
    <DialogHeader>
        <DialogTitle>Edit Profile</DialogTitle>
        <DialogDescription>Update your profile.</DialogDescription>
    </DialogHeader>
    {props.children}
</DialogContent>
```

---

## Card structure

Use full composition — don't dump everything into `CardContent`:

```jac
<Card>
    <CardHeader>
        <CardTitle>Team Members</CardTitle>
        <CardDescription>Manage your team.</CardDescription>
    </CardHeader>
    <CardContent>{props.children}</CardContent>
    <CardFooter>
        <Button>Invite</Button>
    </CardFooter>
</Card>
```

---

## Button loading state

Button has no `isPending` or `isLoading` prop. Compose with `Spinner` + `disabled`:

```jac
<Button disabled={isLoading}>
    {isLoading and <Spinner className="size-4" /> or None}
    {isLoading and "Saving..." or "Save"}
</Button>
```

---

## TabsTrigger must be inside TabsList

Never render `TabsTrigger` directly inside `Tabs` — always wrap in `TabsList`:

```jac
<Tabs defaultValue="account">
    <TabsList>
        <TabsTrigger value="account">Account</TabsTrigger>
        <TabsTrigger value="password">Password</TabsTrigger>
    </TabsList>
    <TabsContent value="account">{props.children}</TabsContent>
</Tabs>
```

---

## Avatar always needs AvatarFallback

Always include `AvatarFallback` for when the image fails to load:

```jac
<Avatar>
    <AvatarImage src="/avatar.png" alt="User" />
    <AvatarFallback>JD</AvatarFallback>
</Avatar>
```

---

## Use existing components instead of custom markup

| Instead of | Use |
|---|---|
| `<hr>` or `<div className="border-t">` | `<Separator />` |
| `<div className="animate-pulse">` with styled divs | `<Skeleton className="h-4 w-3/4" />` |
| `<span className="rounded-full bg-green-100 ...">` | `<Badge variant="secondary">` |

---

## ButtonGroup uses nested groups for gaps

The `cn-button-group` CSS only applies `gap-2` when it detects nested `[data-slot=button-group]` children. Use **nested `<ButtonGroup>`** for visible gaps between sections. `ButtonGroupSeparator` only creates subtle 1px divider lines.

**Incorrect — no visible gaps:**

```jac
<ButtonGroup>
    <Button>A</Button>
    <ButtonGroupSeparator />
    <Button>B</Button>
    <ButtonGroupSeparator />
    <Button>C</Button>
</ButtonGroup>
```

**Correct — visible gaps between sections:**

```jac
<ButtonGroup>
    <ButtonGroup>
        <Button>A</Button>
    </ButtonGroup>
    <ButtonGroup>
        <Button>B</Button>
        <Button>C</Button>
    </ButtonGroup>
</ButtonGroup>
```
