"""Meaning Typed Programming constructs for Jac Language."""
import from collections.abc { Callable }
obj MTRuntime {
    has caller: Callable;
    has args: dict[int | str, object];
    has call_params: dict[str, object];

    static def factory(
        caller: Callable, args: dict[int | str, object], call_params: dict[str, object]
    ) -> MTRuntime {
        return MTRuntime(caller=caller, args=args, call_params=call_params);
    }
}

obj MTIR {
    has caller: Callable;
    has args: dict[int | str, object];
    has call_params: dict[str, object];

    @property
    def runtime()  -> MTRuntime {
        return MTRuntime.factory(self.caller, self.args, self.call_params);
    }
}
