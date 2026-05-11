"""FilterSpec implementation."""

impl FilterSpec.__call__(item: Any) -> bool {
    return self.func(item);
}
