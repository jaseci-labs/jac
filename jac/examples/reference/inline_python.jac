# Inline Python - Embedding Python code blocks within Jac

# ===== Part 1: Basic Python Block =====
::py::
def python_hello():
    return "Hello from Python!"

def python_add(a, b):
    return a + b
::py::


with entry {
    print("=== 1. Basic Python Block ===");
    print(python_hello());
    print(f"Python add: {python_add(10, 20)}");
}

# ===== Part 2: Python Block in Object =====
obj DataProcessor {
    has data: list = [];

    ::py::
    def process(self):
        """Process data using Python libraries."""
        if not self.data:
            return []
        # Use Python built-ins
        return [x * 2 for x in self.data if x > 0]

    def analyze(self):
        """Statistical analysis with Python."""
        if not self.data:
            return {"mean": 0, "sum": 0}
        return {
            "mean": sum(self.data) / len(self.data),
            "sum": sum(self.data),
            "max": max(self.data),
            "min": min(self.data)
        }
    ::py::

}

with entry {
    print("\n=== 2. Python Methods in Object ===");
}

glob processor = DataProcessor(data=[1, -2, 3, 4, -5, 6]),
     processed = processor.process();

with entry {
    print(f"Processed data: {processed}");
}

glob stats = processor.analyze(),
     mean_val = round(stats['mean'], 2);

with entry {
    print(f"Statistics: mean={mean_val}, sum={stats['sum']}");
}

# ===== Part 3: Python Block with Jac Data Structures =====
::py::
def python_process_list(jac_list):
    """Python can work with Jac data structures."""
    # Lists, dicts, and other collections are compatible
    return [x ** 2 for x in jac_list]

def python_process_dict(jac_dict):
    """Process Jac dictionaries in Python."""
    return {k: v * 2 for k, v in jac_dict.items()}
::py::


with entry {
    print("\n=== 3. Python Processing Jac Data ===");
}

glob jac_list = [1, 2, 3, 4, 5],
     squared = python_process_list(jac_list);

with entry {
    print(f"Squared: {squared}");
}

glob jac_dict = {"a": 10, "b": 20, "c": 30},
     doubled = python_process_dict(jac_dict);

with entry {
    print(f"Doubled dict: {doubled}");
}

# ===== Part 4: Python Libraries Integration =====
::py::
import json
import math

def format_json(data):
    """Use Python's json library."""
    return json.dumps(data, indent=2)

def math_operations(x):
    """Use Python's math library."""
    return {
        "sqrt": math.sqrt(x),
        "log": math.log(x),
        "sin": math.sin(x)
    }
::py::


with entry {
    print("\n=== 4. Python Libraries ===");
}

glob data = {"name": "Jac", "version": 1.0, "features": ["OSP", "Python interop"]},
     json_str = format_json(data);

with entry {
    print(f"JSON output:\n{json_str}");
}

glob math_result = math_operations(16),
     log_val = round(math_result['log'], 2);

with entry {
    print(f"Math: sqrt={math_result['sqrt']}, log={log_val}");
}

# ===== Part 5: Python in Node with State =====
node MathNode {
    has value: float = 0.0,
        computed: dict = {};

    ::py::
    def compute_all(self):
        """Compute various mathematical properties."""
        import math
        v = self.value
        self.computed = {
            "square": v ** 2,
            "cube": v ** 3,
            "sqrt": math.sqrt(abs(v)),
            "is_even": v % 2 == 0
        }
        return self.computed
    ::py::

}

with entry {
    print("\n=== 5. Python in Nodes ===");
}

glob math_node = MathNode(value=9.0),
     results = math_node.compute_all();

with entry {
    print(f"Node value: {math_node.value}");
    print(f"Computed: square={results['square']}, cube={results['cube']}");
}

# ===== Part 6: Python Block Accessing Jac Archetypes =====
obj Counter {
    has count: int = 0;

    ::py::
    def increment(self, by=1):
        """Increment counter (Python method)."""
        self.count += by
        return self.count

    def reset(self):
        """Reset counter."""
        self.count = 0
    ::py::

}

with entry {
    print("\n=== 6. Python Methods Accessing Jac State ===");
}

glob counter = Counter();

with entry {
    counter.increment(5);
    counter.increment(3);
    print(f"Counter after increments: {counter.count}");

    counter.reset();
    print(f"Counter after reset: {counter.count}");
}

# ===== Part 7: Mixed Jac and Python Methods =====
obj Calculator {
    has history: list = [];

    # Jac method
    def add_jac(value: int) {
        self.history.append(value);
        return sum(self.history);
    }

    ::py::
    # Python method
    def add_python(self, value):
        """Python version of add."""
        self.history.append(value)
        return sum(self.history)

    def get_stats(self):
        """Python statistics on history."""
        if not self.history:
            return {"avg": 0, "total": 0}
        return {
            "avg": sum(self.history) / len(self.history),
            "total": sum(self.history),
            "count": len(self.history)
        }
    ::py::

}

with entry {
    print("\n=== 7. Mixed Jac/Python Methods ===");
}

glob calc = Calculator();

with entry {
    calc.add_jac(10);
    calc.add_python(20);
    calc.add_jac(30);
}

glob stats = calc.get_stats(),
     avg_val = round(stats['avg'], 1);

with entry {
    print(f"Stats: avg={avg_val}, total={stats['total']}, count={stats['count']}");
}

with entry {
    print("\n✓ Inline Python complete!");
}
