# Authentication

Add user login, signup, and protected routes to your Jac application.

> **Prerequisites**
>
> - Completed: [Backend Integration](backend.md)
> - Time: ~30 minutes

---

## Overview

Jac authentication uses:

1. **Backend walkers** - Handle login, signup, token validation
2. **Auth context** - Share auth state across components
3. **Protected routes** - Restrict access to authenticated users

---

## Backend: User Model

```jac
import from hashlib { sha256 }
import from datetime { datetime }
import uuid;

node User {
    has id: str;
    has email: str;
    has password_hash: str;
    has name: str;
    has created_at: str;
    has token: str = "";

    def verify_password(password: str) -> bool {
        return self.password_hash == sha256(password.encode()).hexdigest();
    }

    def generate_token() -> str {
        self.token = str(uuid.uuid4());
        return self.token;
    }
}
```

---

## Backend: Auth Walkers

### Signup Walker

```jac
walker:pub signup {
    has email: str;
    has password: str;
    has name: str;

    can register with Root entry {
        # Check if user exists
        for user in [-->](?:User) {
            if user.email == self.email {
                report {"success": False, "error": "Email already registered"};
                return;
            }
        }

        # Create new user
        new_user = User(
            id=str(uuid.uuid4()),
            email=self.email,
            password_hash=sha256(self.password.encode()).hexdigest(),
            name=self.name,
            created_at=datetime.now().isoformat()
        );

        root ++> new_user;
        token = new_user.generate_token();

        report {
            "success": True,
            "user": {
                "id": new_user.id,
                "email": new_user.email,
                "name": new_user.name
            },
            "token": token
        };
    }
}
```

### Login Walker

```jac
walker:pub login {
    has email: str;
    has password: str;

    can authenticate with Root entry {
        for user in [-->](?:User) {
            if user.email == self.email {
                if user.verify_password(self.password) {
                    token = user.generate_token();
                    report {
                        "success": True,
                        "user": {
                            "id": user.id,
                            "email": user.email,
                            "name": user.name
                        },
                        "token": token
                    };
                    return;
                } else {
                    report {"success": False, "error": "Invalid password"};
                    return;
                }
            }
        }
        report {"success": False, "error": "User not found"};
    }
}
```

### Validate Token Walker

```jac
walker:pub validate_token {
    has token: str;

    can validate with Root entry {
        for user in [-->](?:User) {
            if user.token == self.token and self.token != "" {
                report {
                    "valid": True,
                    "user": {
                        "id": user.id,
                        "email": user.email,
                        "name": user.name
                    }
                };
                return;
            }
        }
        report {"valid": False};
    }
}
```

### Logout Walker

```jac
walker:pub logout {
    has token: str;

    can invalidate with Root entry {
        for user in [-->](?:User) {
            if user.token == self.token {
                user.token = "";
                report {"success": True};
                return;
            }
        }
        report {"success": False};
    }
}
```

---

## Frontend: Auth Context

### Create the Auth Provider

```jac
cl {
    import from react { createContext, useContext, useEffect }
    import from jac_client { callWalker }

    # Create context
    glob AuthContext = createContext(None);

    # Auth Provider component
    def:pub AuthProvider(props: dict) -> JsxElement {
        has user: any = None;
        has token: str = "";
        has loading: bool = True;

        # Check for existing session on mount
        useEffect(lambda -> None {
            stored_token = localStorage.getItem("auth_token");
            if stored_token {
                validate_session(stored_token);
            } else {
                loading = False;
            }
        }, []);

        async def validate_session(t: str) -> None {
            result = await callWalker("validate_token", {"token": t});
            if result["valid"] {
                user = result["user"];
                token = t;
            } else {
                localStorage.removeItem("auth_token");
            }
            loading = False;
        }

        async def login_user(email: str, password: str) -> dict {
            result = await callWalker("login", {
                "email": email,
                "password": password
            });

            if result["success"] {
                user = result["user"];
                token = result["token"];
                localStorage.setItem("auth_token", token);
            }

            return result;
        }

        async def signup_user(email: str, password: str, name: str) -> dict {
            result = await callWalker("signup", {
                "email": email,
                "password": password,
                "name": name
            });

            if result["success"] {
                user = result["user"];
                token = result["token"];
                localStorage.setItem("auth_token", token);
            }

            return result;
        }

        async def logout_user() -> None {
            await callWalker("logout", {"token": token});
            localStorage.removeItem("auth_token");
            user = None;
            token = "";
        }

        value = {
            "user": user,
            "token": token,
            "loading": loading,
            "isAuthenticated": user != None,
            "login": login_user,
            "signup": signup_user,
            "logout": logout_user
        };

        return <AuthContext.Provider value={value}>
            {props.children}
        </AuthContext.Provider>;
    }

    # Hook to use auth
    def use_auth() -> any {
        return useContext(AuthContext);
    }
}
```

