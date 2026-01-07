# Step 10: Adding Routing

> **Quick Tip:** Each step has two parts. **Part 1** shows you what to build. **Part 2** explains why it works. Want to just build? Skip all Part 2 sections!

In this step, you'll add multiple pages to your app so users can navigate between login, signup, and todos!

---

## Part 1: Building the App

### Step 10.1: Import Routing Components

Update your imports:

```jac
cl import from react {useState, useEffect}
cl import from "@jac-client/utils" {
    Router,
    Routes,
    Route,
    Link,
    Navigate,
    useNavigate,
    jacSignup,
    jacLogin,
    jacLogout,
    jacIsLoggedIn
}

cl {
    # ... your components
}
```

### Step 10.2: Add Navigation Links to Login Page

Update your `LoginPage` to include a link to signup:

```jac
# In LoginPage, replace the last <p> tag with:
<p style={{
    "textAlign": "center",
    "marginTop": "12px",
    "fontSize": "14px"
}}>
    Need an account? <Link to="/signup">Sign up</Link>
</p>
```

### Step 10.3: Add Navigation Links to Signup Page

Update your `SignupPage`:

```jac
# In SignupPage, replace the last <p> tag with:
<p style={{
    "textAlign": "center",
    "marginTop": "12px",
    "fontSize": "14px"
}}>
    Have an account? <Link to="/login">Login</Link>
</p>
```

### Step 10.4: Add Navigation After Login/Signup

Update the login handler to navigate to todos after successful login:

```jac
# In LoginPage
async def handleLogin(e: any) -> None {
    e.preventDefault();
    setError("");

    if not username or not password {
        setError("Please fill in all fields");
        return;
    }

    success = await jacLogin(username, password);
    if success {
        window.location.href = "/cl/app#/todos";  # Navigate to todos
    } else {
        setError("Invalid credentials");
    }
}
```

Update the signup handler:

```jac
# In SignupPage
async def handleSignup(e: any) -> None {
    e.preventDefault();
    setError("");

    if not username or not password {
        setError("Please fill in all fields");
        return;
    }

    result = await jacSignup(username, password);
    if result["success"] {
        window.location.href = "/cl/app#/todos";  # Navigate to todos
    } else {
        setError(result["error"] if result["error"] else "Signup failed");
    }
}
```

### Step 10.5: Create a Navigation Component

Add this component to show navigation at the top:

```jac
def Navigation() -> any {
    isLoggedIn = jacIsLoggedIn();

    if isLoggedIn {
        return <nav style={{
            "padding": "12px 24px",
            "background": "#3b82f6",
            "color": "#ffffff",
            "display": "flex",
            "justifyContent": "space-between"
        }}>
            <div style={{"fontWeight": "600"}}>Todo App</div>
            <div style={{"display": "flex", "gap": "16px"}}>
                <Link to="/todos" style={{
                    "color": "#ffffff",
                    "textDecoration": "none"
                }}>
                    Todos
                </Link>
                <button
                    onClick={lambda e: any -> None {
                        e.preventDefault();
                        jacLogout();
                        window.location.href = "/cl/app#/login";
                    }}
                    style={{
                        "background": "none",
                        "color": "#ffffff",
                        "border": "1px solid #ffffff",
                        "padding": "2px 10px",
                        "borderRadius": "4px",
                        "cursor": "pointer"
                    }}
                >
                    Logout
                </button>
            </div>
        </nav>;
    }

    return <nav style={{
        "padding": "12px 24px",
        "background": "#3b82f6",
        "color": "#ffffff",
        "display": "flex",
        "justifyContent": "space-between"
    }}>
        <div style={{"fontWeight": "600"}}>Todo App</div>
        <div style={{"display": "flex", "gap": "16px"}}>
            <Link to="/login" style={{
                "color": "#ffffff",
                "textDecoration": "none"
            }}>
                Login
            </Link>
            <Link to="/signup" style={{
                "color": "#ffffff",
                "textDecoration": "none"
            }}>
                Sign Up
            </Link>
        </div>
    </nav>;
}
```

### Step 10.6: Update TodosPage to Redirect if Not Logged In

Update your `TodosPage`:

```jac
def TodosPage() -> any {
    # Redirect to login if not logged in
    if not jacIsLoggedIn() {
        return <Navigate to="/login" />;
    }

    # ... all your existing todo code
}
```

### Step 10.7: Create a Home Page

Add this simple home page:

```jac
def HomePage() -> any {
    if jacIsLoggedIn() {
        return <Navigate to="/todos" />;
    }
    return <Navigate to="/login" />;
}
```

### Step 10.8: Set Up Router in app()

Now, update your `app` function to use the router:

```jac
def:pub app() -> any {
    return <Router>
        <div style={{"fontFamily": "system-ui, sans-serif"}}>
            <Navigation />
            <Routes>
                <Route path="/" element={<HomePage />} />
                <Route path="/login" element={<LoginPage />} />
                <Route path="/signup" element={<SignupPage />} />
                <Route path="/todos" element={<TodosPage />} />
            </Routes>
        </div>
    </Router>;
}
```

**Try it!**

1. Go to `http://localhost:8000/cl/app` - you'll be redirected to login
2. Click "Sign up" - goes to signup page
3. Create an account - redirects to todos
4. Click "Logout" - redirects to login
5. Try manually going to `/cl/app#/todos` while logged out - redirects to login!

---

**⏭ Want to skip the theory?** Jump to [Step 11: Final Integration](./step-11-final.md)

---

## Part 2: Understanding the Concepts

### What is Routing?

Routing = Different URLs show different pages

**Traditional websites:**

- `/login` → Server sends login.html
- `/todos` → Server sends todos.html
- Every click = full page reload

