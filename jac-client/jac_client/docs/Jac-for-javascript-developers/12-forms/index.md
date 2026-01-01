# Forms

Handling forms in JAC-Client.

---

## Controlled Inputs

```jac
def ContactForm() -> any {
    [name, setName] = useState("");
    [email, setEmail] = useState("");
    [message, setMessage] = useState("");

    def handleSubmit(e: any) -> None {
        e.preventDefault();
        console.log("Submitted:", name, email, message);
    }

    return (
        <form onSubmit={handleSubmit}>
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
            <button type="submit">Send</button>
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
        <select
            value={selected}
            onChange={lambda e: any -> None { setSelected(e.target.value); }}
        >
            <option value="option1">Option 1</option>
            <option value="option2">Option 2</option>
            <option value="option3">Option 3</option>
        </select>
    );
}
```

---

## Checkbox

```jac
def CheckboxExample() -> any {
    [isChecked, setIsChecked] = useState(False);

    return (
        <label>
            <input
                type="checkbox"
                checked={isChecked}
                onChange={lambda e: any -> None { setIsChecked(e.target.checked); }}
            />
            I agree to terms
        </label>
    );
}
```

---

## Form with Validation

```jac
def ValidatedForm() -> any {
    [email, setEmail] = useState("");
    [error, setError] = useState("");

    def handleSubmit(e: any) -> None {
        e.preventDefault();

        if not email.includes("@") {
            setError("Invalid email");
            return;
        }

        setError("");
        console.log("Valid email:", email);
    }

    return (
        <form onSubmit={handleSubmit}>
            <input
                type="text"
                value={email}
                onChange={lambda e: any -> None { setEmail(e.target.value); }}
                placeholder="Email"
            />
            {error and <p style={{"color": "red"}}>{error}</p>}
            <button type="submit">Submit</button>
        </form>
    );
}
```

---

## React Hook Form

```jac
cl import from react-hook-form { useForm }

cl {
    def FormWithHookForm() -> any {
        formMethods = useForm();
        register = formMethods["register"];
        handleSubmit = formMethods["handleSubmit"];
        errors = formMethods["formState"]["errors"];

        def onSubmit(data: dict) -> None {
            console.log(data);
        }

        return (
            <form onSubmit={handleSubmit(onSubmit)}>
                <input {...register("email", {"required": True})} />
                {errors["email"] and <span>Email required</span>}

                <input {...register("password", {"minLength": 6})} type="password" />
                {errors["password"] and <span>Min 6 characters</span>}

                <button type="submit">Submit</button>
            </form>
        );
    }
}
```

---

## Next

- [Routing](../13-routing/) - Navigation
