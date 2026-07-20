# Jac vs Traditional Stack: A Side-by-Side Comparison

A traditional full-stack web application requires separate projects, frameworks, and glue code -- a Python backend, a React frontend, an ORM, API route definitions, and serialization logic. In Jac, you write all of this in a single file: nodes are your data model, walkers are your API endpoints, and a `cl { }` block (or `.cl.jac` file) holds your UI components. This comparison builds the same Todo app both ways so you can see the difference.

---

## Jac Implementation

```jac
# This single jac program is a fullstack application
node Todo {
    has title: str,
        done: bool;
}

def:pub get_todos -> list {
    root ++> [
        Todo("build startup", False),
        Todo("raise funding", False),
        Todo("change the world", False)
    ];
    return [{"title": t.title, "done": t.done} for t in [root-->][?:Todo]];
}

cl def:pub app() -> JsxElement {
    has items: list = [];

    async can with entry {
        items = await get_todos();
    }

    return
        <div>
            {[<div key={item.title}>
                <input type="checkbox" checked={item.done} />
                {item.title}
            </div> for item in items]}
        </div>;
}
```

**What this file provides:**

- `node Todo` defines the data model with automatic persistence to a graph database
- `def:pub get_todos` creates an HTTP API endpoint
- `cl def:pub app()` defines a React component that runs on the client
- `has items` becomes `useState` in the generated JavaScript
- `async can with entry` becomes `useEffect(() => {...}, [])` for loading data on mount
- `with entry` seeds initial data into the graph database
- `await get_todos()` handles the HTTP request to the backend

---

## Traditional Stack Implementation

The equivalent functionality using Python, FastAPI, SQLite, TypeScript, and React.

---

### Backend

#### `backend/requirements.txt`

```
fastapi==0.109.0
uvicorn[standard]==0.27.0
sqlalchemy==2.0.25
pydantic==2.5.3
```

**Purpose:** Lists Python package dependencies. Python's package manager (pip) uses this file to install FastAPI (web framework), Uvicorn (ASGI server), SQLAlchemy (database ORM), and Pydantic (data validation).

---

#### `backend/database.py`

```python
"""Database configuration and session management."""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

SQLALCHEMY_DATABASE_URL = "sqlite:///./todos.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """Dependency to get database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

**Purpose:** Configures the SQLite database connection, creates the SQLAlchemy engine, sets up session management, and provides a dependency function for database access in API endpoints.

---

#### `backend/models.py`

```python
"""SQLAlchemy models and Pydantic schemas."""
from sqlalchemy import Column, Integer, String, Boolean
from pydantic import BaseModel
from database import Base


class TodoModel(Base):
    """SQLAlchemy model for Todo items."""
    __tablename__ = "todos"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    done = Column(Boolean, default=False)


class TodoResponse(BaseModel):
    """Pydantic schema for Todo response."""
    title: str
    done: bool

    class Config:
        from_attributes = True
