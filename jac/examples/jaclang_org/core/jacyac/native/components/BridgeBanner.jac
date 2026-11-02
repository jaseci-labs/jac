import from "@jac/mobui" { View, Text, Pressable }

def:pub BridgeBanner(
    message: str,
    canRetry: bool,
    onRetry: Callable[[], None],
    onDismiss: Callable[[], None],
) -> JsxElement;
