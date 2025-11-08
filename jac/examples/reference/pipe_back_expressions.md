Pipe back expressions provide the reverse flow of pipe forward expressions, passing the result of the right expression as the last argument to the left expression. This operator enables different composition patterns that can be more natural for certain operations.

#### Backward Pipe Operator (`<|`)

The backward pipe operator flows data from right to left:

```jac
# Forward pipe - data flows left to right
result = data |> process |> format;

# Backward pipe - data flows right to left
result = format <| process <| data;
```

#### Use Cases

##### Building Processing Pipelines
```jac
# Define a processing pipeline right-to-left
processor = output_formatter
    <| data_validator  
    <| input_parser;

# Apply the pipeline
result = processor(raw_input);
```

##### Partial Application Patterns
```jac
# Create specialized functions
process_users = save_to_database
    <| validate_user_data
    <| normalize_user_fields;

# Use the composed function
process_users(user_list);
```

#### Combining with Forward Pipes

Mix both operators for expressive code:

```jac
# Process data then apply formatting
final_result = formatter <| (
    raw_data
    |> clean
    |> validate
    |> transform
);
```

#### Graph Operations

In object-spatial contexts:

```jac
walker Analyzer {
    can analyze with entry {
        # Right-to-left node filtering
        targets = filter_reachable
            <| sort_by_priority
            <| [-->];
        
        # Process results left-to-right
        results = targets
            |> extract_data
            |> aggregate;
    }
}
```

#### Function Composition

Create reusable processing chains:

```jac
# Compose validators
validate_all = validate_format
    <| validate_range
    <| validate_type;

# Compose transformers  
transform_all = final_format
    <| apply_rules
    <| normalize;

# Full pipeline
process = transform_all <| validate_all;
```

#### Precedence and Grouping

Understanding operator precedence:

```jac
# Parentheses for clarity
result = (step3 <| step2) <| step1;

# Mixed operators need careful grouping
output = final_step <| (
    input |> first_step |> second_step
);
```

#### Common Patterns

##### Builder Pattern
```jac
# Build configuration right-to-left
config = apply_overrides
    <| set_defaults
    <| parse_config_file
    <| "config.json";
```

##### Middleware Chain
```jac
# Web request processing
handle_request = send_response
    <| process_business_logic
    <| authenticate
    <| parse_request;
```

##### Data Validation Pipeline
```jac
# Validation stages
validate = report_errors
    <| check_business_rules
    <| verify_data_types
    <| sanitize_input;
```

#### Best Practices

- **Use `<|` when**: Building processing chains where later stages depend on earlier ones
- **Use `|>` when**: Transforming data through sequential steps
- **Mix operators**: When it improves readability
- **Group with parentheses**: To make precedence explicit

#### Comparison with Forward Pipe

```jac
# Forward pipe - follows data flow
processed = data |> step1 |> step2 |> step3;

# Backward pipe - follows dependency order  
processed = step3 <| step2 <| step1 <| data;

# Both achieve the same result
```

Pipe back expressions offer an alternative composition style that can be more intuitive when thinking about processing pipelines in terms of dependencies rather than data flow. They complement forward pipes to provide flexible, expressive ways to compose operations in Jac.
