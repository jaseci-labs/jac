Report statements provide a mechanism for walkers to communicate results back to their spawning context. This feature is essential for extracting information from graph traversals and object-spatial computations.

#### Syntax

```jac
report expression;
```

#### Purpose

Report statements allow walkers to:
- Return computed results from traversals
- Aggregate data collected across multiple nodes
- Communicate findings to the calling context
- Build up results incrementally during traversal

#### Basic Usage

```jac
walker DataCollector {
    can collect with entry {
        # Report individual node data
        report here.data;
        
        # Continue traversal
        visit [-->];
    }
}

# Spawn walker and collect reports
with entry {
    results = spawn DataCollector();
    # results contains all reported values
}
```

#### Multiple Reports

Walkers can report multiple times during traversal:

```jac
walker PathFinder {
    has max_depth: int = 3;
    has depth: int = 0;
    
    can explore with entry {
        if self.depth >= self.max_depth {
            return;
        }
        
        # Report current path node
        report {
            "node": here,
            "depth": self.depth,
            "value": here.value
        };
        
        # Explore deeper
        self.depth += 1;
        visit [-->];
        self.depth -= 1;
    }
}
```

#### Aggregating Results

Common pattern for collecting data:

```jac
walker Aggregator {
    has total: float = 0.0;
    has count: int = 0;
    
    can aggregate with entry {
        # Process current node
        self.total += here.value;
        self.count += 1;
        
        # Visit children
        visit [-->];
    }
    
    can aggregate with exit {
        # Report final aggregation
        if self.count > 0 {
            report {
                "average": self.total / self.count,
                "total": self.total,
                "count": self.count
            };
        }
    }
}
```

#### Conditional Reporting

Report based on conditions:

```jac
walker SearchWalker {
    has target: str;
    
    can search with entry {
        # Report only matching nodes
        if here.name == self.target {
            report {
                "found": here,
                "path": self.path,
                "properties": here.to_dict()
            };
        }
        
        # Continue search
        visit [-->];
    }
}
```

#### Report vs Return

Key differences:
- `report`: Accumulates values, continues execution
- `return`: Exits current ability immediately

```jac
walker Finder {
    can find with entry {
        if here.is_target {
            report here;  # Add to results
            return;       # Stop searching this branch
        }
        visit [-->];
    }
}
```

#### Integration with Object-Spatial

Reports work seamlessly with graph traversal:

```jac
node DataNode {
    has id: str;
    has value: float;
    has category: str;
}

walker Analyzer {
    has category_filter: str;
    
    can analyze with entry {
        # Filter and report
        if here.category == self.category_filter {
            report {
                "id": here.id,
                "value": here.value,
                "connections": len([-->])
            };
        }
        
        # Traverse to connected nodes
        visit [-->(?.category == self.category_filter)];
    }
}

# Usage
with entry {
    results = spawn Analyzer(category_filter="important") on root;
    print(f"Found {len(results)} matching nodes");
}
```

#### Advanced Patterns

##### Path Tracking
```jac
walker PathTracker {
    has path: list = [];
    
    can track with entry {
        self.path.append(here);
        
        # Report complete paths at leaves
        if len([-->]) == 0 {
            report self.path.copy();
        }
        
        visit [-->];
    }
    
    can track with exit {
        self.path.pop();
    }
}
```

##### Hierarchical Aggregation
```jac
walker TreeAggregator {
    can aggregate with entry {
        # Visit children first
        visit [-->];
    }
    
    can aggregate with exit {
        # Aggregate after processing children
        child_sum = sum([child.value for child in [-->]]);
        total = here.value + child_sum;
        
        report {
            "node": here,
            "node_value": here.value,
            "subtree_total": total
        };
    }
}
```

#### Best Practices

1. **Report Meaningful Data**: Include context with reported values
2. **Use Structured Reports**: Return dictionaries for complex data
3. **Consider Memory**: Large traversals with many reports can accumulate
4. **Report Early**: Don't wait until the end if intermediate results matter
5. **Combine with Disengage**: Use `disengage` after critical reports

Report statements are fundamental to the walker pattern in Jac, enabling elegant extraction of information from graph structures while maintaining clean separation between traversal logic and result collection.
