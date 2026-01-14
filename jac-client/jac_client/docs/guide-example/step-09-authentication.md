# Step 9: Adding Authentication

> **Quick Tip:** Each step has two parts. **Part 1** shows you what to build. **Part 2** explains why it works. Want to just build? Skip all Part 2 sections!

In this step, you'll add user authentication so each person has their own private todos!

---

## Part 1: Building the App

### Step 9.1: Import Authentication Functions

Add these imports at the top of your `cl` block:

```jac
# Note: useState is auto-injected, only useEffect needs explicit import
cl import from react {useEffect}
cl import from "@jac-client/utils" {
    jacLogin,
    jacSignup,
    jacLogout,
    jacIsLoggedIn
}

cl {
    # ... your components
}
```

> **Note:** The `useState` import is automatically injected when you use `has` variables in `cl {}` blocks or `.cl.jac` files. You only need to explicitly import other hooks like `useEffect`.

### Step 9.2: Create the Login Page

Add this component:

```jac
def LoginPage() -> any {
    [username, setUsername] = useState("");
    [password, setPassword] = useState("");
    [error, setError] = useState("");

    async def handleLogin(e: any) -> None {
        e.preventDefault();
        setError("");

        if not username or not password {
            setError("Please fill in all fields");
            return;
        }

        success = await jacLogin(username, password);
        if success {
            console.log("Login successful!");
        } else {
            setError("Invalid credentials");
        }
    }

    def handleUsernameChange(e: any) -> None {
        setUsername(e.target.value);
    }

    def handlePasswordChange(e: any) -> None {
        setPassword(e.target.value);
    }

    errorDisplay = None;
    if error {
        errorDisplay = <div style={{
            "color": "#dc2626",
            "fontSize": "14px",
            "marginBottom": "10px"
        }}>
            {error}
        </div>;
    }

    return <div style={{
        "minHeight": "100vh",
        "display": "flex",
        "alignItems": "center",
        "justifyContent": "center",
        "background": "#f5f5f5"
    }}>
        <div style={{
            "background": "#ffffff",
            "padding": "30px",
            "borderRadius": "8px",
            "width": "280px",
            "boxShadow": "0 2px 4px rgba(0,0,0,0.1)"
        }}>
            <h2 style={{"marginBottom": "20px"}}>Login</h2>
            <form onSubmit={handleLogin}>
                <input
                    type="text"
                    value={username}
                    onChange={handleUsernameChange}
                    placeholder="Username"
                    style={{
                        "width": "100%",
                        "padding": "8px",
                        "marginBottom": "10px",
                        "border": "1px solid #ddd",
                        "borderRadius": "4px",
                        "boxSizing": "border-box"
                    }}
                />
                <input
                    type="password"
                    value={password}
                    onChange={handlePasswordChange}
                    placeholder="Password"
                    style={{
                        "width": "100%",
                        "padding": "8px",
                        "marginBottom": "10px",
                        "border": "1px solid #ddd",
                        "borderRadius": "4px",
                        "boxSizing": "border-box"
                    }}
                />
                {errorDisplay}
                <button
                    type="submit"
                    style={{
                        "width": "100%",
                        "padding": "8px",
                        "background": "#3b82f6",
                        "color": "#ffffff",
                        "border": "none",
                        "borderRadius": "4px",
                        "cursor": "pointer",
                        "fontWeight": "600"
                    }}
                >
                    Login
                </button>
            </form>
            <p style={{
                "textAlign": "center",
                "marginTop": "12px",
                "fontSize": "14px"
            }}>
                Need an account? Sign up link here
            </p>
        </div>
    </div>;
}
```

### Step 9.3: Create the Signup Page

Add this component:

