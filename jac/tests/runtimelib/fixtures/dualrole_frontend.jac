"""Client component that reaches the guestbook walkers over RPC (#6507).

The client-context `import from .dualrole_guestbook` is the cl->sv edge that makes the
guestbook module load server-side as an endpoint provider for the browser.
"""


import from .dualrole_guestbook { sign_guestbook, get_guestbook }

def:pub Panel -> JsxElement {
    has names: str = "";

    async can with entry {
        gb = await get_guestbook();
        names = str(gb);
    }

    <div id="panel">{names}</div>
}
