"""Python bisection signatures and initialization, compiled into JacPython."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodDefinition
}
import from jaclang.runtime.python.bindings.arguments {
    CallSignature,
    BoundArguments,
    invoke,
    index_value
}
import from jaclang.runtime.python.modules.bisect { jacpy_bisect }
import from jaclang.runtime.python.capi { jacpy_is_none }

def signature(name: str) -> CallSignature {
    return CallSignature(name, ["a", "x", "lo", "hi", "key"], 2, 4);
}

glob left_signature = signature("bisect_left"),
     right_signature = signature("bisect_right"),
     insert_left_signature = signature("insort_left"),
     insert_right_signature = signature("insort_right");

def search(args: BoundArguments, right: i64, insert: i64) -> u64 {
    low: i64 = 0;
    high: i64 = -1;
    if args.values[2] != 0 {
        value = index_value(args.values[2]);
        if value is None {
            return 0;
        }
        low = value;
    }
    if args.values[3] != 0 and jacpy_is_none(args.values[3]) == 0 {
        value = index_value(args.values[3]);
        if value is None {
            return 0;
        }
        high = value;
    }
    key = args.values[4];
    if key != 0 and jacpy_is_none(key) != 0 {
        key = 0;
    }
    return jacpy_bisect(args.values[0], args.values[1], low, high, key, right, insert);
}

def left(args: BoundArguments) -> u64 {
    return search(args, 0, 0);
}

def right(args: BoundArguments) -> u64 {
    return search(args, 1, 0);
}

def insert_left(args: BoundArguments) -> u64 {
    return search(args, 0, 1);
}

def insert_right(args: BoundArguments) -> u64 {
    return search(args, 1, 1);
}

def call_left(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(left_signature, args, kwargs, left);
}

def call_right(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(right_signature, args, kwargs, right);
}

def call_insert_left(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(insert_left_signature, args, kwargs, insert_left);
}

def call_insert_right(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(insert_right_signature, args, kwargs, insert_right);
}

glob definition = ModuleDefinition(
         "_bisect",
         "Bisection algorithms implemented in native Jac.",
         [
             MethodDefinition(
                 "bisect_left",
                 call_left,
                 "bisect_left($module, /, a, x, lo=0, hi=None, *, key=None)\n--\n\nReturn the insertion index before existing equal items."
             ),
             MethodDefinition(
                 "bisect_right",
                 call_right,
                 "bisect_right($module, /, a, x, lo=0, hi=None, *, key=None)\n--\n\nReturn the insertion index after existing equal items."
             ),
             MethodDefinition(
                 "insort_left",
                 call_insert_left,
                 "insort_left($module, /, a, x, lo=0, hi=None, *, key=None)\n--\n\nInsert x before existing equal items in sorted sequence a."
             ),
             MethodDefinition(
                 "insort_right",
                 call_insert_right,
                 "insort_right($module, /, a, x, lo=0, hi=None, *, key=None)\n--\n\nInsert x after existing equal items in sorted sequence a."
             )
         ]
     );

def:pub PyInit__bisect -> u64 {
    return definition.initialize();
}
