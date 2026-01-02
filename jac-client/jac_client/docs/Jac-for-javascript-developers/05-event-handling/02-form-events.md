# Form Events

Learn how to handle form events in Jac.

---

## onChange Event

### Basic Input

**JavaScript/React:**

```jsx
<input onChange={(e) => setName(e.target.value)} />
```

**Jac:**

```jac
<input onChange={lambda e: any -> None { setName(e.target.value); }} />
```

---

## Text Input

```jac
def TextInput() -> any {
    [name, setName] = useState("");

    return (
        <div>
            <input
                type="text"
                value={name}
                onChange={lambda e: any -> None { setName(e.target.value); }}
                placeholder="Enter your name"
            />
            <p>Hello, {name or "stranger"}!</p>
        </div>
    );
}
```

---

## Multiple Inputs

```jac
def ContactForm() -> any {
    [name, setName] = useState("");
    [email, setEmail] = useState("");
    [message, setMessage] = useState("");

    return (
        <form>
            <input
                type="text"
                value={name}
                onChange={lambda e: any -> None { setName(e.target.value); }}
                placeholder="Name"
            />
            <input
                type="email"
                value={email}
                onChange={lambda e: any -> None { setEmail(e.target.value); }}
                placeholder="Email"
            />
            <textarea
                value={message}
                onChange={lambda e: any -> None { setMessage(e.target.value); }}
                placeholder="Message"
            />
        </form>
    );
}
```

---

## Form Submission

```jac
def LoginForm() -> any {
    [email, setEmail] = useState("");
    [password, setPassword] = useState("");
    [error, setError] = useState("");

    def handleSubmit(e: any) -> None {
        e.preventDefault();  # Prevent page reload

        if email == "" or password == "" {
            setError("Please fill all fields");
            return;
        }

        console.log("Logging in:", email);
        # Submit logic here
    }

    return (
        <form onSubmit={lambda e: any -> None { handleSubmit(e); }}>
            <input
                type="email"
                value={email}
                onChange={lambda e: any -> None { setEmail(e.target.value); }}
                placeholder="Email"
            />
            <input
                type="password"
                value={password}
                onChange={lambda e: any -> None { setPassword(e.target.value); }}
                placeholder="Password"
            />
            {error and <p style={{ "color": "red" }}>{error}</p>}
            <button type="submit">Login</button>
        </form>
    );
}
```

---

## Select Dropdown

```jac
def SelectExample() -> any {
    [selected, setSelected] = useState("option1");

    return (
        <div>
            <select
                value={selected}
                onChange={lambda e: any -> None { setSelected(e.target.value); }}
            >
                <option value="option1">Option 1</option>
                <option value="option2">Option 2</option>
                <option value="option3">Option 3</option>
            </select>
            <p>Selected: {selected}</p>
        </div>
    );
}
```

---

## Checkbox

### Single Checkbox

```jac
def Checkbox() -> any {
    [isChecked, setIsChecked] = useState(False);

    return (
        <label>
            <input
                type="checkbox"
                checked={isChecked}
                onChange={lambda: setIsChecked(not isChecked)}
            />
            I agree to the terms
        </label>
    );
}
```

### Multiple Checkboxes

```jac
def MultiCheckbox() -> any {
    [selected, setSelected] = useState([]);

    options = ["Apple", "Banana", "Cherry"];

    def handleChange(option: str) -> None {
        if option in selected {
            setSelected(selected.filter(lambda x: str -> bool { return x != option; }));
        } else {
            setSelected(selected.concat([option]));
        }
    }

    def renderOption(option: str, index: int) -> any {
        isChecked = option in selected;
        return (
            <label key={index} style={{ "display": "block" }}>
                <input
                    type="checkbox"
                    checked={isChecked}
                    onChange={lambda: handleChange(option)}
                />
                {option}
            </label>
        );
    }

    return (
        <div>
            {options.map(renderOption)}
            <p>Selected: {selected.join(", ") or "None"}</p>
        </div>
    );
}
```

---

## Radio Buttons

