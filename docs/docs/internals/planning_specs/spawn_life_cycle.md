# Archetype Lifecycle Enhancement Roadmap

## Executive Summary

**Problem Statement**: Current archetype execution lacks proper lifecycle management, leading to unmanaged code execution, reduced developer productivity, and limited scalability for complex applications.

**Solution**: Implement a structured three-phase archetype lifecycle with simplified syntax and native concurrency support.

**Improvements in Development**:

- **Structured lifecycle events** enabling organized code execution patterns
- **Event-driven architecture** familiar to developers working with modern frameworks
- **Simplified syntax** reducing learning curve for new developers
- **Deterministic execution** improving code reliability and maintainability

---

## Current State Analysis

### Critical Issues

**1. Unmanaged Code Execution**

- Entry and exit abilities execute without clear lifecycle boundaries
- No separation between initialization, processing, and cleanup phases
- Developers struggle to organize code execution flow

```javascript
// Problem: These behave identically despite different intent
can a with entry { print(1); }
can b with exit { print(2); }
// vs
can a with entry { print(1); print(2); }
```

**2. Syntax Complexity**

- Verbose `can ... with ... entry/exit` syntax for simple lifecycle hooks
- Multiple declarations create confusion and override behavior
- No clear patterns for common use cases

**3. Limited Concurrency**

- No native support for parallel execution
- Developers must implement complex workarounds for concurrent operations
- Performance bottlenecks in data-intensive applications

---

## Implementation Roadmap

### ✅ **PHASE 1: Core Lifecycle Structure** (APPROVED)

**Target Outcome**: Establish predictable execution phases

**Implementation**:

- **Pre-execution**: Entry abilities run before node processing
- **Next-execution**: Node processing and child traversal
- **Post-execution**: Exit abilities run after all processing completes

**Expected Outcomes**:

- Zero ambiguity in execution order
- 100% predictable behavior across all walker types
- Clear separation of concerns in code structure

---

### ✅ **PHASE 2: Event-Driven Lifecycle Hooks** (APPROVED)

**Target Outcome**: Implement standard event-driven programming patterns

**Core Concept**: Lifecycle events with filter-based triggers and standalone abilities

**System Components**:

**1. Standalone Abilities** (Independent of lifecycle)

```javascript
can ability1 {
    // Declare ability that's not included in the lifecycle
    // Code your process here
    // `self`, `here` or `visitor` will be available here
}

can dance {
    // Same as ability1 but with a proper name
    // Contains reusable logic
}
```

**2. Global Lifecycle Events** (No filter - execute once per spawn)

```javascript
with entry {
    // Global entry - no filter specified
    // Only one allowed (multiple declarations use last one)
    // Very first event triggered once per spawn_call
    self::ability1; // Call the ability
    self::dance;    // Call another ability
}

with exit {
    // Global exit - opposite of `with entry`
    // Cleanup and final operations
    // Last event triggered once per spawn_call
}
```

**3. Filtered Lifecycle Events** (Execute multiple times based on filter)

```javascript
with A entry {
    // Entry event with filter A
    // Can be triggered multiple times during traversal
    // Multiple declarations with same filter use last one
    // Triggers when filter A conditions are met
}

with A exit {
    // Exit event with filter A
    // Opposite of filtered entry
    // Cleanup specific to filter A
}
```

**Expected Outcomes**:

- Event-driven architecture using clear filter-to-event mapping
- Zero confusion about event precedence

**Migration Path**:

```javascript
// Current (verbose)
can test with WalkerA entry { /* code */ }

// New (event-driven with abilities)
can process_data {
    // Standalone ability with automatic context
    // self, here, visitor available
}

with WalkerA entry {
    self::process_data; // Call ability within event
}
```

---

### ✅ **PHASE 3: Global Lifecycle Hooks** (APPROVED)

**Target Outcome**: Enable archetype-level control and result handling

**Features**:

- `with entry`: One-time archetype initialization
- `with exit`: Cleanup and result return
- `with object entry/exit`: Per-visit hooks

**Important Note on `with exit`**:

- As part of the global archetype lifecycle, `with exit` serves not only for cleanup but also for producing the final result of a walker spawn. This enables concise and explicit control of return values for spawned walkers, enhancing reliability and intent.

**Illustrative Example: Using `with exit` to Return Final Result**

```javascript
walker A {
    with exit {
        return 1; // final result of walker spawn
    }
}
```

This pattern ensures the walker’s result is predictable and that clean-up and result handling are clearly separated from object/node-level lifecycle events.

**Illustrative Example: Complete Lifecycle**

