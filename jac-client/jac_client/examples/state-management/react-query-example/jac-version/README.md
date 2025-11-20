# React Query in Jac - Data Fetching Made Easy

A beginner-friendly guide to using React Query (TanStack Query) with Jac/OneLang.

## What is React Query?

React Query handles data fetching, caching, and synchronization automatically. Instead of manually managing loading states, errors, and refetching, React Query does it all for you!

## What Does This Example Do?

This app demonstrates:

- **Fetching data** - Load a list of users from an API
- **Viewing details** - Select a user to see their full info
- **Creating data** - Add new users with a form
- **Auto-sync** - Everything updates automatically when data changes!

## Quick Start

```bash
npm install
npm install @tanstack/react-query
jac serve app.jac
```

Open your browser and try:

1. Click "Refetch" to reload users
2. Select different users from the dropdown
3. Create a new user - watch it appear instantly!

## How It Works

### 1. Setup QueryClient (queryClientSetup.js)

React Query needs a QueryClient to manage caches. Since Jac doesn't support the `new` keyword yet, we create it in a JS file:

```javascript
import { QueryClient } from "@tanstack/react-query";

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5000, // Data stays fresh for 5 seconds
    },
  },
});
```

### 2. Wrap Your App with QueryClientProvider (app.jac)

Provide the QueryClient to your entire app:

```jac
cl import from .queryClientSetup { queryClient }
cl import from "@tanstack/react-query" { QueryClientProvider }

cl {
    def app() -> any {
        return <QueryClientProvider client={queryClient}>
            {/* Your components here */}
        </QueryClientProvider>;
    }
}
```

### 3. Fetch Data with useQuery

Use `useQuery` to fetch and cache data:

```jac
cl import from "@tanstack/react-query" { useQuery }

cl {
    def UsersList() -> any {
        # Fetch users
        queryResult = useQuery({
            "queryKey": ["users"],        # Unique cache key
            "queryFn": fetchUsers          # Function that returns data
        });

        # Extract what you need
        data = queryResult.data;
        isLoading = queryResult.isLoading;
        error = queryResult.error;

        # Handle states
        if isLoading {
            return <div>Loading...</div>;
        }

        if error {
            return <div>Error: {error.message}</div>;
        }

        # Render data
        return <div>
            {data.map(lambda user: any -> any {
                return <div key={user.id}>{user.name}</div>;
            })}
        </div>;
    }
}
```

**What happens:**

- React Query calls `fetchUsers()` automatically
- Data is cached with key `["users"]`
- Component shows loading state while fetching
- When data arrives, component re-renders with data
- If you navigate away and come back, data loads instantly from cache!

### 4. Mutate Data with useMutation

Use `useMutation` to create, update, or delete data:

```jac
cl import from "@tanstack/react-query" { useMutation, useQueryClient }

cl {
    def CreateUserForm() -> any {
        let [name, setName] = useState("");
        let [email, setEmail] = useState("");

        # Get query client to invalidate cache
        client = useQueryClient();

        # Setup mutation
        mutation = useMutation({
            "mutationFn": createUser,     # Function to call
            "onSuccess": lambda data: any -> None {
                # After success, refetch users list
                client.invalidateQueries({"queryKey": ["users"]});
                # Clear form
                setName("");
                setEmail("");
            }
        });

        # Handle form submit
        def handleSubmit(e: any) -> None {
            e.preventDefault();
            mutation.mutate({"name": name, "email": email});
        }

        return <form onSubmit={handleSubmit}>
            <input value={name} onChange={lambda e -> None { setName(e.target.value); }} />
            <input value={email} onChange={lambda e -> None { setEmail(e.target.value); }} />
            <button type="submit">
                {mutation.isPending and "Creating..." or "Create User"}
            </button>
        </form>;
    }
}
```

**What happens:**

