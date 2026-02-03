"""Complete SPA example using reactive state and routing."""

cl import from "@jac/runtime" {
    createSignal,
    createState,
    createRouter,
    Route,
    Link,
}

cl glob _appState = createState({"user": None, "loggedIn": False});
cl glob appState = _appState[0];
cl glob setAppState = _appState[1];

cl {
    # Counter component using reactive signal
    def CounterApp()  -> JsxElement {
        [count, setCount] = createSignal(0);

        def increment()  -> None {
            setCount(count() + 1);
        }

        def decrement()  -> None {
            setCount(count() - 1);
        }

        return <div class="counter-app">
            <h1>
                Counter: {count()}
            </h1>
            <button
                onclick={increment}
            >
                +
            </button>
            <button
                onclick={decrement}
            >
                -
            </button>
        </div>;
    }

    # Todo list component using reactive state
    def TodoApp()  -> JsxElement {
        [todos, setTodos] = createState({"items": [], "nextId": 1});

        def addTodo(text: str) -> None {
            currentState = todos();
            newItem = {"id": currentState.nextId, "text": text, "done": False};
            newItems = [*currentState.items, newItem];
            setTodos({"items": newItems, "nextId": currentState.nextId + 1});
        }

        return <div class="todo-app">
            <h1>
                Todos
            </h1>
            <div>
                Total: {todos().items.length}
            </div>
        </div>;
    }

    # Home component
    def Home()  -> JsxElement {
        return <div>
            <h1>
                Home
            </h1>
            <nav>
                <Link href="/counter">
                    Counter App
                </Link>
                <Link href="/todos">
                    Todo App
                </Link>
            </nav>
        </div>;
    }

    # Main app with router
    def App()  -> JsxElement {
        router = createRouter(
            [
                Route(path="/", component=Home),
                Route(path="/counter", component=CounterApp),
                Route(path="/todos", component=TodoApp),

            ],
            defaultRoute="/"
        );

        return <div class="app">
            {router.render()}
        </div>;
    }

    # Test that demonstrates no manual renderJsxTree calls needed
    def test_spa_no_manual_rendering()  -> dict {
        # The app component just returns JSX
        # The framework handles all rendering automatically
        component = App();

        return {
            "hasComponent": component != None,
            "componentTag": component.tag,
            "noManualRenderNeeded": True
        };
    }

    # Test reactive counter
    def test_counter_reactivity()  -> dict {
        [count, setCount] = createSignal(0);

        initial = count();
        setCount(5);
        after5 = count();
        setCount(10);
        after10 = count();

        return {"initial": initial, "after5": after5, "after10": after10};
    }

    # Entry point
    def test_spa_integration()  -> dict {
        return {
            "noManualRender": test_spa_no_manual_rendering(),
            "counterReactivity": test_counter_reactivity()
        };
    }
}
