cl import from "@jac/runtime" { JacForm, JacSchema }
cl import ".assets.jacform-default.css";

def:pub FieldExamples -> Any {
    schema = JacSchema(
        {
            # Text inputs
            textField: JacSchema.string().min(2, "Min 2 characters"),
            emailField: JacSchema.string().email("Invalid email"),
            telField: JacSchema.string().min(10, "Min 10 digits").regex(
                RegExp("^[0-9\\-\\+\\(\\)\\s]*$"),
                "Phone number contains invalid characters"
            ),
            urlField: JacSchema.string().url("Invalid URL"),
            # Password with regex validation and toggle
            passwordField: JacSchema.string().min(
                8, "Password must be at least 8 characters"
            ).regex(
                RegExp("[A-Z]"), "Password must contain at least one uppercase letter"
            ).regex(
                RegExp("[a-z]"), "Password must contain at least one lowercase letter"
            ).regex(
                RegExp("[0-9]"), "Password must contain at least one number"
            ).regex(
                RegExp("[!@#\\$%\\^&\\*]"),
                "Password must contain at least one special character (!@#$%^&*)"
            ),
            confirmPassword: JacSchema.string().min(
                8, "Confirm password must be at least 8 characters"
            ),
            # Number and date/time inputs
            numberField: JacSchema.number().min(1, "Min 1").max(100, "Max 100"),
            dateField: JacSchema.string().min(1, "Date required"),
            datetimeField: JacSchema.string().min(1, "DateTime required"),
            # Select (enum)
            selectField: JacSchema.enum(
                ["option1", "option2", "option3"], "Please select an option"
            ),
            # Radio buttons (enum)
            radioField: JacSchema.enum(["yes", "no", "maybe"], "Please select"),
            # Textarea
            textareaField: JacSchema.string().min(10, "Min 10 characters"),
            # Checkboxes
            checkboxRequired: JacSchema.boolean().refine(
                lambda v: any -> bool { return v == True; }, "Must be checked"
            ),
            checkboxOptional: JacSchema.boolean().optional()
        }
    ).refine(
        lambda data: any -> bool { return data.passwordField == data.confirmPassword; },
        {message: "Passwords do not match", path: ["confirmPassword"],}
    );
    async def handleSubmit(data: dict) -> None {
        console.log("Form submitted:", data);
        alert("Form submitted! Check console for data.");
    }
    return (
        <div style={{maxWidth: "800px", margin: "2rem auto", padding: "2rem"}}>
            <h1 style={{textAlign: "center", marginBottom: "0.5rem"}}>
                JacForm Field Examples
            </h1>
            <p style={{textAlign: "center", color: "#666", marginBottom: "2rem"}}>
                Comprehensive demonstration of all supported field types
            </p>
            <JacForm
                schema={schema}
                onSubmit={handleSubmit}
                layout="vertical"
                className="jac-form"
                submitClassName="jac-form-submit"
                field_config={{
                    "textField": {
                        label: "Text Field",
                        type: "text",
                        placeholder: "Enter text"
                    },
                    "emailField": {
                        label: "Email Field",
                        type: "email",
                        placeholder: "user@example.com"
                    },
                    "telField": {
                        label: "Telephone Field",
                        type: "tel",
                        placeholder: "+1 (555) 123-4567"
                    },
                    "urlField": {
                        label: "URL Field",
                        type: "url",
                        placeholder: "https://example.com"
                    },
                    "passwordField": {
                        label: "Password Field (with regex validation)",
                        type: "password",
                        placeholder: "Must include: A-Z, a-z, 0-9, special chars",
                        showPasswordToggle: True
                    },
                    "confirmPassword": {
                        label: "Confirm Password",
                        type: "password",
                        placeholder: "Re-enter your password",
                        showPasswordToggle: True
                    },
                    "numberField": {
                        label: "Number Field",
                        type: "number",
                        placeholder: "1-100"
                    },
                    "dateField": {label: "Date Field", type: "date"},
                    "datetimeField": {label: "DateTime Field", type: "datetime-local"},
                    "selectField": {
                        label: "Select Field (Dropdown)",
                        type: "select",
                        placeholder: "Choose an option"
                    },
                    "radioField": {label: "Radio Buttons", type: "radio"},
                    "textareaField": {
                        label: "Textarea Field",
                        type: "textarea",
                        placeholder: "Enter multiple lines of text...",
                        rows: 4
                    },
                    "checkboxRequired": {label: "Required Checkbox", type: "checkbox"},
                    "checkboxOptional": {label: "Optional Checkbox", type: "checkbox"}
                }}
                submitLabel="Submit Form"
            />
        </div>
    );
}
