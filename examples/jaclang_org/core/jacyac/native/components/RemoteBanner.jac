import from "@jac/mobui" { View, Text, Pressable }

def RemoteBanner(
    message: str,
    canRetry: bool,
    onRetry: Callable[[], Coroutine[any, any, None]],
    onDismiss: Callable[[], None],
) -> JsxElement;
