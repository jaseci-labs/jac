Pipe expressions enable functional-style data transformation through left-to-right value flow, eliminating deeply nested function calls and creating readable transformation chains. This feature is particularly powerful in object-spatial contexts where computation flows through topological structures.

#### Forward Pipe Operator (`|>`)

The forward pipe operator passes the result of the left expression as the first argument to the right expression:

```jac
# Traditional nested approach
result = process(transform(validate(data)));

# Pipe expression approach
result = data |> validate |> transform |> process;
```

This transformation improves readability by matching the natural left-to-right flow of data processing.

#### Basic Transformation Chains

Pipe expressions excel at creating clear data processing pipelines:

```jac
# Numeric processing
processed_numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    |> filter(|x| x % 2 == 0)
    |> map(|x| x * x)
    |> sum;

# String manipulation
formatted_message = "  Hello World  "
    |> strip
    |> lower
    |> replace(" ", "_")
    |> capitalize;
```

#### Method Chaining Integration

Pipes work seamlessly with object methods and archetype abilities:

```jac
obj DataProcessor {
    def normalize(self, data: list) -> list {
        max_val = max(data);
        return [x / max_val for x in data];
    }
    
    def scale(self, data: list, factor: float) -> list {
        return [x * factor for x in data];
    }
    
    def round_values(self, data: list) -> list {
        return [round(x, 2) for x in data];
    }
}

processor = DataProcessor();
result = raw_measurements
    |> processor.normalize
    |> processor.scale(100.0)
    |> processor.round_values;
```

#### Object-Spatial Pipeline Integration

Pipe expressions integrate naturally with object-spatial operations:

```jac
walker GraphAnalyzer {
    can analyze_network with entry {
        # Chain spatial operations
        network_metrics = here
            |> get_connected_nodes
            |> filter_by_activity_level
            |> calculate_centrality_scores
            |> aggregate_statistics;
        
        # Process node data through pipeline
        processed_data = here.raw_data
            |> clean_data
            |> normalize_values
            |> apply_transformations
            |> validate_results;
        
        # Update node with processed results
        here.update_metrics(network_metrics);
        here.set_processed_data(processed_data);
    }
}

node DataNode {
    has raw_data: list;
    has processed_data: dict;
    
    can get_connected_nodes(self) -> list {
        return [-->] |> map(|edge| edge.target);
    }
    
    can update_metrics(self, metrics: dict) {
        self.metrics = metrics;
    }
}
```

#### Multi-line Pipeline Formatting

Complex pipelines can span multiple lines for enhanced readability:

```jac
comprehensive_analysis = dataset
    |> remove_outliers(threshold=2.5)
    |> apply_feature_engineering(
        features=["normalized", "scaled", "encoded"],
        parameters={"scale_factor": 1.0}
    )
    |> split_train_test(ratio=0.8)
    |> train_model(algorithm="random_forest")
    |> evaluate_performance
    |> generate_report;
```

#### Error-Safe Pipelines

Pipe expressions can incorporate error handling and null-safe operations:

```jac
# Safe pipeline with optional operations
safe_result = potentially_null_input
    |> validate_input
    |> transform_safely
    |> process_if_valid
    |> default_on_error("fallback_value");

# Conditional pipeline execution
conditional_result = data
    |> (|x| validate(x) if x.needs_validation else x)
    |> (|x| expensive_operation(x) if x.size > threshold else x)
    |> finalize_processing;
```

#### Graph Traversal Pipelines

Pipe expressions excel in graph traversal and analysis scenarios:

```jac
walker PathOptimizer {
    can find_optimal_path with entry {
        optimal_route = here
            |> get_all_possible_paths
            |> filter_by_constraints(max_length=10, avoid_cycles=true)
            |> calculate_path_costs
            |> sort_by_efficiency
            |> select_best_path;
        
        # Execute the optimal path
        visit optimal_route;
    }
}

walker DataAggregator {
    has collected_data: list = [];
    
    can aggregate_from_network with entry {
        aggregated_results = [-->*]  # All reachable nodes
            |> filter(|n| n.has_data())
            |> map(|n| n.extract_data())
            |> group_by_category
            |> calculate_statistics
            |> format_results;
        
        self.collected_data.append(aggregated_results);
    }
}
```

#### Performance Considerations

Pipe expressions maintain efficiency through lazy evaluation and optimization:

```jac
# Efficient pipeline with early termination
result = large_dataset
    |> filter(|item| item.is_relevant())  # Reduces dataset size early
    |> take(100)                          # Limits processing to first 100
    |> expensive_transformation           # Only applied to filtered subset
    |> final_aggregation;
```

#### Functional Composition Patterns

Pipes enable elegant functional composition:

```jac
# Reusable transformation functions
def clean_and_validate(data: list) -> list {
    return data |> remove_nulls |> validate_format |> normalize_encoding;
}

def analyze_and_report(data: list) -> dict {
    return data |> statistical_analysis |> generate_insights |> format_report;
}

# Composed pipeline
final_report = raw_input
    |> clean_and_validate
    |> apply_business_rules
    |> analyze_and_report;
```

Pipe expressions transform complex data processing into intuitive, maintainable code that naturally expresses the flow of computation through both traditional data structures and object-spatial topologies.
