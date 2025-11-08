Concurrent expressions enable parallel and asynchronous execution in Jac through the `flow` and `wait` modifiers. These constructs provide built-in concurrency support, allowing efficient parallel processing while maintaining clean, readable code.

#### Flow Modifier

The `flow` modifier initiates parallel execution of expressions:

```jac
# Execute operations in parallel
flow process_data(chunk1);
flow process_data(chunk2);
flow process_data(chunk3);
```

#### Wait Modifier

The `wait` modifier synchronizes parallel operations:

```jac
# Wait for specific operation
result = wait async_operation();

# Wait for multiple operations
wait all_tasks_complete();
```

#### Combined Usage

Flow and wait work together for parallel patterns:

```jac
walker ParallelProcessor {
    can process with entry {
        # Start parallel operations
        task1 = flow compute_heavy(here.data1);
        task2 = flow compute_heavy(here.data2);
        task3 = flow compute_heavy(here.data3);
        
        # Wait for all results
        result1 = wait task1;
        result2 = wait task2;
        result3 = wait task3;
        
        # Combine results
        here.result = combine(result1, result2, result3);
    }
}
```

#### Parallel Walker Spawning

Concurrent execution with walkers:

```jac
walker Analyzer {
    can analyze with entry {
        # Spawn walkers in parallel
        flow spawn ChildWalker() on node1;
        flow spawn ChildWalker() on node2;
        flow spawn ChildWalker() on node3;
        
        # Continue while children process
        visit [-->];
    }
}
```

#### Async Graph Operations

Parallel graph traversal:

```jac
walker ParallelTraverser {
    can traverse with entry {
        children = [-->];
        
        # Process children concurrently
        tasks = [];
        for child in children {
            task = flow process_node(child);
            tasks.append(task);
        }
        
        # Collect results
        results = [];
        for task in tasks {
            result = wait task;
            results.append(result);
        }
        
        report aggregate(results);
    }
}
```

#### Error Handling

Managing errors in concurrent operations:

```jac
can parallel_safe_process(items: list) -> list {
    results = [];
    errors = [];
    
    # Start all tasks
    tasks = [];
    for item in items {
        task = flow process_item(item);
        tasks.append({"item": item, "task": task});
    }
    
    # Collect results with error handling
    for t in tasks {
        try {
            result = wait t["task"];
            results.append(result);
        } except as e {
            errors.append({"item": t["item"], "error": e});
        }
    }
    
    if errors {
        handle_errors(errors);
    }
    
    return results;
}
```

#### Concurrency Patterns

##### Map-Reduce Pattern
```jac
can map_reduce(data: list, mapper: func, reducer: func) -> any {
    # Map phase - parallel
    mapped = [];
    for chunk in partition(data) {
        task = flow mapper(chunk);
        mapped.append(task);
    }
    
    # Collect mapped results
    results = [];
    for task in mapped {
        result = wait task;
        results.append(result);
    }
    
    # Reduce phase
    return reducer(results);
}
```

##### Pipeline Pattern
```jac
walker Pipeline {
    can process with entry {
        # Stage 1 - parallel data fetch
        data1 = flow fetch_source1();
        data2 = flow fetch_source2();
        data3 = flow fetch_source3();
        
        # Stage 2 - process as ready
        processed1 = flow transform(wait data1);
        processed2 = flow transform(wait data2);
        processed3 = flow transform(wait data3);
        
        # Stage 3 - aggregate
        final = aggregate([
            wait processed1,
            wait processed2,
            wait processed3
        ]);
        
        report final;
    }
}
```

#### Best Practices

1. **Granularity**: Balance task size for efficient parallelism
2. **Dependencies**: Clearly manage data dependencies
3. **Error Propagation**: Handle errors from parallel tasks
4. **Resource Limits**: Consider system constraints
5. **Synchronization**: Use wait appropriately to avoid race conditions

#### Integration with Object-Spatial

Concurrent expressions enhance graph processing:

```jac
walker GraphAnalyzer {
    can analyze with entry {
        # Parallel subgraph analysis
        subgraphs = partition_graph(here);
        
        analyses = [];
        for sg in subgraphs {
            analysis = flow analyze_subgraph(sg);
            analyses.append(analysis);
        }
        
        # Combine results
        combined = {};
        for a in analyses {
            result = wait a;
            merge_results(combined, result);
        }
        
        report combined;
    }
}
```

Concurrent expressions provide powerful primitives for parallel execution in Jac, enabling efficient utilization of modern multi-core systems while maintaining the clarity and expressiveness of the language's object-spatial programming model. 
