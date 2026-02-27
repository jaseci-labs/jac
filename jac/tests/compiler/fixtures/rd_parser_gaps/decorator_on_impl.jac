# Decorator on impl definition
def my_decorator(func: Any) -> Any {
    return func;
}

obj MyObj {
    def greet -> None;
}

@my_decorator
impl MyObj.greet -> None {
    print("hello");
}
