"""Solid JacForm fixture for jsdom TanStack Form integration test.

Mounts a `JacForm` with an email field (string with `.email()` validation), a
boolean checkbox field, an enum select field, and an enum radio field, using the
default `validateMode="onTouched"`. The Solid runtime wires only the `onChange`
validator for `onTouched` mode (not `onBlur`) so that sibling fields do not
accumulate stale `errorMap["blur"]` entries when the first field is blurred;
error display is gated on `isTouched` to preserve the "show errors after first
touch" UX. `JacForm` gates the submit button on `isTouched` so pre-blur
`isValid=false` (eager onChange) does not disable the button early.

The jsdom harness in `test_solid_jsdom.jac` verifies:

- the form, input, and button elements render correctly via TanStack solid-form
- an invalid email shows a Jac error paragraph after blur (onBlur fires)
- fixing the email clears the error without a second blur (onChange revalidation
  after touch proves the onTouched approximation is live end-to-end)
- the submit button is disabled initially (isDirty=false) and enabled after the
  user enters a valid value and the form becomes dirty+valid
- the checkbox field renders as `<input type="checkbox">` (exercises the checkbox
  branch in `renderInput`, which has no jsdom coverage elsewhere)
- the enum select field renders as a `<select>` with one `<option>` per enum value
  plus the placeholder (exercises the select branch + `getEnumOptions`); picking
  an option updates the select's reflected value
- the enum radio field renders one `<input type="radio">` per option with none
  checked initially; clicking one fires handleChange and marks it checked
- the full submit flow: after all fields dirtied the button is enabled, clicking
  it calls onSubmit (sets globalThis.__jacFormSubmitted), and no throw occurs
"""

import from "@jac/runtime" { JacForm, JacSchema }

def:pub app() -> JsxElement {
    schema = JacSchema({
        email: JacSchema.string().email("Invalid email"),
        agree: JacSchema.boolean(),
        plan: JacSchema.enum(["free", "pro", "enterprise"]),
        role: JacSchema.enum(["admin", "user"])
    });

    return <div data-testid="form-root">
        <JacForm
            schema={schema}
            onSubmit={lambda data: any { globalThis.__jacFormSubmitted = True; return; }}
            field_config={{
                "email": {"type": "email", "label": "Email"},
                "agree": {"type": "checkbox", "label": "I agree"},
                "plan": {"type": "select", "label": "Plan"},
                "role": {"type": "radio", "label": "Role"}
            }}
        />
    </div>;
}