- User fills form and clicks submit
- `mutation.mutate()` calls `createUser()` with the data
- While creating, `mutation.isPending` is `true` (button shows "Creating...")
- On success, `client.invalidateQueries()` marks `["users"]` as stale
- React Query automatically refetches users
- New user appears in the list!

### 5. Dependent Queries

Fetch data based on other data:

```jac
cl {
    def UserDetail() -> any {
        let [selectedUserId, setSelectedUserId] = useState(1);

        # Fetch user detail based on selectedUserId
        def userQueryFn() -> any {
            return fetchUserById(selectedUserId);
        }

        queryResult = useQuery({
            "queryKey": ["user", selectedUserId],  # Cache per user ID
            "queryFn": userQueryFn,
            "enabled": selectedUserId != None       # Only fetch if ID exists
        });

        data = queryResult.data;
        isFetching = queryResult.isFetching;

        return <div>
            <select onChange={lambda e -> None { setSelectedUserId(e.target.value); }}>
                {/* Options here */}
            </select>

            {isFetching and <div>Loading...</div> or <div>{data.name}</div>}
        </div>;
    }
}
```

**What happens:**

- When user selects a different ID, `selectedUserId` changes
- Query key becomes `["user", newId]`
- React Query checks cache for that user
- If cached, shows instantly; otherwise fetches
- Old user data doesn't show while new user loads (`isFetching` handles this)

## File Structure

```
├── app.jac                # Main components and UI
├── queryClientSetup.js    # Creates QueryClient (needs JS for 'new' keyword)
└── mockApi.js             # Mock API functions (needs JS for Promise 'new')
```

## Key Concepts

### QueryKey - The Cache ID

```jac
"queryKey": ["users"]           # All users
"queryKey": ["user", 5]         # User with ID 5
"queryKey": ["posts", "recent"] # Recent posts
```

Query keys identify cached data. Same key = same cache.

### Stale vs Fresh

- **Fresh** - Data was fetched recently (within `staleTime`)
- **Stale** - Data is old and should be refetched
- React Query automatically refetches stale data in the background

### Invalidating Queries

```jac
client.invalidateQueries({"queryKey": ["users"]});
```

Marks data as stale and triggers refetch. Use after mutations to update lists.

## Why Use React Query?

**Without React Query:**

```jac
let [users, setUsers] = useState([]);
let [loading, setLoading] = useState(False);
let [error, setError] = useState(None);

async def loadUsers() -> None {
    setLoading(True);
    try {
        result = await fetchUsers();
        setUsers(result);
    } catch e {
        setError(e);
    } finally {
        setLoading(False);
    }
}

useEffect(lambda -> None { loadUsers(); }, []);
```

**With React Query:**

```jac
queryResult = useQuery({
    "queryKey": ["users"],
    "queryFn": fetchUsers
});
```

React Query handles loading, error, caching, refetching, and synchronization automatically!

## Common Patterns

### Refetch on Demand

```jac
queryResult = useQuery({...});
refetch = queryResult.refetch;

<button onClick={lambda -> None { refetch(); }}>Reload</button>
```

### Show Loading State

```jac
if isLoading {
    return <div>⏳ Loading...</div>;
}
```

### Show Error State

```jac
if error {
    return <div>❌ Error: {error.message}</div>;
}
```

### Optimistic Updates

```jac
mutation = useMutation({
    "mutationFn": createUser,
    "onSuccess": lambda -> None {
        client.invalidateQueries({"queryKey": ["users"]});
    }
});
```

## Try This

1. **Create a user** - Fill the form and submit. Watch it appear in the list.
2. **Select users** - Notice the dropdown updates with new users automatically.
3. **Check cache** - Select a user, then select another, then go back. The first user loads instantly (from cache)!
4. **Refetch manually** - Click the "Refetch" button to reload data.

## Next Steps

- Add pagination with `useInfiniteQuery`
- Implement optimistic updates
- Add React Query DevTools for debugging
- Explore background refetching options

Happy coding with Jac! 🚀
