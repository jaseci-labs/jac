"""Combined core Jac constructs for ECMAScript generator tests."""

cl {
    glob al_counter: int = 0;

    # Basic functions and control flow
    def add(a: int, b: int) -> int {
        return a + b;
    }

    def greet(name: str = "World") -> str {
        return "Hello, " + name;
    }

    def classify_number(value: int) -> str {
        if value < 0 {
            return "negative";
        } elif value == 0 {
            return "zero";
        }
        return "positive";
    }

    def fibonacci(n: int) -> int {
        if n <= 1 {
            return n;
        }
        return fibonacci(n - 1) + fibonacci(n - 2);
    }

    def addItem() -> None {
        newItem = { "id": Date.now(), "text": "Item " + (items.length + 1), "done": False };
        newItems = items.concat([newItem]);
        setItems(newItems);
    }

    def formatCompact(num: float) -> str {
        if num >= 1000000 {
            divided = num / 1000000;
            return (Math.round(divided * 10) / 10).toString().concat("M");
        }
        if num >= 1000 {
            divided = num / 1000;
            return (Math.round(divided * 10) / 10).toString().concat("K");
        }
        return Math.round(num).toString();
    }

    def loop_examples(limit: int) -> int {
        total = 0;
        array = [1, 2, 3, 4, 5];
        for i in array {
            if i % 2 == 0 {
                total += i;
                continue;
            }
            total += i * 2;
        }

        for i = 0 to i < limit by i += 1 {
            if i == 3 {
                break;
            }
            total += i;
        }

        counter = limit;
        while counter > 0 {
            total -= 1;
            counter -= 1;
        }
        return total;
    }

    # Data structures and assignments
    def collection_examples()  -> dict {
        numbers = [1, 2, 3, 4];
        person = {"name": "Alice", "age": 30};
        matrix = [[1, 2], [3, 4]];
        history = {"first": numbers[0], "last": numbers[-1]};
        return {
            "numbers": numbers,
            "person": person,
            "matrix": matrix,
            "history": history
        };
    }

    def destructuring_examples()  -> dict {
        (x, y) = (10, 20);
        [a, b, c] = [1, 2, 3];
        (head, *tail) = [5, 6, 7, 8];
        result = (size := len(tail)) + x + y + a + b + c;
        return {
            "tuple": (x, y),
            "list": [a, b, c],
            "tail": tail,
            "result": result,
            "size": size
        };
    }

    def assignment_examples(value: int) -> dict {
        current = value;
        current += 5;
        current -= 2;
        current *= 3;
        current /= 2;
        parity = status := current % 2;
        return {"current": current, "status": status, "parity": parity};
    }

    # Exception handling
    def safe_division(a: int, b: int) -> float {
        global global_counter;
        try {
            return a / b;
        } except ZeroDivisionError as err {
            global_counter += 1;
            return 0.0;
        } finally {
            global_counter += 1;
        }
    }

    # Boolean and comparison helpers
    def compare_values(x: int, y: int) -> dict {
        return {
            "lt": x < y,
            "le": x <= y,
            "eq": x == y,
            "ne": x != y,
            "ge": x >= y,
            "gt": x > y,
            "logic": (x < y and y < 100) or not (x == y)
        };
    }

    # Switch case test cases
    def switch_case(fruit: str) {
        switch fruit {
            case "apple":
                print("Matched case for value: apple");
                break;

            case "banana":

            case "orange":
                print("Matched case for value: banana, orange");

            case "grape":
                print("Matched case for value: grape");
                break;

            default:
                print("Matched case for value: kiwi");

        }
    }

    # Object definitions
    obj Person {
        has name: str;
        has age: int = 0;

        def describe -> str {
            return self.name + " (" + str(self.age) + ")";
        }
    }

    obj Employee(Person) {
        has role: str = "Engineer";

        def describe -> str {
            return self.name + " - " + self.role;
        }
    }

    obj Calculator {
        has value: float = 0.0;

        def add(x: float) -> float {
            self.value += x;
            return self.value;
        }

        def subtract(x: float) -> float {
            self.value -= x;
            return self.value;
        }

        def reset {
            self.value = 0.0;
        }
    }

    obj MathUtils {
        static def square(x: int) -> int {
            return x * x;
        }
    }

    # Enumerations
    enum Status { ACTIVE = "active", INACTIVE = "inactive", PENDING = "pending" }

    enum Priority { LOW = 1, MEDIUM = 2, HIGH = 3 }

    def summarize_status()  -> dict {
        states = [Status.ACTIVE, Status.PENDING];
        return {
            "first": states[0],
            "count": len(states),
            "names": ["ACTIVE", "PENDING"]
        };
    }

    # Utility demonstrating combined features
    def build_report(data: list) -> dict {
        processed = [];
        for item in data {
            if item is None {
                continue;
            }
            processed.append(item * 2);
        }

        info = collection_examples();
        stats = compare_values(len(processed), len(info["numbers"]));

        return {
            "processed": processed,
            "info": info,
            "stats": stats,
            "summary": summarize_status()
        };
    }

    def app()  -> JsxElement {
        return <div>
            <h1>
                "Authentication" App
            </h1>
            <p>
                This is a placeholder for the authentication app.
            </p>
        </div>;
    }
}
