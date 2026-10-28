import from "lucide-react" { AlertCircle }

def:pub AuthForm(
    isSignup: bool,
    username: str,
    password: str,
    error: str,
    loading: bool,
    onUsernameChange: Callable[[ChangeEvent], None],
    onPasswordChange: Callable[[ChangeEvent], None],
    email: str = "",
    onEmailChange: Callable[[ChangeEvent], None] = lambda (e: ChangeEvent) {},
    onSubmit: Callable[[FormEvent], None],
    onToggleMode: Callable[[], None],
    githubEnabled: bool = False,
    onGithub: Callable[[], None] = lambda {},
) -> JsxElement;
