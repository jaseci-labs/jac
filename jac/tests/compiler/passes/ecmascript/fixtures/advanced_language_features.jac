"""Advanced Jac constructs combined fixture for ECMAScript generator tests."""

cl {
    # Lambdas and higher-order helpers
    def lambda_examples()  -> dict {
        adder = lambda  a: int , b: int: a + b;
        scaler = lambda  value: int , factor: int: value * factor;
        numbers = [1, 2, 3, 4];
        doubled = [scaler(n, 2) for n in numbers];
        filtered = [
            n
            for n in numbers
            if (keep := n % 2 == 0)
        ];
        return {"sum": adder(2, 5), "doubled": doubled, "filtered": filtered};
    }

    # Async / await usage
    async def fetch_value(value: int) -> int {
        return value;
    }

    async def async_pipeline(data: list) -> dict {
        total = 0;
        results = [];
        for item in data {
            response = await fetch_value(item);
            total += response;
            results.append(response);
        }
        status = "large" if total > 10 else "small";
        return {"total": total, "results": results, "status": status};
    }

    # Generators
    def generator_examples(limit: int) {
        index = 0;
        while index < limit {
            yield index * 3;
            index += 1;
        }
    }

    # Spread and rest patterns
    def spread_and_rest_examples()  -> dict {
        base = [1, 2, 3];
        extras = [4, 5];
        combined = [*base, *extras, 6];

        defaults = {"mode": "dev", "retries": 1};
        overrides = {"retries": 3, "timeout": 30};
        merged = {** defaults, ** overrides};

        def collect(label: str, *items: tuple, **options: dict) -> dict {
            return {"label": label, "items": list(items), "options": options};
        }

        bag = collect("demo", *combined, limit=10, strict=True);
        return {"combined": combined, "merged": merged, "bag": bag};
    }

    # Pattern matching / switch lowering
    def pattern_matching_examples(code: int, flag: bool) -> str {
        match code {
            case 200:
                return "ok";

            case 404 | 500:
                return "error";

            case _:
                if flag {
                    return "fallback";
                }
                return "unknown";

        }
    }

    # Template literals and complex expressions
    def template_literal_examples(user: str, score: int) -> str {
        status = "pass" if score >= 60 else "fail";
        return f"{user} scored {score} which is a {status}";
    }

    # Destructuring & rest patterns
    def advanced_destructuring()  -> dict {
        (first, *middle, last) = [10, 20, 30, 40, 50];
        point = (100, 200);
        (x, y) = point;
        settings = {"limits": {"max": 5}};
        limit = 0;
        if settings is not None and "limits" in settings {
            inner = settings["limits"];
            if inner is not None and "max" in inner {
                limit = inner["max"];
            }
        }
        return {
            "first": first,
            "middle": middle,
            "last": last,
            "point": (x, y),
            "limit": limit
        };
    }

    # Optional access simulations
    def optional_access_examples(payload: dict) -> dict {
        result = {"value": 0, "mode": "basic"};
        if payload is not None and "config" in payload {
            config = payload["config"];
            if config is not None and "value" in config {
                result["value"] = config["value"];
            }
            if config is not None and "mode" in config {
                result["mode"] = config["mode"];
            }
        }
        return result;
    }

    # Update expression stand-ins
    def update_expression_examples()  -> dict {
        counter = 0;
        for _ in range(5) {
            counter += 1;
        }

        index = 3;
        index -= 1;
        return {"counter": counter, "index": index};
    }

    # Do-while style loops
    def do_while_simulation(limit: int) -> int {
        total = 0;
        current = 0;
        while True {
            total += current;
            current += 1;
            if not (current < limit) {
                break;
            }
        }
        return total;
    }

    # Combined advanced report
    def build_advanced_report(values: list) -> dict {
        lambda_data = lambda_examples();
        spread_data = spread_and_rest_examples();
        optional = optional_access_examples({"config": {"value": 7, "mode": "strict"}});
        destructured = advanced_destructuring();

        async def gather_async()  -> dict {
            return await async_pipeline(values);
        }

        generator_list = [];
        for item in generator_examples(len(values)) {
            generator_list.append(item);
        }

        return {
            "lambda": lambda_data,
            "spread": spread_data,
            "optional": optional,
            "destructured": destructured,
            "pattern": pattern_matching_examples(404, False),
            "template": template_literal_examples("user", 72),
            "updates": update_expression_examples(),
            "loop": do_while_simulation(4),
            "generator": generator_list,
            "async_helper": gather_async
        };
    }

    def TodoList(filteredTodos: any, toggleTodo: any, deleteTodo: any) -> JsxElement {
        if filteredTodos.length == 0 {
            return <div
                style={{"padding": "20px", "textAlign": "center", "color": "#999"}}
            >
                No todos yet. Add one above!
            </div>;
        }

        return <div>
            {filteredTodos.map(
                lambda  todo: any  -> any{ return <TodoItem
                    key={todo._jac_id}
                    todo={todo}
                    toggleTodo={toggleTodo}
                    deleteTodo={props.deleteTodo}
                    children={props.children}
                />; }
            )}
        </div>;
    }

    def PropTodoList(props: any) -> JsxElement {
        if props.filteredTodos.length == 0 {
            return <div
                style={{"padding": "20px", "textAlign": "center", "color": "#999"}}
            >
                No todos yet. Add one above!
            </div>;
        }

        return <div>
            {props.filteredTodos.map(
                lambda  todo: any  -> any{ return <TodoItem
                    key={todo._jac_id}
                    todo={todo}
                    toggleTodo={props.toggleTodo}
                    deleteTodo={props.deleteTodo}
                    children={props.children}
                />; }
            )}
        </div>;
    }

    def `def(`from: str, `class: str) -> str {
        print("From is:", `from);
        print("Class is:", `class);
    }
}
