# Migrating from React Hook Form to TanStack Form

**Breaking change in `@jac/runtime`**: `useJacForm` previously returned a React Hook Form
handle; it now returns a TanStack Form handle. The two objects have incompatible APIs -
nothing from the old handle shape carries over.

---

## Who is affected

| Usage pattern | Affected? |
|---|---|
| Called `useJacForm` and used the raw handle (`register`, `formState`, `handleSubmit`) | **Yes - runtime errors** |
| Used `<JacForm>` component only, never touched the handle | No (public props unchanged) |
| Imported `react-hook-form` directly without `useJacForm` | No code break, but must declare it in `jac.toml` explicitly (no longer a transitive dep) |

---

## API migration table

| Was (React Hook Form) | Now (TanStack Form) |
|---|---|
| `const { register, formState, handleSubmit } = useJacForm(...)` | Don't destructure - pass `form` to `<JacForm>` or call `form.Field(...)` directly |
| `{...register("fieldName")}` | `<JacForm>` for auto-rendered fields; `form.Field({name: "fieldName"})` for custom UIs |
| `formState.errors.fieldName?.message` | `field.state.meta.errors[0]` |
| `formState.isSubmitting` | `form.state.isSubmitting` |
| `formState.isValid` | `form.state.isValid` (raw TanStack value; see `onTouched` note below) |
| `formState.isDirty` | `form.state.isDirty` |
| `handleSubmit(fn)` | `form.handleSubmit` (or use `<JacForm onSubmit={fn}>`) |

---

## `validateMode` behaviour change

Previously `validateMode="onTouched"` was a native React Hook Form mode:

1. Do **not** validate on change until the field has been blurred once.
2. After first blur, validate on every subsequent change.

TanStack Form has no `onTouched` mode. `JacForm` approximates it by wiring **both**
`onBlur` and `onChange` validators, then gating error display on
`field.state.meta.isTouched` (errors appear after first blur, clear on subsequent
`onChange` without a second blur). Validation still runs in the background pre-blur,
so raw `form.state.isValid` may be `false` before touch.

`<JacForm>` compensates with an `effectiveIsValid` submit gate:

```jac
effectiveIsValid = (
    True
    if (validateMode == "onTouched" and not form.state.isTouched)
    else form.state.isValid
);
```

The built-in submit button uses:

```jac
disabled={form.state.isSubmitting or not form.state.isDirty or not effectiveIsValid}
```

So before any field has been touched, submit stays gated only by `isSubmitting` and
`isDirty`; after the first touch, it also reflects the real `form.state.isValid`.

For custom field UIs built with `form.Field`, apply the same display gate:

```jac
# Only show errors after the field has been touched
if field.state.meta.isTouched and len(field.state.meta.errors) > 0 {
    return <span class="error">{field.state.meta.errors[0]}</span>;
}
```

If you build a custom submit button from the raw form handle and want `<JacForm>`
parity for `validateMode="onTouched"`, mirror the same `effectiveIsValid` logic.

The other modes map cleanly:

| `validateMode` | TanStack validators wired |
|---|---|
| `onChange` | `onChange` only |
| `onBlur` | `onBlur` only |
| `onSubmit` | `onSubmit` only |
| `onTouched` | `onBlur` + `onChange` (display gated on `isTouched`) |

---

## `jac.toml` dependency changes

`react-hook-form` and `@hookform/resolvers` are no longer transitive dependencies of
`@jac/runtime`. Remove them unless your app imports them directly:

```diff
 [dependencies.npm]
 react = "^18.2.0"
 react-dom = "^18.2.0"
 react-router-dom = "^6.22.0"
 react-error-boundary = "^5.0.0"
-react-hook-form = "^7.71.0"
 zod = "^4.3.6"
-"@hookform/resolvers" = "^5.2.2"
```

If your custom form UI calls TanStack Form APIs directly (outside `useJacForm`), add:

```toml
"@tanstack/react-form" = "^1.0.0"
```

---

## Custom form UI example (before / after)

**Before (React Hook Form)**

```jac
cl import from "@jac/runtime" { useJacForm, JacSchema }

def:pub MyCustomForm -> JsxElement {
    schema = JacSchema({ email: JacSchema.string().email() });
    form = useJacForm("onTouched", schema);
    { register, formState, handleSubmit } = form;

    return (
        <form onSubmit={handleSubmit(submitFn)}>
            <input {**register("email")} />
            {formState.errors.email and <span>{formState.errors.email.message}</span>}
            <button type="submit">Submit</button>
        </form>
    );
}
```

**After (TanStack Form)**

```jac
cl import from "@jac/runtime" { useJacForm, JacSchema }

def:pub MyCustomForm -> JsxElement {
    schema = JacSchema({ email: JacSchema.string().email() });
    form = useJacForm("onTouched", schema);
    effectiveIsValid = (
        True
        if not form.state.isTouched
        else form.state.isValid
    );

    return (
        <form onSubmit={(e) -> None {
            e.preventDefault();
            form.handleSubmit();
        }}>
            <form.Field name="email">
                {(field) -> JsxElement {
                    return (
                        <div>
                            <input
                                value={field.state.value}
                                onBlur={field.handleBlur}
                                onChange={(e) -> None { field.handleChange(e.target.value); }}
                            />
                            {field.state.meta.isTouched and len(field.state.meta.errors) > 0 and
                                <span>{field.state.meta.errors[0]}</span>}
                        </div>
                    );
                }}
            </form.Field>
            <button
                type="submit"
                disabled={
                    form.state.isSubmitting
                    or not form.state.isDirty
                    or not effectiveIsValid
                }
            >
                Submit
            </button>
        </form>
    );
}
```

For auto-rendered forms with no custom field UI, `<JacForm>` is unchanged - no migration
needed.
