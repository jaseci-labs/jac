impl MTIR.runtime -> MTRuntime {
    return MTRuntime.factory(self.caller, self.args, self.call_params);
}

impl MTRuntime.factory(
    caller: Callable, args: dict[int | str, object], call_params: dict[str, object]
) -> MTRuntime {
    return MTRuntime(caller=caller, args=args, call_params=call_params);
}