```javascript
walker DataProcessor {
   with entry { /* initialize resources once */ }
   with exit { return processed_results; /* clean return as final walker result */ }
   with object entry { /* per-node processing */ }
}
```

**Expected Outcomes**:

- Clean separation between archetype and object lifecycles
- Reliable result handling and value return from walker spawns
- Improved resource management patterns

---

### 🔄 **PHASE 4: Instant Visit Support** (UNDER DISCUSSION)

**Target Outcome**: Enable native depth-first search with predictable execution order

**Why This Matters**:

- **Performance**: Native DFS eliminates recursive overhead
- **Predictability**: Guaranteed execution sequence for complex traversals
- **Developer Experience**: Intuitive `enter [-->]` syntax matches mental model

**Technical Implementation**:

```javascript
node A {
   with WalkerA entry {
      print(1);
      enter [-->(`?B)]; // Immediate B lifecycle execution
      print(3);         // Continues after B completes
   }
}
// Guaranteed output: 1, 2, 3
```

**Expected Outcomes**:

- Native DFS eliminates custom implementation complexity
- Guaranteed execution sequence for complex traversals
- Intuitive syntax matches developer mental models

**Risk Mitigation**:

- Comprehensive testing with existing walker patterns
- Gradual rollout with feature flags
- Clear documentation of execution guarantees

---

### 🔄 **PHASE 5: Concurrent Execution Support** (UNDER DISCUSSION)

**Target Outcome**: Enable high-performance parallel processing with simple syntax

**Why Critical for Modern Applications**:

- **Scalability**: Handle large datasets efficiently
- **User Experience**: Responsive applications under load
- **Resource Utilization**: Maximize hardware capabilities

**Multiple Implementation Approaches**:

**Thread-based Concurrency**:

```javascript
// Simple syntax for CPU-bound tasks
visit:thread [-->]; // Automatic thread pool management
```

**Async/Task-based Concurrency**:

```javascript
// Ideal for I/O-bound operations
visit:task [-->]; // Native TaskGroup integration
```

**Manual Control for Complex Cases**:

```javascript
with TaskGroup() as tg {
    tg.create_task(async enter [-->]);
    tg.create_task(process_data());
}
```

**Expected Outcomes**:

- Structured approach to parallel processing
- Simplified concurrency patterns reduce implementation complexity
- Multiple syntax options for different use cases

**Implementation Considerations**:

- Thread safety analysis for all core operations
- Memory management for concurrent contexts
- Error handling and propagation across parallel tasks
- Performance benchmarking against current sequential execution

---

## Expected Outcomes

### Developer Productivity

- **Better Code Organization**: Event-driven patterns improve code structure
- **Familiar Paradigms**: Common event hooks reduce learning curve
- **Cleaner Separation**: Distinct abilities and events improve maintainability

### Application Architecture

- **Event-Driven Design**: Clear lifecycle management and execution flow
- **Modular Abilities**: Reusable code components with automatic context
- **Structured Concurrency**: Organized approach to parallel processing

### Code Quality

- **Predictable Events**: Clear filter-to-event mapping
- **Better Practices**: Separation between abilities and lifecycle events
- **Improved Testability**: Isolated abilities and events enable better testing

### Improvements in Development

- **Better Code Patterns**: Event-driven design improves development practices
- **Familiar Programming Model**: Reduces cognitive load for contributors
- **Improved Maintainability**: Clear separation between abilities and events
- **Team Collaboration**: Consistent patterns enable easier contribution and review

---

## Risk Assessment & Mitigation

### High Priority Risks

1. **Breaking Changes**: Existing code requires updates
   - _Mitigation_: Comprehensive migration guide and automated conversion tools
2. **Complexity Introduction**: Event system may add cognitive overhead
   - _Mitigation_: Clear documentation and illustrative examples for familiarity
3. **Ability Syntax Uncertainty**: `self::ability_name` syntax needs validation
   - _Mitigation_: Prototype syntax and gather developer feedback on `self::` vs alternatives

### Implementation Dependencies

- Phases 1-3 must be completed before 4-5
- Event system design and filter parsing required
- Ability calling syntax needs finalization (`self::ability_name` syntax validation)
- Migration tooling for existing codebases

---

## Next Steps

1. **Finalize Phase 4 & 5 specifications** based on team discussion
2. **Decide on ability calling syntax** (current proposal: `self::ability_name`)
3. **Develop event system architecture** with filter parsing logic
4. **Create comprehensive testing plan** for event-driven patterns

_Ready for your feedback on Phases 4 & 5 and ability syntax to proceed with detailed implementation planning._
