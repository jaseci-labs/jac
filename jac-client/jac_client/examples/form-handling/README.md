# Form Handling Example

Comprehensive demonstration of JacForm auto-rendered forms with all supported field types.

## Quick Start

```bash
cd form-handling
jac client run
```

## What JacForm Offers

- **Auto-rendering** - Generate complete forms from Zod schemas
- **Type-safe validation** - Schema-based validation with Zod
- **Multiple layouts** - Vertical, grid, horizontal, inline
- **Built-in features** - Password toggles, validation errors, field configurations
- **Minimal code** - ~80% less code than manual forms

## Supported Field Types

| Type | Schema | Config |
|------|--------|--------|
| **Text** | `JacSchema.string()` | `type: "text"` |
| **Email** | `JacSchema.string().email()` | `type: "email"` |
| **Password** | `JacSchema.string()` | `type: "password"`, `showPasswordToggle: true` |
| **Tel** | `JacSchema.string()` | `type: "tel"` |
| **URL** | `JacSchema.string().url()` | `type: "url"` |
| **Number** | `JacSchema.number()` | `type: "number"` |
| **Date** | `JacSchema.string()` | `type: "date"` |
| **DateTime** | `JacSchema.string()` | `type: "datetime-local"` |
| **Select** | `JacSchema.enum([...])` | `type: "select"` |
| **Radio** | `JacSchema.enum([...])` | `type: "radio"` |
| **Textarea** | `JacSchema.string()` | `type: "textarea"`, `rows: 4` |
| **Checkbox** | `JacSchema.boolean()` | `type: "checkbox"` |

## Field Configuration Options

- `label` - Field label text
- `placeholder` - Placeholder text
- `type` - Field type (required)
- `rows` - Textarea rows (default: 4)
- `showPasswordToggle` - Show password checkbox (password fields only)
- `className` - Field wrapper CSS class
- `inputClassName` - Input element CSS class
- `labelClassName` - Label element CSS class

## Documentation

For detailed API reference and advanced usage, see [Form Handling Documentation](../../docs/advance/form-handling.md).
