
# Jac Form Handling Template

A minimal **Jac client-side template** demonstrating a clean and reusable **form handling pattern** inspired by modern React practices (React Hook Form–style architecture).

This template focuses on:
- Component-driven UI
- Schema-based validation
- Centralized form state management

It is intended as a **starter template**, not a full application.

---

##  What This Template Demonstrates

- Form component isolation
- Validation logic separated into schemas
- Shared form state via a store
- Clear, minimal project structure

This pattern can be reused for:
- Login forms
- Registration forms
- Settings forms
- Any structured user input flow

---

##  Project Structure

```

jac-form-handling-template/
├── jac.toml                    # Project configuration
├── main.jac                    # Application entry point
├── components/
│   └── LoginForm.cl.jac        # Form UI component
├── schema/
│   └── loginSchema.cl.jac      # Form validation schema
├── store/
│   └── useFormStore.cl.jac     # Centralized form state
├── assets/                     # Static assets
└── README.md

````

---

##  Architecture Overview

**Component**
- Handles UI rendering
- Reads and updates form state

**Schema**
- Defines validation rules
- Keeps business logic out of UI

**Store**
- Manages form values and errors
- Allows reuse across multiple components

This separation keeps the codebase:
- Easy to reason about
- Easy to extend
- Easy to reuse as a template

---

##  Getting Started

Run the template locally:

```bash
jac start main.jac
````

---

##  Reusing This Template

To adapt this template for a new form:

1. Create a new schema in `schema/`
2. Create a new form component in `components/`
3. Reuse or extend the form store
4. Import the component in `main.jac`

No structural changes are required.

---

## 🎯 Purpose

This template is designed to:

* Serve as a reference implementation
* Provide a consistent form-handling pattern
* Act as a starting point for Jac-based frontend projects

It intentionally avoids overengineering to remain clear and instructional.