---

## Frontend: Login Form

```jac
cl {
    def:pub LoginForm() -> JsxElement {
        has email: str = "";
        has password: str = "";
        has error: str = "";
        has loading: bool = False;

        auth = use_auth();

        async def handle_submit() -> None {
            loading = True;
            error = "";

            result = await auth.login(email, password);

            if not result["success"] {
                error = result["error"];
            }
            # On success, auth context updates automatically

            loading = False;
        }

        return <form className="auth-form">
            <h2>Login</h2>

            {error and <div className="error">{error}</div>}

            <input
                type="email"
                value={email}
                onChange={lambda e: any -> None { email = e.target.value; }}
                placeholder="Email"
                required={True}
            />

            <input
                type="password"
                value={password}
                onChange={lambda e: any -> None { password = e.target.value; }}
                placeholder="Password"
                required={True}
            />

            <button
                type="button"
                onClick={lambda -> None { handle_submit(); }}
                disabled={loading}
            >
                {("Logging in..." if loading else "Login")}
            </button>

            <p>
                Don't have an account?
                <a href="/signup">Sign up</a>
            </p>
        </form>;
    }
}
```

---

## Frontend: Signup Form

```jac
cl {
    def:pub SignupForm() -> JsxElement {
        has name: str = "";
        has email: str = "";
        has password: str = "";
        has confirm_password: str = "";
        has error: str = "";
        has loading: bool = False;

        auth = use_auth();

        async def handle_submit() -> None {
            # Validation
            if password != confirm_password {
                error = "Passwords don't match";
                return;
            }

            if len(password) < 8 {
                error = "Password must be at least 8 characters";
                return;
            }

            loading = True;
            error = "";

            result = await auth.signup(email, password, name);

            if not result["success"] {
                error = result["error"];
            }

            loading = False;
        }

        return <form className="auth-form">
            <h2>Create Account</h2>

            {error and <div className="error">{error}</div>}

            <input
                type="text"
                value={name}
                onChange={lambda e: any -> None { name = e.target.value; }}
                placeholder="Full Name"
                required={True}
            />

            <input
                type="email"
                value={email}
                onChange={lambda e: any -> None { email = e.target.value; }}
                placeholder="Email"
                required={True}
            />

            <input
                type="password"
                value={password}
                onChange={lambda e: any -> None { password = e.target.value; }}
                placeholder="Password"
                required={True}
            />

            <input
                type="password"
                value={confirm_password}
                onChange={lambda e: any -> None { confirm_password = e.target.value; }}
                placeholder="Confirm Password"
                required={True}
            />

            <button
                type="button"
                onClick={lambda -> None { handle_submit(); }}
                disabled={loading}
            >
                {("Creating account..." if loading else "Sign Up")}
            </button>

            <p>
                Already have an account?
                <a href="/login">Login</a>
            </p>
        </form>;
    }
}
```

---

## Protected Routes

### ProtectedRoute Component

```jac
cl {
    def:pub ProtectedRoute(props: dict) -> JsxElement {
        auth = use_auth();

        # Still loading auth state
        if auth.loading {
            return <div className="loading">Loading...</div>;
        }

        # Not authenticated - redirect to login
        if not auth.isAuthenticated {
            # Using window.location for simple redirect
            window.location.href = "/login";
            return <div>Redirecting...</div>;
        }

        # Authenticated - render children
        return <>{props.children}</>;
    }
}
```

### Using Protected Routes

