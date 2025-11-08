# Imports in Jac: Working with Modules and Libraries

Learn how to import third-party libraries, other Jac files, and JavaScript modules in your Jac applications.

---

## 📚 Table of Contents

- [Working with Third-Party Node Modules](#working-with-third-party-node-modules)
- [Installing Packages](#installing-packages)
- [Importing Third-Party Libraries](#importing-third-party-libraries)
- [Importing Other Jac Files](#importing-other-jac-files)
- [Importing JavaScript Files](#importing-javascript-files)
- [Best Practices](#best-practices)

---

## Working with Third-Party Node Modules

Jac supports importing any npm package that's compatible with ES modules. This includes popular libraries like React UI frameworks, utility libraries, and more.

### Prerequisites

Before importing third-party libraries, you need:

1. **Node.js** installed (for npm)
2. **package.json** in your project root
3. **Vite** configured in your project (automatically set up with `jac create_jac_app`)

### Why Third-Party Libraries?

Third-party libraries provide:
- **UI Components**: React component libraries (Ant Design, Material-UI, etc.)
- **Utilities**: Helper functions and utilities (lodash, date-fns, etc.)
- **Tools**: Development and production tools
- **Reusability**: Community-maintained, tested code

---

## Installing Packages

### Step 1: Install with npm

Use npm to install packages into your project:

```bash
# Install a package
npm install antd

# Install a specific version
npm install antd@5.12.8

# Install as dev dependency (development tools)
npm install --save-dev vite

# Install multiple packages
npm install antd react-icons date-fns
```

**What Happens:**
- Package is downloaded to `node_modules/`
- Package is added to `package.json` dependencies
- Package becomes available for import

### Step 2: Verify Installation

Check that the package is installed:

```bash
# Check package.json
cat package.json

# Verify node_modules exists
ls node_modules | grep antd
```

**package.json Example:**
```json
{
  "name": "my-app",
  "version": "1.0.0",
  "dependencies": {
    "antd": "^5.12.8",
    "react-icons": "^4.12.0"
  },
  "devDependencies": {
    "vite": "^5.0.0"
  }
}
```

---

## Importing Third-Party Libraries

Once a package is installed, you can import it using Jac's `cl import` syntax.

### Basic Import Syntax

```jac
cl import from package_name {
    Component1,
    Component2,
    Function1,
    Constant1
}
```

**Key Points:**
- Use `cl import` for client-side imports
- `from package_name` - the npm package name (no quotes)
- `{ ... }` - list of exports to import (comma-separated)

### Example: Importing Ant Design

```bash
# First, install Ant Design
npm install antd
```

```jac
"""Importing Ant Design components."""

cl import from antd {
    Button,
    Card,
    Input,
    Space
}

cl def MyApp() -> any {
    return <div>
        <Space direction="vertical" size="large">
            <Card title="Welcome">
                <Input placeholder="Enter text..." />
                <Button type="primary">Submit</Button>
            </Card>
        </Space>
    </div>;
}

cl def jac_app() -> any {
    return MyApp();
}
```

### Example: Importing React Icons

```bash
# Install React Icons
npm install react-icons
```

```jac
"""Importing React Icons."""

cl import from 'react-icons' {
    FaHome,
    FaUser,
    FaSettings
}

cl def Navigation() -> any {
    return <nav>
        <FaHome />
        <FaUser />
        <FaSettings />
    </nav>;
}
```

### Example: Importing Utility Libraries

```bash
# Install utility libraries
npm install date-fns lodash
```

```jac
"""Importing utility functions."""

cl import from 'date-fns' {
    format,
    parseISO,
    differenceInDays
}

cl import from lodash {
    debounce,
    throttle
}

```

### Example: Importing Multiple Components

```jac
"""Importing multiple components from a library."""

cl import from antd {
    Button,
    Card,
    Input,
    Form,
    Select,
    DatePicker,
    Table
}

cl def FormExample() -> any {
    return <Card title="Form Example">
        <Form>
            <Input placeholder="Name" />
            <Select placeholder="Select option">
                <option value="1">Option 1</option>
                <option value="2">Option 2</option>
            </Select>
            <DatePicker />
            <Button type="primary">Submit</Button>
        </Form>
    </Card>;
}
```

### Importing Default Exports

Some libraries export a default export. Import it like this:

```jac
"""Importing default exports."""

# If the library has a default export, you can import it
# Note: Check the library's documentation for export patterns

cl import from mylibrary {
   default as MyLibrary
}
```

### Using Imported Components

Once imported, use components just like Jac components:

```jac
cl import from antd {
    Button,
    Card,
    Modal
}

cl def MyComponent() -> any {
    return <div>
        <Card title="My Card">
            <Button
                type="primary"
                onClick={lambda -> None {
                    console.log("Button clicked!");
                }}
            >
                Click Me
            </Button>
        </Card>
    </div>;
}
```

---

## Importing Other Jac Files

You can import components, functions, and constants from other Jac files in your project.

### Relative Import Syntax

```jac
cl import from .module_name {
    Component1,
    Function1,
    Constant1
}
```

**Key Points:**
- Use `.` for relative imports (same directory or subdirectory)
- `.module_name` - the Jac file name without `.jac` extension
- `{ ... }` - list of exports to import

### Example: Importing from Same Directory

**button.jac:**
```jac
"""Button component."""

cl def CustomButton(props: dict) -> any {
    return <button
        style={{
            "padding": "10px 20px",
            "background": "#7C3AED",
            "color": "#FFFFFF",
            "border": "none",
            "borderRadius": "6px",
            "cursor": "pointer"
        }}
        onClick={props.onClick}
    >
        {props.children}
    </button>;
}

cl def PrimaryButton(props: dict) -> any {
    return <button
        style={{
            "padding": "10px 20px",
            "background": "#059669",
            "color": "#FFFFFF",
            "border": "none",
            "borderRadius": "6px",
            "cursor": "pointer"
        }}
        onClick={props.onClick}
    >
        {props.children}
    </button>;
}
```

**app.jac:**
```jac
"""Main application."""

cl import from .button {
    CustomButton,
    PrimaryButton
}

cl def App() -> any {
    return <div>
        <CustomButton onClick={lambda -> None { console.log("Clicked!"); }}>
            Custom Button
        </CustomButton>
        <PrimaryButton onClick={lambda -> None { console.log("Primary!"); }}>
            Primary Button
        </PrimaryButton>
    </div>;
}

cl def jac_app() -> any {
    return App();
}
```

### Example: Importing from Subdirectory

> currently not suported

## Importing JavaScript Files

You can import functions, classes, and constants from local JavaScript files.

### JavaScript File Structure

**utils.js:**
```javascript
// Export individual functions
export function formatMessage(name) {
    return `Hello, ${name}!`;
}

export function calculateSum(a, b) {
    return a + b;
}

// Export constants
export const JS_CONSTANT = "JavaScript Import Test";

// Export class
export class MessageFormatter {
    constructor(prefix) {
        this.prefix = prefix;
    }

    format(message) {
        return `[${this.prefix}] ${message}`;
    }
}

// Export default (if needed)
export default function defaultExport() {
    return "Default export";
}
```

### Importing from JavaScript Files

```jac
"""Importing from JavaScript files."""

cl import from .utils {
    formatMessage,
    calculateSum,
    JS_CONSTANT,
    MessageFormatter
}

cl def JsImportTest() -> any {
    greeting = formatMessage("Jac");
    sum = calculateSum(5, 3);
    formatter = MessageFormatter("JS");
    formatted = formatter.format("Hello from JS class");

    return <div>
        <h1>{JS_CONSTANT}</h1>
        <p>Greeting: {greeting}</p>
        <p>Sum (5 + 3): {sum}</p>
        <p>Constant: {JS_CONSTANT}</p>
        <p>Formatted: {formatted}</p>
    </div>;
}

cl def jac_app() -> any {
    return JsImportTest();
}
```

### Using JavaScript Functions

```jac
"""Using imported JavaScript functions."""

cl import from .dateUtils {
    formatDate,
    parseDate,
    getDaysDifference
}

cl import from .stringUtils {
    capitalize,
    slugify
}

cl def DateComponent() -> any {
    today = new Date();
    formatted = formatDate(today);

    return <div>
        <p>Today: {formatted}</p>
        <p>Capitalized: {capitalize("hello world")}</p>
    </div>;
}
```

### JavaScript Classes

```jac
"""Using imported JavaScript classes."""

cl import from .validators {
    EmailValidator,
    PasswordValidator
}

cl def ValidationForm() -> any {
    emailValidator = EmailValidator();
    passwordValidator = PasswordValidator();

    return <form>
        <input
            type="email"
            onBlur={lambda e: any -> None {
                if not emailValidator.validate(e.target.value) {
                    alert("Invalid email");
                }
            }}
        />
        <input
            type="password"
            onBlur={lambda e: any -> None {
                if not passwordValidator.validate(e.target.value) {
                    alert("Invalid password");
                }
            }}
        />
    </form>;
}
```

---

## Best Practices

### 1. Organize Imports

```jac
# ✅ Good: Group imports logically
# Third-party libraries
cl import from antd {
    Button,
    Card
}

cl import from 'react-icons' {
    FaHome,
    FaUser
}

# Local Jac files
cl import from .header {
    Header
}

cl import from .utils {
    formatDate
}

# Local JavaScript files
cl import from .helpers {
    debounce
}
```

## Common Import Patterns

### Pattern 1: UI Component Library

```jac
"""Using a UI component library."""

cl import from antd {
    Button,
    Card,
    Input,
    Space,
    Layout
}

cl def Dashboard() -> any {
    return <Layout>
        <Card title="Dashboard">
            <Space direction="vertical">
                <Input placeholder="Search..." />
                <Button type="primary">Submit</Button>
            </Space>
        </Card>
    </Layout>;
}
```

### Pattern 2: Utility Functions

```jac
"""Using utility functions."""

cl import from .dateUtils {
    formatDate,
    getRelativeTime
}

cl import from .stringUtils {
    capitalize,
    truncate
}

cl def PostCard(post: dict) -> any {
    return <div>
        <h3>{capitalize(post.title)}</h3>
        <p>{truncate(post.content, 100)}</p>
        <small>{getRelativeTime(post.created_at)}</small>
    </div>;
}
```

### Pattern 3: Reusable Components

```jac
"""Using reusable components."""

cl import from .forms {
    TextInput,
    SelectInput,
    SubmitButton
}

cl import from .layout {
    Container,
    Row,
    Column
}

cl def ContactForm() -> any {
    return <Container>
        <Row>
            <Column>
                <TextInput placeholder="Name" />
                <TextInput placeholder="Email" />
                <SelectInput options={["Option 1", "Option 2"]} />
                <SubmitButton>Send</SubmitButton>
            </Column>
        </Row>
    </Container>;
}
```

---

## Troubleshooting

### Issue: Module Not Found

**Problem:**
```
Error: Cannot find module 'antd'
```

**Solution:**
```bash
# Install the missing package
npm install antd
```

### Issue: Import Not Working

**Problem:**
Imported component is `undefined`

**Solution:**
- Check the export name matches exactly
- Verify the file path is correct
- Ensure the file exports the component/function

### Issue: Type Errors

**Problem:**
Type errors with imported functions

**Solution:**
- Check function signatures match
- Verify parameter types
- Review library documentation

---

## Summary

- **Third-Party Libraries**: Install with `npm install`, import with `cl import from package_name`
- **Jac Files**: Import with `cl import from .module_name`
- **JavaScript Files**: Import with `cl import from .filename`
- **Best Practices**: Organize imports, import only what you need, document exports

Imports in Jac make it easy to use third-party libraries and organize your code! 🚀

