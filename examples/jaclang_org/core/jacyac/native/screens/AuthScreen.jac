import from "@jac/mobui" {
    View,
    Text,
    Pressable,
    ActivityIndicator,
    ScrollView,
    StatusBar,
    useWindowDimensions,
}

"""What JacYac shows a caller who is not signed in: why, and a way in. What
signing in takes is the app's auth plugin's to ask."""
def AuthScreen(
    error: str,
    loading: bool,
    onSignIn: Callable[[], Coroutine[any, any, None]],
    embedded: bool = False,
) -> JsxElement;
