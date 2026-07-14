"""Client component that reaches the guestbook walkers over RPC (#6507).

The `sv import from .dualrole_guestbook` is the cl->sv edge that makes the
guestbook module load server-side as an endpoint provider for the browser.
"""

sv import from .dualrole_guestbook { sign_guestbook, get_guestbook }

cl def:pub Panel() -> JsxElement {
    has names: str = "";

    async can with entry {
        gb = await get_guestbook();
        names = str(gb);
    }

    return
        <div id="panel">{names}</div>;
}
