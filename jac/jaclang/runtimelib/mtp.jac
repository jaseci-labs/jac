"""Meaning Typed Programming constructs for Jac Language."""
import from collections.abc { Callable }
obj MTRuntime {
    has caller: Callable,
        args: dict[(int | str, object)],
        call_params: dict[(str, object)];

    static def factory(
        caller: Callable, args: dict[int | str, object], call_params: dict[str, object]
    ) -> MTRuntime;
}

obj MTIR {
    has caller: Callable,
        args: dict[(int | str, object)],
        call_params: dict[(str, object)];

    @property
    def runtime -> MTRuntime;
}
