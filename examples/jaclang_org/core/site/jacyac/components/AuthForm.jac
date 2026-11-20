import from "lucide-react" { AlertCircle }

"""What JacYac shows a caller who is not signed in: why, and a way in. What
signing in takes is the app's auth plugin's to ask."""
def:pub AuthForm(
    error: str, loading: bool, onSignIn: Callable[[], Coroutine[any, any, None]]
) -> JsxElement;
