"""Test fixture for reactive effects with dependencies (can with [deps] entry in client context).

Note: useEffect import is auto-injected from @jac/runtime when `can with entry/exit` is used.
"""

cl {
    def:pub user_profile(userId: str) -> JsxElement {
        has userData: dict = {};
        has loading: bool = True;

        # Effect with dependencies (tuple syntax) - re-runs when userId or loading changes
        async can with (userId, loading) entry {
            loading = True;
            userData = await fetch_user(userId);
            loading = False;
        }

        return <div>
            <p>User: {userData}</p>
            <p>Loading: {loading}</p>
        </div>;
    }
}
