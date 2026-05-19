# little-x

A Jac client-side application with React support.

## Project Structure

```
little-x/
├── jac.toml              # Project configuration
├── main.jac              # Entry point (combines frontend + backend)
├── frontend.cl.jac       # `app` shell: shared state + server handlers
├── frontend.impl.jac     # Handler implementations
├── server.jac            # Object-spatial social graph backend
├── components/           # Reusable UI components
│   ├── Sidebar.cl.jac        # Left navigation
│   ├── RightSidebar.cl.jac   # Search, trending, suggestions
│   ├── MobileNav.cl.jac      # Mobile bottom nav
│   ├── FeedTab.cl.jac        # Home feed
│   ├── ExploreTab.cl.jac     # Discover users
│   ├── ChannelsTab.cl.jac    # Channels (owns its own form state)
│   ├── ProfileTab.cl.jac     # Profile view
│   ├── Composer.cl.jac       # Reusable post box
│   ├── WelcomeBanner.cl.jac  # First-run banner
│   ├── TweetCard.cl.jac      # Single tweet
│   ├── AuthForm.cl.jac       # Login / signup
│   └── Button.cl.jac         # Example Jac component
├── assets/               # Static assets (images, fonts, etc.)
└── build/                # Build output (generated)
```

The `app` component in `frontend.cl.jac` owns shared state and the walker
handlers, then passes data and callbacks down to the components above.
Tab switching goes through a single `navigate(tab)` handler.

## Getting Started

Start the development server:

```bash
jac start main.jac
```

## Components

Create Jac components in `components/` as `.cl.jac` files and import them:

```jac
cl import from .components.Button { Button }
```

## Adding Dependencies

Add npm packages with the --cl flag:

```bash
jac add --cl react-router-dom
```