```jac
cl {
    def:pub Dashboard() -> JsxElement {
        auth = use_auth();

        return <ProtectedRoute>
            <div className="dashboard">
                <h1>Welcome, {auth.user.name}!</h1>
                <p>Email: {auth.user.email}</p>
                <button onClick={lambda -> None { auth.logout(); }}>
                    Logout
                </button>
            </div>
        </ProtectedRoute>;
    }
}
```

---

## Complete App Structure

```jac
cl {
    import from jac_client { Router, Route }

    def:pub app() -> JsxElement {
        return <AuthProvider>
            <Router>
                <nav>
                    <NavBar />
                </nav>

                <main>
                    <Route path="/" element={<Home />} />
                    <Route path="/login" element={<LoginForm />} />
                    <Route path="/signup" element={<SignupForm />} />
                    <Route path="/dashboard" element={<Dashboard />} />
                    <Route path="/profile" element={<Profile />} />
                </main>
            </Router>
        </AuthProvider>;
    }

    def:pub NavBar() -> JsxElement {
        auth = use_auth();

        return <div className="navbar">
            <a href="/">Home</a>

            {(
                <span>
                    <a href="/dashboard">Dashboard</a>
                    <span>Hi, {auth.user.name}</span>
                    <button onClick={lambda -> None { auth.logout(); }}>
                        Logout
                    </button>
                </span>
            ) if auth.isAuthenticated else (
                <span>
                    <a href="/login">Login</a>
                    <a href="/signup">Sign Up</a>
                </span>
            )}
        </div>;
    }
}
```

---

## Authenticated API Calls

### Passing Token to Walkers

```jac
cl {
    import from jac_client { callWalker }

    def:pub UserData() -> JsxElement {
        has data: any = None;
        auth = use_auth();

        async def fetch_private_data() -> None {
            # Include token in walker call
            result = await callWalker("get_user_data", {
                "token": auth.token
            });
            data = result;
        }

        return <div>
            <button onClick={lambda -> None { fetch_private_data(); }}>
                Fetch My Data
            </button>
            {data and <pre>{JSON.stringify(data, None, 2)}</pre>}
        </div>;
    }
}
```

### Protected Walker

```jac
walker get_user_data {
    has token: str;

    can fetch with Root entry {
        # Validate token first
        for user in [-->](?:User) {
            if user.token == self.token and self.token != "" {
                # Token valid - return user's private data
                report {
                    "email": user.email,
                    "name": user.name,
                    "created_at": user.created_at,
                    # ... other private fields
                };
                return;
            }
        }

        # Invalid token
        report {"error": "Unauthorized"};
    }
}
```

---

## Security Best Practices

### 1. Password Hashing

Always hash passwords before storing:

```jac
import from hashlib { sha256, pbkdf2_hmac }
import os;

def hash_password(password: str) -> str {
    salt = os.urandom(32);
    key = pbkdf2_hmac('sha256', password.encode(), salt, 100000);
    return salt.hex() + key.hex();
}

def verify_password(password: str, stored: str) -> bool {
    salt = bytes.fromhex(stored[:64]);
    stored_key = stored[64:];
    key = pbkdf2_hmac('sha256', password.encode(), salt, 100000);
    return key.hex() == stored_key;
}
```

### 2. Token Expiration

Add expiration to tokens:

```jac
node User {
    has token: str = "";
    has token_expires: str = "";

    def generate_token() -> str {
        import from datetime { datetime, timedelta }
        self.token = str(uuid.uuid4());
        self.token_expires = (datetime.now() + timedelta(days=7)).isoformat();
        return self.token;
    }

    def is_token_valid() -> bool {
        if self.token == "" {
            return False;
        }
        import from datetime { datetime }
        return datetime.now().isoformat() < self.token_expires;
    }
}
```

### 3. HTTPS Only

In production, always use HTTPS for auth endpoints.

---

## Key Takeaways

| Concept | Implementation |
|---------|----------------|
| User model | Node with hashed password |
| Login/Signup | Walker endpoints |
| Auth state | React Context + localStorage |
| Protected routes | Check auth before rendering |
| Token auth | Pass token with API calls |

---

## Next Steps

- [Routing](routing.md) - Multi-page applications
- [Backend Integration](backend.md) - More API patterns
