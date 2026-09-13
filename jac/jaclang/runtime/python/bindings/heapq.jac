"""Python heap signatures and initialization, compiled into JacPython."""
import from jaclang.runtime.python.bindings.module { Module, Method }
import from jaclang.runtime.python.bindings.arguments {
    Signature,
    Arguments,
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

glob heappush_signature = Signature("heappush", ["heap", "item"], 2, 2, 2);
def heappush_bound(args: Arguments) -> u64 {
    heap = args.values[0];
    if jacpy_is_list(heap) == 0 {
        invalid(f"heappush() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_push(heap, args.values[1], 0);
}

def heappush_call(module: u64, args: u64) -> u64 {
    return invoke(heappush_signature, args, 0, heappush_bound);
}

glob heappush_max_signature = Signature("heappush_max", ["heap", "item"], 2, 2, 2);
def heappush_max_bound(args: Arguments) -> u64 {
    heap = args.values[0];
    if jacpy_is_list(heap) == 0 {
        invalid(f"heappush_max() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_push(heap, args.values[1], 1);
}

def heappush_max_call(module: u64, args: u64) -> u64 {
    return invoke(heappush_max_signature, args, 0, heappush_max_bound);
}

glob heapreplace_signature = Signature("heapreplace", ["heap", "item"], 2, 2, 2);
def heapreplace_bound(args: Arguments) -> u64 {
    heap = args.values[0];
    if jacpy_is_list(heap) == 0 {
        invalid(f"heapreplace() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_replace(heap, args.values[1], 0);
}

def heapreplace_call(module: u64, args: u64) -> u64 {
    return invoke(heapreplace_signature, args, 0, heapreplace_bound);
}

glob heapreplace_max_signature = Signature(
         "heapreplace_max", ["heap", "item"], 2, 2, 2
     );

def heapreplace_max_bound(args: Arguments) -> u64 {
    heap = args.values[0];
    if jacpy_is_list(heap) == 0 {
        invalid(f"heapreplace_max() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_replace(heap, args.values[1], 1);
}

def heapreplace_max_call(module: u64, args: u64) -> u64 {
    return invoke(heapreplace_max_signature, args, 0, heapreplace_max_bound);
}

glob heappushpop_signature = Signature("heappushpop", ["heap", "item"], 2, 2, 2);
def heappushpop_bound(args: Arguments) -> u64 {
    heap = args.values[0];
    if jacpy_is_list(heap) == 0 {
        invalid(f"heappushpop() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_pushpop(heap, args.values[1], 0);
}

def heappushpop_call(module: u64, args: u64) -> u64 {
    return invoke(heappushpop_signature, args, 0, heappushpop_bound);
}

glob heappushpop_max_signature = Signature(
         "heappushpop_max", ["heap", "item"], 2, 2, 2
     );

def heappushpop_max_bound(args: Arguments) -> u64 {
    heap = args.values[0];
    if jacpy_is_list(heap) == 0 {
        invalid(f"heappushpop_max() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_pushpop(heap, args.values[1], 1);
}

def heappushpop_max_call(module: u64, args: u64) -> u64 {
    return invoke(heappushpop_max_signature, args, 0, heappushpop_max_bound);
}

def heappop_bound(heap: u64) -> u64 {
    if jacpy_is_list(heap) == 0 {
        invalid(f"heappop() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_pop(heap, 0);
}

def heappop_call(module: u64, args: u64) -> u64 {
    return invoke_one(args, heappop_bound);
}

def heappop_max_bound(heap: u64) -> u64 {
    if jacpy_is_list(heap) == 0 {
        invalid(f"heappop_max() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heap_pop(heap, 1);
}

def heappop_max_call(module: u64, args: u64) -> u64 {
    return invoke_one(args, heappop_max_bound);
}

def heapify_bound(heap: u64) -> u64 {
    if jacpy_is_list(heap) == 0 {
        invalid(f"heapify() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heapify(heap, 0);
}

def heapify_call(module: u64, args: u64) -> u64 {
    return invoke_one(args, heapify_bound);
}

def heapify_max_bound(heap: u64) -> u64 {
    if jacpy_is_list(heap) == 0 {
        invalid(f"heapify_max() argument must be list, not {type_name(heap)}");
        return 0;
    }
    return jacpy_heapify(heap, 1);
}

def heapify_max_call(module: u64, args: u64) -> u64 {
    return invoke_one(args, heapify_max_bound);
}

glob definition = Module(
         "_heapq",
         "Heap algorithms implemented in native Jac.",
         [
             Method(
                 "heappush",
                 0,
                 "heappush($module, heap, item, /)\n--\n\nMaintain a heap in place.",
                 heappush_call,
                 1
             ),
             Method(
                 "heappush_max",
                 0,
                 "heappush_max($module, heap, item, /)\n--\n\nMaintain a heap in place.",
                 heappush_max_call,
                 1
             ),
             Method(
                 "heapreplace",
                 0,
                 "heapreplace($module, heap, item, /)\n--\n\nMaintain a heap in place.",
                 heapreplace_call,
                 1
             ),
             Method(
                 "heapreplace_max",
                 0,
                 "heapreplace_max($module, heap, item, /)\n--\n\nMaintain a heap in place.",
                 heapreplace_max_call,
                 1
             ),
             Method(
                 "heappushpop",
                 0,
                 "heappushpop($module, heap, item, /)\n--\n\nMaintain a heap in place.",
                 heappushpop_call,
                 1
             ),
             Method(
                 "heappushpop_max",
                 0,
                 "heappushpop_max($module, heap, item, /)\n--\n\nMaintain a heap in place.",
                 heappushpop_max_call,
                 1
             ),
             Method(
                 "heappop",
                 0,
                 "heappop($module, heap, /)\n--\n\nMaintain a heap in place.",
                 heappop_call,
                 8
             ),
             Method(
                 "heappop_max",
                 0,
                 "heappop_max($module, heap, /)\n--\n\nMaintain a heap in place.",
                 heappop_max_call,
                 8
             ),
             Method(
                 "heapify",
                 0,
                 "heapify($module, heap, /)\n--\n\nMaintain a heap in place.",
                 heapify_call,
                 8
             ),
             Method(
                 "heapify_max",
                 0,
                 "heapify_max($module, heap, /)\n--\n\nMaintain a heap in place.",
                 heapify_max_call,
                 8
             )
         ]
     );

def:pub PyInit__heapq -> u64 {
    return definition.initialize();
}