```jac
def SignupPage() -> any {
    [username, setUsername] = useState("");
    [password, setPassword] = useState("");
    [error, setError] = useState("");

    async def handleSignup(e: any) -> None {
        e.preventDefault();
        setError("");

        if not username or not password {
            setError("Please fill in all fields");
            return;
        }

        result = await jacSignup(username, password);
        if result["success"] {
            console.log("Signup successful!");
        } else {
            setError(result["error"] if result["error"] else "Signup failed");
        }
    }

    def handleUsernameChange(e: any) -> None {
        setUsername(e.target.value);
    }

    def handlePasswordChange(e: any) -> None {
        setPassword(e.target.value);
    }

    errorDisplay = None;
    if error {
        errorDisplay = <div style={{
            "color": "#dc2626",
            "fontSize": "14px",
            "marginBottom": "10px"
        }}>
            {error}
        </div>;
    }

    return <div style={{
        "minHeight": "100vh",
        "display": "flex",
        "alignItems": "center",
        "justifyContent": "center",
        "background": "#f5f5f5"
    }}>
        <div style={{
            "background": "#ffffff",
            "padding": "30px",
            "borderRadius": "8px",
            "width": "280px",
            "boxShadow": "0 2px 4px rgba(0,0,0,0.1)"
        }}>
            <h2 style={{"marginBottom": "20px"}}>Sign Up</h2>
            <form onSubmit={handleSignup}>
                <input
                    type="text"
                    value={username}
                    onChange={handleUsernameChange}
                    placeholder="Username"
                    style={{
                        "width": "100%",
                        "padding": "8px",
                        "marginBottom": "10px",
                        "border": "1px solid #ddd",
                        "borderRadius": "4px",
                        "boxSizing": "border-box"
                    }}
                />
                <input
                    type="password"
                    value={password}
                    onChange={handlePasswordChange}
                    placeholder="Password"
                    style={{
                        "width": "100%",
                        "padding": "8px",
                        "marginBottom": "10px",
                        "border": "1px solid #ddd",
                        "borderRadius": "4px",
                        "boxSizing": "border-box"
                    }}
                />
                {errorDisplay}
                <button
                    type="submit"
                    style={{
                        "width": "100%",
                        "padding": "8px",
                        "background": "#3b82f6",
                        "color": "#ffffff",
                        "border": "none",
                        "borderRadius": "4px",
                        "cursor": "pointer",
                        "fontWeight": "600"
                    }}
                >
                    Sign Up
                </button>
            </form>
            <p style={{
                "textAlign": "center",
                "marginTop": "12px",
                "fontSize": "14px"
            }}>
                Have an account? Login link here
            </p>
        </div>
    </div>;
}
```

### Step 9.4: Test the Pages

For now, update your `app()` function to show the login page:

```jac
def:pub app() -> any {
    return <LoginPage />;
}
```

**Try it!** You should see a login form. Try logging in (it won't work yet because we haven't created an account).

Change it to show signup:

```jac
def:pub app() -> any {
    return <SignupPage />;
}
```

**Create an account!** Enter a username and password, then click "Sign Up". Check the browser console - you should see "Signup successful!"

### Step 9.5: Protect Your Todo Page

Now let's make the todo page require login. Rename your current `app` function to `TodosPage`:

```jac
# Rename app to TodosPage
def TodosPage() -> any {
    # Check if user is logged in
    if not jacIsLoggedIn() {
        return <div style={{"padding": "20px"}}>
            <h1>Please login to view todos</h1>
        </div>;
    }

    # ... all your existing todo code (useState, useEffect, functions, return)
}
```

**What we did:**

- Renamed `app` to `TodosPage`
- Added a check: if not logged in, show a message
- If logged in, show the todos

