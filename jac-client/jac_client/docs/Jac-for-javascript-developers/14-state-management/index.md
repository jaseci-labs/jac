# State Management

External state libraries in JAC-Client.

---

## Zustand (Recommended)

Simple, minimal boilerplate:

```jac
cl import from zustand { create }

cl {
    # Create store
    useStore = create(lambda set: any -> dict {
        return {
            "count": 0,
            "increment": lambda -> None {
                set(lambda state: dict -> dict {
                    return {"count": state["count"] + 1};
                });
            },
            "decrement": lambda -> None {
                set(lambda state: dict -> dict {
                    return {"count": state["count"] - 1};
                });
            },
            "reset": lambda -> None {
                set({"count": 0});
            }
        };
    });

    def Counter() -> any {
        count = useStore(lambda state: dict -> int { return state["count"]; });
        increment = useStore(lambda state: dict -> any { return state["increment"]; });
        decrement = useStore(lambda state: dict -> any { return state["decrement"]; });

        return (
            <div>
                <p>Count: {count}</p>
                <button onClick={increment}>+</button>
                <button onClick={decrement}>-</button>
            </div>
        );
    }
}
```

---

## Zustand with Persist

```jac
cl import from zustand { create }
cl import from zustand/middleware { persist }

cl {
    useStore = create(
        persist(
            lambda set: any -> dict {
                return {
                    "user": None,
                    "setUser": lambda user: dict -> None {
                        set({"user": user});
                    }
                };
            },
            {"name": "user-storage"}
        )
    );
}
```

---

## Redux Toolkit

```jac
cl import from @reduxjs/toolkit { configureStore, createSlice }
cl import from react-redux { Provider, useSelector, useDispatch }

cl {
    # Create slice
    counterSlice = createSlice({
        "name": "counter",
        "initialState": {"value": 0},
        "reducers": {
            "increment": lambda state: dict -> None {
                state["value"] = state["value"] + 1;
            },
            "decrement": lambda state: dict -> None {
                state["value"] = state["value"] - 1;
            }
        }
    });

    # Create store
    store = configureStore({
        "reducer": {
            "counter": counterSlice["reducer"]
        }
    });

    def Counter() -> any {
        count = useSelector(lambda state: dict -> int {
            return state["counter"]["value"];
        });
        dispatch = useDispatch();
        actions = counterSlice["actions"];

        return (
            <div>
                <p>{count}</p>
                <button onClick={lambda: dispatch(actions["increment"]())}>+</button>
                <button onClick={lambda: dispatch(actions["decrement"]())}>-</button>
            </div>
        );
    }

    def app() -> any {
        return (
            <Provider store={store}>
                <Counter />
            </Provider>
        );
    }
}
```

---

## React Query (Server State)

```jac
cl import from @tanstack/react-query { QueryClient, QueryClientProvider, useQuery }

cl {
    queryClient = QueryClient();

    def UserList() -> any {
        query = useQuery({
            "queryKey": ["users"],
            "queryFn": lambda -> any {
                return fetch("/api/users").then(lambda r: any -> any {
                    return r.json();
                });
            }
        });

        if query["isLoading"] {
            return <p>Loading...</p>;
        }

        if query["error"] {
            return <p>Error loading users</p>;
        }

        def renderUser(user: dict, index: int) -> any {
            return <li key={user["id"]}>{user["name"]}</li>;
        }

        return <ul>{query["data"].map(renderUser)}</ul>;
    }

    def app() -> any {
        return (
            <QueryClientProvider client={queryClient}>
                <UserList />
            </QueryClientProvider>
        );
    }
}
```

---

## Summary

| Library | Best For |
|---------|----------|
| Zustand | Simple, small apps |
| Redux | Complex, large apps |
| React Query | Server state |

---

## Next

- [Authentication](../15-authentication/) - Login/logout
