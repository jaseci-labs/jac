import from "lucide-react" { AlertCircle }

def:pub ProfileEditor(
    profile: Profile,
    saving: bool,
    error: str,
    onSave: Callable[[dict[str, str]], Coroutine[any, any, None]],
    onCancel: Callable[[], None],
) -> JsxElement;
