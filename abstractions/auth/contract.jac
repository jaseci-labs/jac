"""The contract of the `auth` abstraction: `Auth`, the interface of the plugin
that says who a caller is and signs one in, what crosses it, and `AuthHost`,
what such a plugin may ask of the program it runs in."""

import from common.contract { Host }

"""Something a caller gives to sign in: its `name`, what a page calls it,
whether it is kept from sight as it is typed, and, when only some values are
taken, which."""
obj SignInField {
    has name: str,
        label: str = "",
        secret: bool = False,
        choices: list[str] = [];
}

"""A way of signing in a page offers: its `name`, which `Auth.answer` is
given, what a page calls it, and the fields it takes; or, for one done
elsewhere, the place to go, `redirect`, from which the caller comes back to
`/__jac/auth/<name>` with what that place gave them. What `keeps` holds
stays with the page that left, and is given to `Auth.answer` beside what the
caller came back with: so a plugin can tell the caller who left from one who
was only handed the way back."""
obj SignInAction {
    has name: str,
        label: str = "",
        needs: list[str] = [],
        redirect: str = "",
        keeps: dict[str, str] = {};
}

"""A caller signed in: who they are, the credential their calls carry from
now on ("" where the plugin knows a caller by something else its requests
carry), and what they are called, where that is not who they are (the name
another service knows them by)."""
obj Session {
    has user: str,
        token: str = "",
        name: str = "";
}

"""What signing in takes, as a page shows it: a form of `fields` with its
`actions`; or a place to go, `redirect`; or nothing, for a caller the plugin
knows already, whose `session` it is."""
obj SignIn {
    has fields: list[SignInField] = [],
        actions: list[SignInAction] = [],
        redirect: str = "",
        session: Session | None = None;
}

"""A sign-in the plugin refuses, saying why: and, for one made too often, how
many seconds to wait."""
obj Rejected(Exception) {
    has detail: str,
        retry_after: int = 0;

    def __str__ -> str {
        return self.detail;
    }
}

"""What an `auth` plugin may ask of the program it runs in: what every
plugin may (`Host`), and

- `windowed`, whether the app shows itself in a window of its own, on its
  user's machine: where a plugin may know its one user without a password.
- `consume_limit`, which counts a use of `scope` by `actor` with the
  project's `limits`, and gives 0 while that is within `limit` uses in
  `seconds`, else the seconds until it is: how a plugin holds sign-ins to
  so many tries."""
obj AuthHost(Host) {
    def windowed -> bool abst;
    def consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int abst;
}

"""Who a caller is, and how one signs in: the interface of the `auth`
abstraction's plugins. `headers` are a request's, their names lowercased.

- `open` makes it ready, in the program `host`: the first thing asked of
  it. DataError (`common.contract`) for data it keeps that it can't start
  with.
- `caller` is who a request's caller is, or None for one it does not know.
- `asks` is what signing in takes, for a page to show.
- `answer` signs a caller in by `action` with what they gave, from the
  client at `client`: their session, or Rejected.
- `leave` ends the session a request carries."""
obj Auth {
    def open(host: dyn AuthHost) abst;
    def caller(headers: dict[str, str]) -> str | None abst;
    def asks(headers: dict[str, str]) -> SignIn abst;
    def answer(action: str, given: dict[str, str], client: str) -> Session abst;
    def leave(headers: dict[str, str]) abst;
}

"""The credential a request with `headers` carries as a bearer token, or ""."""
def bearer_token(headers: dict[str, str]) -> str {
    return headers.get("authorization", "").removeprefix("Bearer ").strip();
}