```

**Purpose:** Defines the data structure twice: once as a SQLAlchemy model for database operations, and once as a Pydantic schema for API response serialization.

---

#### `backend/main.py`

```python
"""FastAPI Todo Application - Backend API."""
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from database import engine, get_db, Base
from models import TodoModel, TodoResponse


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database on startup."""
    Base.metadata.create_all(bind=engine)
    db = next(get_db())
    if db.query(TodoModel).count() == 0:
        initial_todos = [
            TodoModel(title="build startup", done=False),
            TodoModel(title="raise funding", done=False),
            TodoModel(title="change the world", done=False),
        ]
        db.add_all(initial_todos)
        db.commit()
    db.close()
    yield


app = FastAPI(title="Todo API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/todos", response_model=list[TodoResponse])
def get_todos(db: Session = Depends(get_db)):
    """Get all todos."""
    return db.query(TodoModel).all()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

**Purpose:** Creates the FastAPI application, configures CORS middleware for frontend access, defines the API endpoint, handles database initialization on startup, and seeds initial data.

---

### Frontend

#### `frontend/package.json`

```json
{
  "name": "todo-app-frontend",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.48",
    "@types/react-dom": "^18.2.18",
    "@vitejs/plugin-react": "^4.2.1",
    "typescript": "^5.3.3",
    "vite": "^5.0.12"
  }
}
```

**Purpose:** Node.js package manifest that lists JavaScript/TypeScript dependencies (React, TypeScript, Vite) and defines npm scripts for development and building.

---

#### `frontend/tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

**Purpose:** Configures the TypeScript compiler with target JavaScript version, module resolution strategy, JSX handling, and type-checking rules.

---

#### `frontend/tsconfig.node.json`

```json
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true,
    "strict": true
  },
  "include": ["vite.config.ts"]
}
```

**Purpose:** Separate TypeScript configuration for Node.js-executed files like `vite.config.ts`, which run in a different environment than browser code.

---

#### `frontend/vite.config.ts`

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
})
```

**Purpose:** Configures Vite build tool with React plugin support and sets up a development proxy to forward `/api` requests to the backend server.

---

#### `frontend/index.html`

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Todo App</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

**Purpose:** HTML entry point that provides the root DOM element where React mounts and loads the TypeScript entry point.

---

#### `frontend/src/types.ts`

```typescript
export interface Todo {
  title: string;
  done: boolean;
}
```

**Purpose:** TypeScript interface definitions for data structures. These must be kept in sync with the backend Pydantic schemas.

---

#### `frontend/src/api.ts`

```typescript
import { Todo } from './types';

export async function getTodos(): Promise<Todo[]> {
  const response = await fetch('/api/todos');
  if (!response.ok) {
    throw new Error('Failed to fetch todos');
  }
  return response.json();
}
```

**Purpose:** API client function that wraps the fetch call to communicate with the backend, handling HTTP requests and error checking.

---

#### `frontend/src/App.tsx`

```tsx
import { useState, useEffect } from 'react';
import { Todo } from './types';
import { getTodos } from './api';

export default function App() {
  const [items, setItems] = useState<Todo[]>([]);

  useEffect(() => {
    async function loadTodos() {
      const todos = await getTodos();
      setItems(todos);
    }
    loadTodos();
  }, []);

  return (
    <div>
      {items.map((item) => (
        <div key={item.title}>
          <input type="checkbox" checked={item.done} readOnly />
          {item.title}
        </div>
      ))}
    </div>
  );
}
```

**Purpose:** Main React component that manages state with `useState`, loads data on mount with `useEffect`, and renders the todo list.

---

#### `frontend/src/main.tsx`

```tsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

**Purpose:** React application entry point that mounts the App component into the DOM root element.

---

### What Each Approach Requires

| Component | Traditional Stack | Jac |
|-----------|-------------------|-----|
| Database configuration | Explicit setup | Automatic |
| ORM model | Required | `node` declaration |
| API serialization schema | Required (Pydantic) | Automatic |
| API route definition | Required (decorator) | `def:pub` |
| CORS configuration | Required | Automatic |
| Frontend type definitions | Required | Shared with backend |
| API client code | Required | Automatic RPC |
| React state setup | `useState` hook | `has` declaration |
| Data loading effect | `useEffect` hook | `can with entry` |
| Build tooling config | Required (Vite, TS) | Automatic |
| HTML entry point | Required | Automatic |

---

## Counting What Matters

Line count is the least of it. The sharper comparison is structural: how many
notations you maintain, how many times one fact is written down, and how many
pairs of artifacts are kept consistent only by discipline -- because a pair no
tool can check is where the next bug comes from.

| Measure | Traditional stack (this page) | Jac |
|---|---|---|
| General-purpose languages | 3 (Python, TypeScript, SQL via the ORM) | 1 |
| Auxiliary dialects | 5 (JSON ×2, TS config, HTML, `requirements.txt`) | 0 in this app (1 `jac.toml` in a full project) |
| Copies of the `Todo` shape | 3 (SQLAlchemy model, Pydantic schema, TS interface) | 1 (`node Todo`) |
| Boundary-only artifacts (files or config sections) | 5 (`database.py`, `types.ts`, `api.ts`, the `vite.config.ts` proxy section, the CORS block in `main.py`) | 0 |
| Artifact pairs synced by discipline alone | at least 4 (model↔schema, schema↔interface, route↔client, proxy↔server port) | 0 -- one compiler sees every pair |

That last row is the load-bearing one. Every "kept in sync by hand" pair is a
place where meaning is re-encoded and **no verifier has jurisdiction over the
encoding** -- the comment in `types.ts` above says it out loud: "These must be
kept in sync with the backend Pydantic schemas." Kept in sync *by whom*? By
convention, by review, and ultimately by `grep`. The whole-program type
checker of a traditional stack is `grep`.

## The Rename Test

Don't take the table's word for it -- run the experiment. Rename `title` to
`name` on the Todo type in each stack, then run every checker the stack has to
exhaustion, and count what gets caught.

**Traditional stack.** Rename the column and `TodoModel.title`. Now:

- `mypy`/`pyright` flags backend *code* that uses the old attribute -- but not
  the Pydantic `TodoResponse`, which is a separate class and still says
  `title`, and still type-checks fine on its own.
- `tsc` flags frontend uses of `Todo.title` -- *if* you remember to edit
  `types.ts`, which no tool connects to the backend. If you don't, everything
  compiles green on both sides.
- Nothing checks the wire. The first sign of a missed copy is `undefined`
  rendering in the browser, or a 500 in production -- discovered at runtime,
  by whoever is on call.
- The database migration is a fourth, separately authored artifact.

**Jac.** Rename `title` on `node Todo`. Run `jac check`. Every stale use --
the `def:pub` function on the server, the `item.title` in the JSX on the
client -- is a **compile error with a file and line number**, because the
client and server are the same program checked by the same compiler against
one declaration. When it builds again, it works again. (Persisted data
migrates by rule rather than by hand -- see
[Persistence & Schema Migration](../reference/persistence.md).)

This is the practical meaning of Jac's design bet: not that boundaries
disappear, but that every boundary crossing lands inside the reach of the
compiler -- across tiers, as this page shows, and equally across the package
ecosystems (PyPI, npm, C) a real application draws on, which enter through a
plain `import` instead of a wrapper. The property has a name, *synechic*,
and the full argument is on [The Ideas Behind Jac](ideas-behind-jac.md).
