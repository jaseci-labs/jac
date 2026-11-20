import from "@jac/mobui" { View, Text, Pressable, TextInput, ActivityIndicator }

def Composer(
    avatars: dict[str, str],
    username: str,
    placeholder: str,
    value: str,
    onChange: Callable[[str], None],
    onPost: Callable[[], Coroutine[any, any, None]],
    busy: bool = False,
    buttonLabel: str = "Post",
) -> JsxElement;
