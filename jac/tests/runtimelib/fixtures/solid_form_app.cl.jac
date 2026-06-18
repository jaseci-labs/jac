"""Solid JacForm fixture for jsdom TanStack Form integration test.

Mounts a `JacForm` with an email field (string with `.email()` validation) and
a boolean checkbox field using the default `validateMode="onTouched"`. The Solid
runtime wires both `onBlur` and `onChange` validators for `onTouched`, so the
jsdom harness in `test_solid_jsdom.jac` can verify:

- the form, input, and button elements render correctly via TanStack solid-form
- an invalid email shows a Jac error paragraph after blur (onBlur fires)
- fixing the email clears the error without a second blur (onChange revalidation
  after touch proves the onTouched approximation is live end-to-end)
- the checkbox field renders as `<input type="checkbox">` (exercises the checkbox
  branch in `renderInput`, which has no jsdom coverage elsewhere)
"""

import from "@jac/runtime" { JacForm, JacSchema }

def:pub app() -> JsxElement {
    schema = JacSchema({
        email: JacSchema.string().email("Invalid email"),
        agree: JacSchema.boolean()
    });

    return <div data-testid="form-root">
        <JacForm
            schema={schema}
            onSubmit={lambda data: any { return; }}
            field_config={{
                "email": {"type": "email", "label": "Email"},
                "agree": {"type": "checkbox", "label": "I agree"}
            }}
        />
    </div>;
}
