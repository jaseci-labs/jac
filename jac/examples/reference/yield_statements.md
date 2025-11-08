Yield statements in Jac provide the foundation for generator functions and iterative computation patterns. These statements enable functions to produce sequences of values on-demand rather than computing and returning entire collections at once, supporting memory-efficient iteration and lazy evaluation.

**Basic Yield Statement Syntax**

Yield statements follow this pattern from the grammar:
```jac
yield expression;     # Yield a value
yield;               # Yield nothing (None/null)
yield from iterable; # Yield all values from another iterable
```

**Generator Function Example**

The provided example demonstrates a generator function that yields multiple values:
```jac
def myFunc {
    yield "Hello";
    yield 91;
    yield "Good Bye";
    yield;
}
```

**Key aspects:**
- **No return type**: Generator functions don't specify return types like regular functions
- **Multiple yields**: Function can yield different values at different points
- **Mixed types**: Can yield different types (string, int, null)
- **Execution suspension**: Function pauses at each yield and resumes when next value is requested

**Generator Consumption**

Generators are consumed through iteration:
```jac
x = myFunc();        # Creates generator object
for z in x {         # Iterates through yielded values
    print(z);        # Prints: "Hello", 91, "Good Bye", None
}
```

**Execution flow:**
1. `myFunc()` returns a generator object (doesn't execute function body yet)
2. First iteration calls generator, executes until first `yield "Hello"`
3. Second iteration resumes after first yield, executes until `yield 91`
4. Process continues until all yields are exhausted
5. Generator automatically raises StopIteration when function ends

**Yield Expression Types**

**Value Yields**
```jac
def number_generator {
    yield 1;
    yield 2;
    yield 3;
}
```

**Expression Yields**
```jac
def calculated_values(base: int) {
    yield base * 2;
    yield base ** 2;
    yield base + 10;
}
```

**Variable Yields**
```jac
def data_generator {
    items = ["a", "b", "c"];
    for item in items {
        yield item;
    }
}
```

**Empty Yields**
```jac
def sparse_generator {
    yield 1;
    yield;        # Yields None/null
    yield 3;
}
```

**Yield From Statement**

The `yield from` syntax delegates to another iterable:

**Generator Delegation**
```jac
def sub_generator {
    yield 1;
    yield 2;
}

def main_generator {
    yield 0;
    yield from sub_generator();  # Yields 1, then 2
    yield 3;
}
# Result sequence: 0, 1, 2, 3
```

**Collection Delegation**
```jac
def list_generator {
    yield from [1, 2, 3];      # Yields each list element
    yield from "abc";          # Yields each character
}
```

**Generator State and Memory**

Generators maintain state between yields:

**Stateful Generators**
```jac
def counter(start: int, end: int) {
    current = start;
    while current <= end {
        yield current;
        current += 1;           # State persists between yields
    }
}
```

**Local Variable Persistence**
```jac
def accumulator {
    total = 0;
    values = [1, 2, 3, 4, 5];
    for value in values {
        total += value;
        yield total;            # Yields running sum: 1, 3, 6, 10, 15
    }
}
```

**Infinite Generators**

Generators can produce infinite sequences:

**Infinite Counter**
```jac
def infinite_counter(start: int) {
    current = start;
    while true {
        yield current;
        current += 1;
    }
}
```

**Fibonacci Generator**
```jac
def fibonacci {
    a, b = 0, 1;
    while true {
        yield a;
        a, b = b, a + b;
    }
}
```

**Generator Patterns**

**Data Processing Pipeline**
```jac
def process_data(raw_data: list) {
    for item in raw_data {
        if item.is_valid {
            processed = item.transform();
            yield processed;
        }
    }
}
```

**Batch Processing**
```jac
def batch_generator(data: list, batch_size: int) {
    batch = [];
    for item in data {
        batch.append(item);
        if len(batch) == batch_size {
            yield batch;
            batch = [];
        }
    }
    if len(batch) > 0 {
        yield batch;  # Final partial batch
    }
}
```

**Resource Management**
```jac
def file_line_generator(filename: str) {
    file = open(filename);
    try {
        for line in file {
            yield line.strip();
        }
    } finally {
        file.close();
    }
}
```

**Generator Expressions vs Generator Functions**

**Generator Function**
```jac
def squares {
    for i in range(10) {
        yield i * i;
    }
}
```

**Generator Expression** (if supported)
```jac
squares = (i * i for i in range(10));
```

**Integration with Object-Spatial Features**

Generators work within object-spatial contexts:

**Walker Data Generation**
```jac
walker DataCollector {
    can collect_from_nodes with `node entry {
        for neighbor in [-->] {
            data = neighbor.extract_data();
            if data.is_valid {
                yield data;
            }
        }
    }
}
```

**Node Data Streaming**
```jac
node DataSource {
    can stream_data with Reader entry {
        for chunk in self.data_chunks {
            yield chunk;
        }
    }
}
```

**Performance Benefits**

**Memory Efficiency**
```jac
# Memory efficient - generates values on demand
def large_sequence {
    for i in range(1000000) {
        yield expensive_computation(i);
    }
}

# vs. Memory intensive - creates entire list
def large_list {
    return [expensive_computation(i) for i in range(1000000)];
}
```

**Lazy Evaluation**
```jac
def lazy_processor(data: list) {
    for item in data {
        # Computation only happens when value is requested
        result = expensive_operation(item);
        yield result;
    }
}
```

**Generator Composition**

**Pipeline Pattern**
```jac
def source {
    for i in range(100) {
        yield i;
    }
}

def filter_even {
    for value in source() {
        if value % 2 == 0 {
            yield value;
        }
    }
}

def transform {
    for value in filter_even() {
        yield value * 2;
    }
}
```

**Error Handling in Generators**

```jac
def safe_generator(data: list) {
    for item in data {
        try {
            result = risky_operation(item);
            yield result;
        } except Exception as e {
            yield error_value(e);
        }
    }
}
```

**Generator Cleanup**

```jac
def resource_generator {
    resource = acquire_resource();
    try {
        while resource.has_data() {
            yield resource.next_item();
        }
    } finally {
        resource.release();  # Cleanup when generator is destroyed
    }
}
```

**Best Practices**

1. **Use for large datasets**: Generators excel with large or infinite sequences
2. **Document generator behavior**: Clearly specify what values are yielded
3. **Handle cleanup**: Use try/finally for resource management
4. **Avoid state mutation**: Be careful with shared mutable state
5. **Consider composition**: Chain generators for processing pipelines

**Common Patterns**

**Data Transformation**
```jac
def transform_records(records: list) {
    for record in records {
        transformed = record.transform();
        if transformed.is_valid {
            yield transformed;
        }
    }
}
```

**Event Generation**
```jac
def event_stream {
    while system.is_running {
        event = system.wait_for_event();
        yield event;
    }
}
```

**Pagination**
```jac
def paginated_data(source: DataSource) {
    page = 1;
    while true {
        data = source.get_page(page);
        if not data {
            break;
        }
        yield from data;
        page += 1;
    }
}
```

Yield statements in Jac enable powerful generator-based programming patterns that promote memory efficiency, lazy evaluation, and elegant iteration patterns. They provide a foundation for building data processing pipelines, handling large datasets, and implementing custom iteration protocols that integrate seamlessly with both traditional programming constructs and Jac's object-spatial features.