**Try it!** You should see the "Please login" message (we'll add routing next to make this work properly).

---

**⏭ Want to skip the theory?** Jump to [Step 10: Routing](./step-10-routing.md)

---

## Part 2: Understanding the Concepts

### What is Authentication?

Authentication = Proving who you are

**Real-world analogy:**

- **ID card** - You show it to prove your identity
- **Username/Password** - Same thing, but digital!

### Jac's Built-in Auth Functions

```jac
# 1. Sign up a new user
result = await jacSignup(username, password);

# 2. Log in an existing user
success = await jacLogin(username, password);

# 3. Log out
jacLogout();

# 4. Check if logged in
if jacIsLoggedIn() {
    // User is logged in
}
```

### How jacSignup Works

```jac
result = await jacSignup("alice", "password123");

// Returns:
{
    "success": true,   // or false if failed
    "error": null      // or error message
}
```

**What happens:**

1. Jac creates a new user account
2. Hashes the password (secure!)
3. Creates a session token
4. Stores token in browser
5. Returns success/failure

### How jacLogin Works

```jac
success = await jacLogin("alice", "password123");

// Returns:
true  // Login successful
false // Login failed
```

**What happens:**

1. Jac checks if user exists
2. Verifies password (securely)
3. Creates a session token
4. Stores token in browser
5. Returns true/false

### How jacLogout Works

```jac
jacLogout();
```

**What happens:**

1. Removes session token from browser
2. You're now logged out
3. Next API call will fail (not authenticated)

### How jacIsLoggedIn Works

```jac
if jacIsLoggedIn() {
    // User is logged in
} else {
    // User is NOT logged in
}
```

**What it checks:**

1. Is there a valid session token?
2. Has it expired?
3. Returns true/false

### Form Handling with onSubmit

```jac
<form onSubmit={handleLogin}>
    <input type="text" />
    <button type="submit">Login</button>
</form>
```

**Key points:**

- `onSubmit` fires when form is submitted
- Submitting = clicking button OR pressing Enter
- Always call `e.preventDefault()` to stop page reload

```jac
async def handleLogin(e: any) -> None {
    e.preventDefault();  # Stop page reload!
    // Your login logic
}
```

### Password Input Type

```jac
<input type="password" />  # Hides characters (•••)
<input type="text" />      # Shows characters (abc)
```

Always use `type="password"` for passwords!

### Error Handling

```jac
[error, setError] = useState("");

# Show error if exists
{(<div style={{"color": "red"}}>{error}</div>) if error else None}

# Set error
setError("Invalid credentials");

# Clear error
setError("");
```

### Conditional Rendering for Auth

```jac
def TodosPage() -> any {
    if not jacIsLoggedIn() {
        return <div>Please login</div>;
    }

    # User is logged in, show todos
    return <div>Your todos here</div>;
}
```

This pattern protects pages from unauthorized access!

### User Isolation

**Magic happens automatically!**

When you add authentication to walkers:

```jac
walker read_todos {
    # No special code needed - Jac handles it!
    can read with `root entry {
        visit [-->(`?Todo)];
    }
}
```

Jac automatically:

- Uses the logged-in user's root node
- Each user sees only their own todos
- No way to access other users' data

### Session Persistence

Sessions persist across page refreshes!

```jac
# User logs in
await jacLogin("alice", "password123");

# Refresh page
# jacIsLoggedIn() still returns true!

# Sessions last until:
# 1. User logs out (jacLogout)
# 2. Session expires (configurable)
# 3. User clears browser data
```

---

## What You've Learned

- What authentication is and why it's important
- Using `jacSignup` to create accounts
- Using `jacLogin` to log users in
- Using `jacLogout` to log users out
- Using `jacIsLoggedIn` to check auth status
- Creating login and signup forms
- Handling form submission
- Protecting pages with auth checks
- User isolation (each user sees only their data)

---

## Common Issues

### Issue: "Signup failed"

**Check:**

- Is the username already taken? Try a different one
- Are username/password not empty?
- Check browser console for errors

### Issue: Login says "Invalid credentials"

**Check:**

- Did you create an account first?
- Is the username/password correct?
- Usernames are case-sensitive!

### Issue: jacIsLoggedIn() always returns false

**Check:**

- Did you successfully login/signup?
- Check browser console for errors
- Try logging in again

### Issue: Can't create multiple accounts

**Solution:** Each username can only be used once. Try different usernames:

- alice, bob, carol
- user1, user2, user3
- test_alice, test_bob

---

## Quick Exercise

Try adding a "Remember me" message:

```jac
def LoginPage() -> any {
    [username, setUsername] = useState("");
    [password, setPassword] = useState("");

    # Check if already logged in
    if jacIsLoggedIn() {
        return <div style={{"padding": "20px"}}>
            <h2>You're already logged in!</h2>
            <button onClick={lambda -> None { jacLogout(); }}>
                Logout
            </button>
        </div>;
    }

    # ... rest of login form
}
```

---

## Next Step

Great! You now have authentication, but you're still showing only one page at a time.

In the next step, we'll add **routing** so users can navigate between login, signup, and todos pages!

 **[Continue to Step 10: Routing](./step-10-routing.md)**
