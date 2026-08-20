"""The configured `auth_redirect` target, at a non-default path: a guard that
drops the config lands on `/login`, which is not a route here."""

def:pub page -> JsxPage {
    <div data-testid="signin">Sign in</div>
}
