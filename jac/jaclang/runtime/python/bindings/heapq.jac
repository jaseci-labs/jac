"""Python heap signatures and initialization, compiled into JacPython."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition
}
import from jaclang.runtime.python.bindings.arguments {
    CallSignature,
    BoundArguments,
    invoke,
    invoke_one,
    invalid
}
import from jaclang.runtime.python.capi { jacpy_is_list, type_name }
import from jaclang.runtime.python.modules.heapq {
    jacpy_heap_push,
    jacpy_heap_pop,
    jacpy_heap_replace,
    jacpy_heap_pushpop,
    jacpy_heapify
}

glob:priv heappush_signature = CallSignature(
         "heappush", ["heap", "item"], 2, 2, 2
     );

def:priv heappush_bound(args: BoundArguments) -> u64 {
    heap = args.values[0];
    if jacpy_is_list(heap) == 0 {
        invalid(f"heappush() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_push(heap, args.values[1], 0);
}

def:priv heappush_call(module: u64, args: u64) -> u64 {
    return invoke(heappush_signature, args, 0, heappush_bound);
}

glob:priv heappush_max_signature = CallSignature(
         "heappush_max", ["heap", "item"], 2, 2, 2
     );

def:priv heappush_max_bound(args: BoundArguments) -> u64 {
    heap = args.values[0];
    if jacpy_is_list(heap) == 0 {
        invalid(f"heappush_max() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_push(heap, args.values[1], 1);
}

def:priv heappush_max_call(module: u64, args: u64) -> u64 {
    return invoke(heappush_max_signature, args, 0, heappush_max_bound);
}

glob:priv heapreplace_signature = CallSignature(
         "heapreplace", ["heap", "item"], 2, 2, 2
     );

def:priv heapreplace_bound(args: BoundArguments) -> u64 {
    heap = args.values[0];
    if jacpy_is_list(heap) == 0 {
        invalid(f"heapreplace() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_replace(heap, args.values[1], 0);
}

def:priv heapreplace_call(module: u64, args: u64) -> u64 {
    return invoke(heapreplace_signature, args, 0, heapreplace_bound);
}

glob:priv heapreplace_max_signature = CallSignature(
         "heapreplace_max", ["heap", "item"], 2, 2, 2
     );

def:priv heapreplace_max_bound(args: BoundArguments) -> u64 {
    heap = args.values[0];
    if jacpy_is_list(heap) == 0 {
        invalid(f"heapreplace_max() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_replace(heap, args.values[1], 1);
}

def:priv heapreplace_max_call(module: u64, args: u64) -> u64 {
    return invoke(heapreplace_max_signature, args, 0, heapreplace_max_bound);
}

glob:priv heappushpop_signature = CallSignature(
         "heappushpop", ["heap", "item"], 2, 2, 2
     );

def:priv heappushpop_bound(args: BoundArguments) -> u64 {
    heap = args.values[0];
    if jacpy_is_list(heap) == 0 {
        invalid(f"heappushpop() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_pushpop(heap, args.values[1], 0);
}

def:priv heappushpop_call(module: u64, args: u64) -> u64 {
    return invoke(heappushpop_signature, args, 0, heappushpop_bound);
}

glob:priv heappushpop_max_signature = CallSignature(
         "heappushpop_max", ["heap", "item"], 2, 2, 2
     );

def:priv heappushpop_max_bound(args: BoundArguments) -> u64 {
    heap = args.values[0];
    if jacpy_is_list(heap) == 0 {
        invalid(f"heappushpop_max() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_pushpop(heap, args.values[1], 1);
}

def:priv heappushpop_max_call(module: u64, args: u64) -> u64 {
    return invoke(heappushpop_max_signature, args, 0, heappushpop_max_bound);
}

def:priv heappop_bound(heap: u64) -> u64 {
    if jacpy_is_list(heap) == 0 {
        invalid(f"heappop() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_pop(heap, 0);
}

def:priv heappop_call(module: u64, args: u64) -> u64 {
    return invoke_one(args, heappop_bound);
}

def:priv heappop_max_bound(heap: u64) -> u64 {
    if jacpy_is_list(heap) == 0 {
        invalid(f"heappop_max() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_pop(heap, 1);
}

def:priv heappop_max_call(module: u64, args: u64) -> u64 {
    return invoke_one(args, heappop_max_bound);
}

def:priv heapify_bound(heap: u64) -> u64 {
    if jacpy_is_list(heap) == 0 {
        invalid(f"heapify() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heapify(heap, 0);
}

def:priv heapify_call(module: u64, args: u64) -> u64 {
    return invoke_one(args, heapify_bound);
}

def:priv heapify_max_bound(heap: u64) -> u64 {
    if jacpy_is_list(heap) == 0 {
        invalid(f"heapify_max() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heapify(heap, 1);
}

def:priv heapify_max_call(module: u64, args: u64) -> u64 {
    return invoke_one(args, heapify_max_bound);
}

glob:priv definition = ModuleDefinition(
         "_heapq",
         "Heap algorithms implemented in native Jac.",
         [
             MethodDefinition(
                 "heappush",
                 MethodCallbacks(positional=heappush_call),
                 "heappush($module, heap, item, /)\n--\n\nMaintain a heap in place.",
                 flags=1
             ),
             MethodDefinition(
                 "heappush_max",
                 MethodCallbacks(positional=heappush_max_call),
                 "heappush_max($module, heap, item, /)\n--\n\nMaintain a heap in place.",
                 flags=1
             ),
             MethodDefinition(
                 "heapreplace",
                 MethodCallbacks(positional=heapreplace_call),
                 "heapreplace($module, heap, item, /)\n--\n\nMaintain a heap in place.",
                 flags=1
             ),
             MethodDefinition(
                 "heapreplace_max",
                 MethodCallbacks(positional=heapreplace_max_call),
                 "heapreplace_max($module, heap, item, /)\n--\n\nMaintain a heap in place.",
                 flags=1
             ),
             MethodDefinition(
                 "heappushpop",
                 MethodCallbacks(positional=heappushpop_call),
                 "heappushpop($module, heap, item, /)\n--\n\nMaintain a heap in place.",
                 flags=1
             ),
             MethodDefinition(
                 "heappushpop_max",
                 MethodCallbacks(positional=heappushpop_max_call),
                 "heappushpop_max($module, heap, item, /)\n--\n\nMaintain a heap in place.",
                 flags=1
             ),
             MethodDefinition(
                 "heappop",
                 MethodCallbacks(positional=heappop_call),
                 "heappop($module, heap, /)\n--\n\nMaintain a heap in place.",
                 flags=8
             ),
             MethodDefinition(
                 "heappop_max",
                 MethodCallbacks(positional=heappop_max_call),
                 "heappop_max($module, heap, /)\n--\n\nMaintain a heap in place.",
                 flags=8
             ),
             MethodDefinition(
                 "heapify",
                 MethodCallbacks(positional=heapify_call),
                 "heapify($module, heap, /)\n--\n\nMaintain a heap in place.",
                 flags=8
             ),
             MethodDefinition(
                 "heapify_max",
                 MethodCallbacks(positional=heapify_max_call),
                 "heapify_max($module, heap, /)\n--\n\nMaintain a heap in place.",
                 flags=8
             )
         ]
     );

def:pub PyInit__heapq -> u64 {
    return definition.initialize();
}