**Single-Page Apps (SPAs):**

- `/login` → JavaScript shows login component
- `/todos` → JavaScript shows todos component
- No page reload = instant and smooth!

### Router Components

```jac
<Router>           # Container for all routing
  <Routes>         # Groups route definitions
    <Route />      # Defines one route
  </Routes>
</Router>
```

**Think of it like:**

```python
# Python routing (Flask)
@app.route("/login")
def login():
    return render_template("login.html")

# Jac routing
<Route path="/login" element={<LoginPage />} />
```

### The Router Setup

```jac
<Router>
    <div>
        <Navigation />  # Shows on all pages
        <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/login" element={<LoginPage />} />
        </Routes>
    </div>
</Router>
```

**What happens:**

- `Router` manages the current URL
- `Navigation` is always visible
- `Routes` shows ONE matching route
- Components render based on URL

### Route Definitions

```jac
<Route path="/login" element={<LoginPage />} />
```

**Breakdown:**

- `path="/login"` - URL pattern to match
- `element={<LoginPage />}` - Component to show (must be JSX!)

**Important:** Use `element={<Component />}` not `element={Component}`

### Link Component

```jac
<Link to="/login">Go to Login</Link>
```

**vs regular anchor tag:**

```jac
#  Wrong - causes page reload
<a href="/login">Go to Login</a>

#  Correct - no page reload
<Link to="/login">Go to Login</Link>
```

`Link` updates the URL without reloading the page!

### Navigate Component

```jac
def TodosPage() -> any {
    if not jacIsLoggedIn() {
        return <Navigate to="/login" />;
    }
    // Show todos
}
```

**Purpose:** Redirect programmatically

**When to use:**

- Protecting routes (if not logged in, redirect)
- After form submission
- Conditional redirects

### useNavigate Hook

```jac
navigate = useNavigate();

async def handleLogin() -> None {
    success = await jacLogin(username, password);
    if success {
        navigate("/todos");  # Navigate programmatically
    }
}
```

**Use when:** You need to navigate from JavaScript code (not from JSX)

### URL Structure in Jac

```
http://localhost:8000/cl/app#/todos
                       ^^^^^^^  ^^^^^^
                       Jac app  Route
```

- `/cl/app` - Your Jac app
- `#/todos` - Client-side route (hash routing)

### Protected Routes Pattern

```jac
def ProtectedPage() -> any {
    if not jacIsLoggedIn() {
        return <Navigate to="/login" />;
    }

    # User is authenticated, show page
    return <div>Protected content</div>;
}
```

This pattern:

1. Checks authentication
2. Redirects if not logged in
3. Shows content if logged in

### Conditional Navigation

```jac
def Navigation() -> any {
    isLoggedIn = jacIsLoggedIn();

    if isLoggedIn {
        return <nav>
            <Link to="/todos">Todos</Link>
            <button onClick={logout}>Logout</button>
        </nav>;
    }

    return <nav>
        <Link to="/login">Login</Link>
        <Link to="/signup">Sign Up</Link>
    </nav>;
}
```

Shows different links based on login status!

### Route Matching

Routes are matched **in order**:

```jac
<Routes>
    <Route path="/" element={<HomePage />} />
    <Route path="/login" element={<LoginPage />} />
    <Route path="/todos" element={<TodosPage />} />
</Routes>
```

- URL `/` → Shows `HomePage`
- URL `/login` → Shows `LoginPage`
- URL `/todos` → Shows `TodosPage`
- URL `/other` → Shows nothing (we could add a 404 page)

### Common Routing Patterns

**Pattern 1: Auto-redirect based on auth**

```jac
def HomePage() -> any {
    if jacIsLoggedIn() {
        return <Navigate to="/todos" />;
    }
    return <Navigate to="/login" />;
}
```

**Pattern 2: Logout and redirect**

```jac
def handleLogout() -> None {
    jacLogout();
    navigate("/login");
}
```

**Pattern 3: Conditional links**

```jac
{(
    <Link to="/dashboard">Dashboard</Link>
) if jacIsLoggedIn() else (
    <Link to="/login">Login</Link>
)}
```

---

## What You've Learned

- What client-side routing is
- Setting up Router, Routes, and Route
- Creating navigation with Link
- Programmatic navigation with Navigate
- Protected routes with authentication checks
- Conditional navigation based on auth status
- Common routing patterns

---

## Common Issues

### Issue: Links don't work

**Check:**

- Is everything wrapped in `<Router>`?
- Are you using `<Link>` not `<a>`?
- Is the `to` prop correct? `to="/login"` not `href="/login"`

### Issue: Page reloads when clicking links

**Cause:** Using `<a href="">` instead of `<Link to="">`

```jac
#  Wrong
<a href="/login">Login</a>

#  Correct
<Link to="/login">Login</Link>
```

### Issue: Navigate not working

**Check:**

- Is `<Navigate>` inside a component rendered by `<Route>`?
- Is it wrapped in `<Router>`?

### Issue: Can't access protected page when logged in

**Check:**

- Is `jacIsLoggedIn()` returning true?
- Did you successfully login?
- Check browser console for errors

---

## Quick Exercise

Try adding a 404 page for unknown routes:

```jac
def NotFoundPage() -> any {
    return <div style={{
        "textAlign": "center",
        "padding": "50px"
    }}>
        <h1>404 - Page Not Found</h1>
        <Link to="/">Go Home</Link>
    </div>;
}

# Add as last route (catches everything else)
<Route path="*" element={<NotFoundPage />} />
```

---

## Next Step

Congratulations! You've learned all the key concepts. Now let's put everything together into the **complete, final app**!

 **[Continue to Step 11: Final Integration](./step-11-final.md)**
