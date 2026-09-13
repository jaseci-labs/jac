"""Argument ownership and signature binding shared by native Python adapters."""
import from jaclang.runtime.python.capi {
    boundary_failure,
    required,
    object_error,
    text_value,
    jacpy_release,
    jacpy_retain,
    jacpy_tuple_size,
    jacpy_tuple_item,
    jacpy_dict_items,
    jacpy_list_size,
    jacpy_list_item,
    jacpy_is_unicode,
    jacpy_unicode_size,
    jacpy_unicode_char,
    jacpy_index,
    jacpy_error_pending
}
import from c { def jacpy_ssize(value: u64) -> i64;  }

obj BoundArguments {
    has values: list[u64],
        context: u64 = 0,
        keywords: u64 = 0;

    def drop {
        for value in self.values {
            jacpy_release(value);
        }
        jacpy_release(self.keywords);
    }
}

def invalid(message: str) -> bool {
    object_error("TypeError", message);
    return False;
}

def index_value(value: u64) -> (i64 | None) {
    index = jacpy_index(value);
    if index == 0 {
        return None;
    }
    try {
        result = jacpy_ssize(index);
        if result == -1 and jacpy_error_pending() != 0 {
            return None;
        }
        return result;
    } finally {
        jacpy_release(index);
    }
}

obj CallSignature {
    has name: str,
        names: list[str],
        required_count: int,
        positional_count: int,
        positional_only: int = 0;

    def bind(result: BoundArguments, args: u64, kwargs: u64) -> bool {
        count = int(jacpy_tuple_size(args));
        if count < 0 {
            return False;
        }
        if count > self.positional_count {
            return invalid(
                f"{self.name}() takes at most {self.positional_count} positional arguments ({count} given)"
            );
        }
        for i in range(count) {
            result.values[i] = required(jacpy_tuple_item(args, i64(i)));
        }
        if kwargs != 0 {
            items = required(jacpy_dict_items(kwargs));
            try {
                for i in range(int(jacpy_list_size(items))) {
                    item = required(jacpy_list_item(items, i64(i)));
                    key: u64 = 0;
                    try {
                        key = required(jacpy_tuple_item(item, 0));
                        if jacpy_is_unicode(key) == 0 {
                            return invalid("keywords must be strings");
                        }
                        name = text_value(key);
                        index = -1;
                        for j in range(self.positional_only, len(self.names)) {
                            if self.names[j] == name {
                                index = j;
                                break;
                            }
                        }
                        if index < 0 {
                            return invalid(
                                f"{self.name}() got an unexpected keyword argument '{name}'"
                            );
                        }
                        if result.values[index] != 0 {
                            return invalid(
                                f"argument for {self.name}() given by name ('{name}') and position ({index
                                    + 1})"
                            );
                        }
                        result.values[index] = required(jacpy_tuple_item(item, 1));
                    } finally {
                        jacpy_release(key);
                        jacpy_release(item);
                    }
                }
            } finally {
                jacpy_release(items);
            }
        }
        for i in range(self.required_count) {
            if result.values[i] == 0 {
                return invalid(
                    f"{self.name}() missing required argument '{self.names[i]}' (pos {i
                        + 1})"
                );
            }
        }
        return True;
    }
}

def invoke(
    signature: CallSignature,
    args: u64,
    kwargs: u64,
    implementation: Callable[[BoundArguments], u64],
    context: u64 = 0,
    forward_keywords: bool = False
) -> u64 {
    # The call frame lives outside the exception region: every exit releases
    # all converted arguments, including a failure in a nested conversion.
    bound = BoundArguments([u64(0) for _ in signature.names], context);
    if forward_keywords and kwargs != 0 {
        bound.keywords = jacpy_retain(kwargs);
    }
    try {
        if not signature.bind(bound, args, u64(0) if forward_keywords else kwargs) {
            return 0;
        }
        return implementation(bound);
    } except boundary_failure {
        return 0;
    }
}

def invoke_one(value: u64, implementation: Callable[[u64], u64]) -> u64 {
    try {
        return implementation(value);
    } except boundary_failure {
        return 0;
    }
}

def character_value(value: u64, context: str) -> (i64 | None) {
    if jacpy_is_unicode(value) == 0 or jacpy_unicode_size(value) != 1 {
        object_error("TypeError", f"{context}() argument must be a unicode character");
        return None;
    }
    return jacpy_unicode_char(value, 0);
}
