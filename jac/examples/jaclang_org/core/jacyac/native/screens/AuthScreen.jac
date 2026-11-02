import from "@jac/mobui" {
    View,
    Text,
    Pressable,
    TextInput,
    KeyboardAvoidingView,
    ActivityIndicator,
    ScrollView,
    StatusBar,
    useWindowDimensions,
    Platform
}

def:pub AuthScreen(
    isSignup: bool,
    username: str,
    password: str,
    error: str,
    loading: bool,
    onUsernameChange: Callable[[str], None],
    onPasswordChange: Callable[[str], None],
    email: str = "",
    onEmailChange: Callable[[str], None] = lambda (t: str) {},
    onSubmit: Callable[[], None],
    onToggleMode: Callable[[], None],
    githubEnabled: bool = False,
    onGithub: Callable[[], None] = lambda {},
    embedded: bool = False,
) -> JsxElement;
