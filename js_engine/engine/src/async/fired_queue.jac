"""Generic async fired-callback queue (timers, fs, net share this pattern)."""

obj FiredQueue {
    has fns: list[any] = [],
        args: list[any] = [];

    def count -> int {
        return len(self.fns);
    }

    def push(fn: any, arg_list: list[any]) {
        self.fns.append(fn);
        self.args.append(arg_list);
    }

    def peek_fn(i: int) -> any {
        return self.fns[i];
    }

    def peek_args(i: int) -> list[any] {
        return self.args[i];
    }

    def clear_front(n: int) -> None {
        # O(remaining) rebuild — repeated `del [0]` is O(n) per pop (O(n^2) drain).
        if n <= 0 {
            return;
        }
        fn_kept: list[any] = [];
        arg_kept: list[any] = [];
        i: int = n;
        n_total: int = len(self.fns);
        while i < n_total {
            fn_kept.append(self.fns[i]);
            arg_kept.append(self.args[i]);
            i = i + 1;
        }
        self.fns = fn_kept;
        self.args = arg_kept;
    }
}

def make_fired_queue -> FiredQueue {
    return FiredQueue();
}