```jac
def RadioExample() -> any {
    [selected, setSelected] = useState("small");

    return (
        <div>
            <label>
                <input
                    type="radio"
                    name="size"
                    value="small"
                    checked={selected == "small"}
                    onChange={lambda e: any -> None { setSelected(e.target.value); }}
                />
                Small
            </label>
            <label>
                <input
                    type="radio"
                    name="size"
                    value="medium"
                    checked={selected == "medium"}
                    onChange={lambda e: any -> None { setSelected(e.target.value); }}
                />
                Medium
            </label>
            <label>
                <input
                    type="radio"
                    name="size"
                    value="large"
                    checked={selected == "large"}
                    onChange={lambda e: any -> None { setSelected(e.target.value); }}
                />
                Large
            </label>
            <p>Selected size: {selected}</p>
        </div>
    );
}
```

---

## Number Input

```jac
def NumberInput() -> any {
    [quantity, setQuantity] = useState(1);

    def handleChange(e: any) -> None {
        value = parseInt(e.target.value);
        if not isNaN(value) and value >= 0 {
            setQuantity(value);
        }
    }

    return (
        <div>
            <input
                type="number"
                value={quantity}
                onChange={lambda e: any -> None { handleChange(e); }}
                min="0"
                max="100"
            />
            <p>Quantity: {quantity}</p>
        </div>
    );
}
```

---

## Range Slider

```jac
def RangeSlider() -> any {
    [value, setValue] = useState(50);

    return (
        <div>
            <input
                type="range"
                min="0"
                max="100"
                value={value}
                onChange={lambda e: any -> None { setValue(parseInt(e.target.value)); }}
            />
            <p>Value: {value}</p>
        </div>
    );
}
```

---

## Focus and Blur Events

```jac
def FocusDemo() -> any {
    [isFocused, setIsFocused] = useState(False);
    [value, setValue] = useState("");

    return (
        <input
            value={value}
            onChange={lambda e: any -> None { setValue(e.target.value); }}
            onFocus={lambda: setIsFocused(True)}
            onBlur={lambda: setIsFocused(False)}
            style={{
                "border": ("2px solid blue") if isFocused else ("1px solid gray"),
                "padding": "10px"
            }}
            placeholder="Focus me!"
        />
    );
}
```

---

## Form with Object State

```jac
def FormWithObject() -> any {
    [form, setForm] = useState({
        "name": "",
        "email": "",
        "age": "",
        "newsletter": False
    });

    def handleChange(field: str, value: any) -> None {
        setForm({ **form, field: value });
    }

    def handleSubmit(e: any) -> None {
        e.preventDefault();
        console.log("Form data:", form);
    }

    return (
        <form onSubmit={lambda e: any -> None { handleSubmit(e); }}>
            <input
                value={form["name"]}
                onChange={lambda e: any -> None {
                    setForm({ **form, "name": e.target.value });
                }}
                placeholder="Name"
            />
            <input
                type="email"
                value={form["email"]}
                onChange={lambda e: any -> None {
                    setForm({ **form, "email": e.target.value });
                }}
                placeholder="Email"
            />
            <input
                type="number"
                value={form["age"]}
                onChange={lambda e: any -> None {
                    setForm({ **form, "age": e.target.value });
                }}
                placeholder="Age"
            />
            <label>
                <input
                    type="checkbox"
                    checked={form["newsletter"]}
                    onChange={lambda: setForm({ **form, "newsletter": not form["newsletter"] })}
                />
                Subscribe to newsletter
            </label>
            <button type="submit">Submit</button>
        </form>
    );
}
```

---

## Summary

| Event    | Usage                                                                |
| -------- | -------------------------------------------------------------------- |
| onChange | `onChange={lambda e: any -> None { setValue(e.target.value); }}`     |
| onSubmit | `onSubmit={lambda e: any -> None { e.preventDefault(); submit(); }}` |
| onFocus  | `onFocus={lambda: setFocused(True)}`                                 |
| onBlur   | `onBlur={lambda: setFocused(False)}`                                 |
| Checkbox | `onChange={lambda: setChecked(not checked)}`                         |

---

## Next

- [Keyboard Events](03-keyboard-events.md) - onKeyDown, onKeyUp
