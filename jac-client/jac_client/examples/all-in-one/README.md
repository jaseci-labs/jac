# all-in-one

A Jac client-side application with React support showcasing file-based routing.

## Project Structure

```
all-in-one/
├── jac.toml              # Project configuration
├── main.jac              # Main application entry
├── components/           # Reusable components
│   └── Button.cl.jac     # Example Jac component
├── pages/                # File-based routing (auto-generated routes)
│   ├── layout.jac        # Root layout wrapper
│   ├── index.jac         # Home page (/)
│   ├── landing.jac       # /landing
│   ├── (auth)/           # Auth-protected route group
│   │   └── index.jac     # / (requires auth)
│   ├── (public)/         # Public route group
│   │   ├── login.jac     # /login
│   │   └── signup.jac    # /signup
│   ├── users/            # Nested routes
│   │   ├── index.jac     # /users
│   │   └── [id].jac      # /users/:id (dynamic)
│   ├── posts/            # Blog with slugs
│   │   ├── index.jac     # /posts
│   │   └── [slug].jac    # /posts/:slug (dynamic)
│   └── [...notFound].jac # Catch-all 404 page
├── assets/               # Static assets (images, fonts, etc.)
└── build/                # Build output (generated)
```

## Getting Started

Start the development server:

```bash
jac start main.jac
```

## File-Based Routing

Jac automatically generates routes based on files in the `pages/` directory. Just create a `.jac` file and export a `page` function.

### Basic Pages

| File                     | Route          | Description          |
| ------------------------ | -------------- | -------------------- |
| `pages/index.jac`        | `/`            | Home page            |
| `pages/about.jac`        | `/about`       | Static page          |
| `pages/landing.jac`      | `/landing`     | Landing page         |
| `pages/contact.jac`      | `/contact`     | Contact page         |

### Dynamic Routes with Parameters

Use square brackets `[param]` to create dynamic route segments:

| File                     | Route            | Example URLs                  |
| ------------------------ | ---------------- | ----------------------------- |
| `pages/users/[id].jac`   | `/users/:id`     | `/users/1`, `/users/42`       |
| `pages/posts/[slug].jac` | `/posts/:slug`   | `/posts/hello-world`          |

**Example: Dynamic User Profile** (`pages/users/[id].jac`):

```jac
cl import from "@jac/runtime" { Link, useParams }

cl {
    def:pub page -> JsxElement {
        params = useParams();
        userId = params.id;  # Access the dynamic parameter

        return
            <div>
                <h1>User Profile</h1>
                <p>Viewing user ID: {userId}</p>
                <Link to="/users">Back to Users</Link>
            </div>;
    }
}
```

**Example: Blog Post with Slug** (`pages/posts/[slug].jac`):

```jac
cl import from "@jac/runtime" { Link, useParams }

cl {
    def:pub page -> JsxElement {
        params = useParams();
        slug = params.slug;  # e.g., "getting-started-with-jac"

        return
            <article>
                <h1>Blog Post</h1>
                <p>Slug: {slug}</p>
                <Link to="/posts">All Posts</Link>
            </article>;
    }
}
```

### Catch-All Routes

Use `[...param]` for catch-all routes that match any path:

| File                        | Route | Matches                                |
| --------------------------- | ----- | -------------------------------------- |
| `pages/[...notFound].jac`   | `*`   | Any unmatched route (404 page)         |
| `pages/docs/[...path].jac`  | `*`   | `/docs/a`, `/docs/a/b/c`, etc.         |

**Example: 404 Not Found Page** (`pages/[...notFound].jac`):

```jac
cl import from "@jac/runtime" { Link }

cl {
    def:pub page -> JsxElement {
        return
            <div>
                <h1>404 - Page Not Found</h1>
                <p>The page you are looking for does not exist.</p>
                <Link to="/">Back to Home</Link>
            </div>;
    }
}
```

### Route Groups

Use parentheses `(groupName)` to organize routes without affecting the URL:

| Directory       | Effect                                       |
| --------------- | -------------------------------------------- |
| `(public)/`     | Groups public pages (no URL segment added)   |
| `(auth)/`       | Groups auth-protected pages + requires login |

**Example Structure:**

```
pages/
├── (public)/
│   ├── login.jac      # Route: /login
│   └── signup.jac     # Route: /signup
├── (auth)/
│   ├── index.jac      # Route: / (protected)
│   └── dashboard.jac  # Route: /dashboard (protected)
```

The `(auth)` group automatically wraps pages with authentication checks.

### Nested Routes

Create subdirectories for nested URL paths:

```
pages/
├── users/
│   ├── index.jac      # /users
│   └── [id].jac       # /users/:id
├── posts/
│   ├── index.jac      # /posts
│   └── [slug].jac     # /posts/:slug
├── settings/
│   ├── index.jac      # /settings
│   ├── profile.jac    # /settings/profile
│   └── security.jac   # /settings/security
```

### Layout Files

Create a `layout.jac` to wrap pages with shared UI (navigation, footer, etc.):

**Example: Root Layout** (`pages/layout.jac`):

```jac
cl import from "@jac/runtime" { Outlet }
cl import from ..components.navigation { Navigation }

cl {
    def:pub layout -> JsxElement {
        return
            <>
                <Navigation />
                <main style={{"maxWidth": "960px", "margin": "0 auto"}}>
                    <Outlet />  {/* Child routes render here */}
                </main>
                <footer>Footer content</footer>
            </>;
    }
}
```

### Index Files

`index.jac` files represent the default page for a directory:

| File                      | Route       |
| ------------------------- | ----------- |
| `pages/index.jac`         | `/`         |
| `pages/users/index.jac`   | `/users`    |
| `pages/posts/index.jac`   | `/posts`    |

## Routing Hooks

Import routing utilities from `@jac/runtime`:

```jac
cl import from "@jac/runtime" {
    Link,           # Navigation link component
    useNavigate,    # Programmatic navigation
    useParams,      # Access URL parameters
    useLocation,    # Get current location info
    Navigate,       # Redirect component
    Outlet          # Render child routes (layouts)
}
```

### useParams Example

```jac
params = useParams();
userId = params.id;      # From [id].jac
slug = params.slug;      # From [slug].jac
```

### useNavigate Example

```jac
navigate = useNavigate();

async def handleSubmit() -> None {
    # ... form logic
    navigate("/dashboard");  # Redirect after success
}
```

### useLocation Example

```jac
location = useLocation();
currentPath = location.pathname;  # e.g., "/users/123"
queryString = location.search;    # e.g., "?sort=name"
```

## Components

Create Jac components in `components/` as `.cl.jac` files and import them:

```jac
cl import from .components.Button { Button }
```

## Adding Dependencies

Add packages with the --npm flag:

```bash
jac add --npm react-router-dom
```
