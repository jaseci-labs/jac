import from "@jac/runtime" {
    RemoteRejected,
    sign_in,
    sign_out,
    signed_in_name,
    __removeLocalStorage,
}

"""Who is using JacYac: whether they are signed in, and what they are called.
How one signs in is the app's auth plugin's to say (jac.toml's `[auth]`): a
page asks only to be signed in."""
obj Session {
    has loggedIn: bool,
        checking: bool,
        username: str,
        error: str,
        busy: bool,
        login: Callable[[], Coroutine[any, any, None]],
        logout: Callable[[], Coroutine[any, any, None]];
}

def useSession -> Session;
