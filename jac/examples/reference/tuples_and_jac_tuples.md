Jac provides two distinct tuple syntaxes that serve different programming needs: traditional positional tuples for ordered data and keyword tuples for labeled data structures that integrate seamlessly with pipe operations and object-spatial programming.

#### Positional Tuples

Positional tuples follow Python's immutable ordered collection semantics:

```jac
coords = (10, 20);
print(coords[0]);   # → 10

# Single-element tuples require trailing comma
singleton = (42,);
```

Positional tuples support standard sequence operations including slicing, concatenation, and indexing, providing familiar behavior for developers transitioning from Python.

#### Keyword Tuples

Keyword tuples are a Jac-specific extension that associates labels with tuple elements, creating self-documenting data structures:

```jac
point = (x=3, y=4);
print(point.x);        # → 3
print(point["y"]);     # → 4 (index by name)
```

Each element in a keyword tuple is tagged with a field name that persists at runtime, enabling both dot notation and dictionary-style access patterns.

#### Pipeline Integration

Keyword tuples integrate naturally with Jac's pipe operators, enabling clean parameter passing without explicit argument lists:

```jac
walker DataProcessor {
    can analyze with entry {
        # Build labeled data tuple and pipe to function
        (node_id=here.id, data_size=len(here.data), 
         neighbor_count=len([-->])) |> process_metrics;
    }
}

def process_metrics(node_id: str, data_size: int, neighbor_count: int) {
    print(f"Node {node_id}: {data_size} bytes, {neighbor_count} neighbors");
}
```

This pattern eliminates the need for long parameter lists while maintaining clear semantic meaning.

#### Mixed Tuple Syntax

Jac allows combining positional and keyword elements within a single tuple, with positional elements required to precede keyword elements:

```jac
mixed_data = ("header", version=2, timestamp=now());
```

This ordering constraint ensures unambiguous parsing while providing flexibility for complex data structures.

#### Destructuring Assignment

Both tuple types support destructuring assignment with appropriate syntax:

```jac
# Positional destructuring
let (x, y) = coords;

# Keyword destructuring (order-independent)
let (y=latitude, x=longitude) = point;
```

Keyword destructuring matches variables by label rather than position, providing more robust code when tuple structure evolves.

#### Object-Spatial Applications

Tuples integrate effectively with object-spatial programming patterns:

```jac
node MetricsNode {
    can compute_stats with visitor entry {
        # Create labeled metrics tuple
        stats = (
            processing_time=self.get_processing_time(),
            memory_usage=self.get_memory_usage(),
            throughput=self.calculate_throughput()
        );
        
        # Pass to visitor for aggregation
        visitor.collect_metrics(stats);
    }
}

walker MetricsCollector {
    has collected_metrics: list = [];
    
    can collect_metrics(metrics: tuple) {
        self.collected_metrics.append(metrics);
    }
}
```

#### Performance and Memory Considerations

Both tuple types are immutable, ensuring thread safety and enabling optimization opportunities. Keyword tuples carry additional metadata for field names but provide enhanced readability and maintainability for complex data structures.

#### Usage Guidelines

**Positional tuples** are ideal for simple ordered data, mathematical coordinates, and compatibility with Python libraries.

**Keyword tuples** excel in heterogeneous data representation, pipeline operations, and scenarios requiring explicit semantic labeling.

The choice between tuple types should reflect the intended use pattern and the importance of self-documenting code structure in the specific application context.
