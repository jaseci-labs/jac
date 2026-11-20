// `@jac/runtime`'s part every JS space shares: who's calling, and what they keep.
import * as $j from "./core.js";

const kept = new Map();
// Where the name a session came with is kept, beside its token.
const NAME_KEY = "jac_name";
const store = () => { try { return typeof localStorage === "undefined" ? null : localStorage; } catch (_) { return null; } };

export const RemoteError = $j.RemoteError;
export const RemoteUnavailable = $j.RemoteUnavailable;
export const RemoteTimeout = $j.RemoteTimeout;
export const RemoteRejected = $j.RemoteRejected;
export const RemoteDecodeError = $j.RemoteDecodeError;
export const RemoteFailed = $j.RemoteFailed;

// What a desktop app's page asks of the app itself (stdjac.app's app_route):
// nothing, where the page is not in an app's window.
async function appAsk(path, body) {
    const asked = body === undefined ? {} : { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) };
    const res = await fetch($j.apiBase() + "/__jac/app/" + path, asked);
    if (res.status === 404) return null;
    const data = await res.json();
    if (!data.ok) throw new $j.RemoteRejected("app", path, data.detail);
    return data.data;
}
// Which arrangement of its app the page's app is (`current`), which it may be
// (`names`: none for an app with one), and whether its user chose it.
export async function jacArrangement() {
    return (await appAsk("arrangement")) || { names: [], current: "", chosen: true };
}
// Choose arrangement `name`: the app starts again as it, signed in to no one.
export async function jacUseArrangement(name) {
    await appAsk("arrangement", { name });
    $j.setToken("");
    __removeLocalStorage(NAME_KEY);
}
export const __getLocalStorage = (k) => { const s = store(); return s ? s.getItem(k) : (kept.has(k) ? kept.get(k) : null); };
export const __setLocalStorage = (k, v) => { const s = store(); if (s) s.setItem(k, v); else kept.set(k, String(v)); };
export const __removeLocalStorage = (k) => { const s = store(); if (s) s.removeItem(k); else kept.delete(k); };
export const __getApiBaseUrl = $j.apiBase;

// Signing in, by whatever the project's auth plugin takes (stdjac.server's
// auth_route). A page says only that it wants a signed-in caller: the plugin
// says what that takes, a form or a place to go, and answers it.
const authHeaders = () => { const t = $j.token(); return t ? { Authorization: "Bearer " + t } : {}; };
async function authGet(path) {
    const res = await fetch($j.apiBase() + "/__jac/auth/" + path, { headers: authHeaders() });
    if (res.status === 401) return null;
    const data = await res.json();
    if (!data.ok) throw new $j.RemoteRejected("auth", path, data.detail);
    return data.data;
}
// Whether the caller is signed in, as the app's auth says.
export async function signed_in() {
    return (await authGet("me")) !== null;
}
// Who the caller is signed in as, or "" for no one.
export async function signed_in_as() {
    const me = await authGet("me");
    return me ? me.user : "";
}
// What the caller is called: the name the app's auth gave as they signed in
// (the one another service knows them by), else who they are; "" for no one.
export async function signed_in_name() {
    const me = await authGet("me");
    return me ? __getLocalStorage(NAME_KEY) || me.user : "";
}
// Keep a session the app's auth gave: its token, and the name with it.
function keep(session) {
    $j.setToken(session.token);
    if (session.name) __setLocalStorage(NAME_KEY, session.name);
    else __removeLocalStorage(NAME_KEY);
}
// Sign the caller out: their session is ended, and its token forgotten.
export async function sign_out() {
    await fetch($j.apiBase() + "/__jac/auth/logout", { method: "POST", headers: authHeaders() });
    $j.setToken("");
    __removeLocalStorage(NAME_KEY);
}
// Sign the caller in: true once they are, false if they turned the form away.
// One the plugin knows already is signed in at once; one it sends elsewhere
// goes there, and comes back signed in.
export async function sign_in() {
    if (await signed_in()) return true;
    const asks = await authGet("");
    if (asks.session) {
        keep(asks.session);
        return true;
    }
    if (asks.fields.length === 0 && asks.actions.length === 0) {
        if (!asks.redirect) throw new $j.RemoteRejected("auth", "sign_in", "the app's auth offers no way of signing in");
        return leaveFor(asks.redirect, {});
    }
    const shown = shower ? shower(asks, answerForm) : null;
    if (shown) return shown;
    return askForm(asks);
}
// What shows the form in place of the page's own: a `ui` plugin's runtime, where
// there is no page to draw it on (React Native). It is given what signing in
// takes and `answerForm`, and gives a promise of whether the caller signed in,
// or null to leave the form to the page.
let shower = null;
export function __showSignIn(show) {
    shower = show;
}
// One way of signing in, tried with what the caller gave: `{ok: true}` once
// they are signed in, and their session kept; `{ok: false, detail}` with the
// plugin's reason when it refuses.
async function answerForm(action, given) {
    try {
        keep(await $j.authPost(action.name, given));
        return { ok: true };
    } catch (e) {
        if (!(e instanceof $j.RemoteRejected)) throw e;
        return { ok: false, detail: e.detail };
    }
}
// Go to `url`, where the caller signs in and is sent back: nothing follows
// here. What the way of signing in asks the page to keep, and where the
// caller left from, stay in this tab for the page they come back to
// (stdjac.server's CAME_BACK).
function leaveFor(url, keeps) {
    if (typeof location === "undefined" || typeof sessionStorage === "undefined") throw new $j.RemoteRejected("auth", "sign_in", "signing in is done at " + url + ", which this host cannot open");
    sessionStorage.setItem("jac_sign_in", JSON.stringify({ keeps, back: location.pathname + location.search + location.hash }));
    location.assign(url);
    return new Promise(() => {});
}
// The plugin's form, shown over the page: a field for each it asks for, a
// button for each way of signing in, and what it refused the last try with.
// Its parts carry the classes `jac-sign-in*`, which a project's CSS styles.
function askForm(asks) {
    if (typeof document === "undefined") throw new $j.RemoteRejected("auth", "sign_in", "the app's auth asks for " + asks.fields.map((f) => f.name).join(", ") + ", and this host shows no form");
    return new Promise((resolve) => {
        const el = (tag, cls, text) => { const e = document.createElement(tag); e.className = cls; if (text !== undefined) e.textContent = text; return e; };
        const back = el("div", "jac-sign-in");
        back.setAttribute("role", "dialog");
        back.setAttribute("aria-modal", "true");
        if (!document.getElementById("jac-sign-in-style")) {
            const style = el("style", "");
            style.id = "jac-sign-in-style";
            style.textContent = ":where(.jac-sign-in){position:fixed;inset:0;display:grid;place-items:center;background:rgba(0,0,0,.45);z-index:2147483000;font:16px system-ui,sans-serif}"
                + ":where(.jac-sign-in-form){display:grid;gap:.75rem;min-width:18rem;max-width:90vw;padding:1.5rem;border-radius:.75rem;background:Canvas;color:CanvasText;box-shadow:0 1rem 3rem rgba(0,0,0,.3)}"
                + ":where(.jac-sign-in-field){display:grid;gap:.25rem}:where(.jac-sign-in-field input,.jac-sign-in-field select){font:inherit;padding:.5rem}"
                + ":where(.jac-sign-in-actions){display:flex;flex-wrap:wrap;gap:.5rem;justify-content:flex-end}:where(.jac-sign-in-actions button){font:inherit;padding:.5rem 1rem}"
                + ":where(.jac-sign-in-error){color:#b00020;min-height:1.25em;margin:0}";
            document.head.appendChild(style);
        }
        const form = el("form", "jac-sign-in-form");
        const inputs = {};
        for (const f of asks.fields) {
            const row = el("label", "jac-sign-in-field", f.label || f.name);
            const input = el("input", "jac-sign-in-input");
            input.name = f.name;
            input.type = f.secret ? "password" : "text";
            if (f.choices.length > 0) {
                const list = el("datalist", "");
                list.id = "jac-sign-in-" + f.name;
                for (const c of f.choices) { const o = el("option", ""); o.value = c; list.appendChild(o); }
                input.setAttribute("list", list.id);
                row.appendChild(list);
            }
            row.appendChild(input);
            form.appendChild(row);
            inputs[f.name] = input;
        }
        const error = el("p", "jac-sign-in-error", "");
        error.setAttribute("role", "alert");
        form.appendChild(error);
        const done = (ok) => { back.remove(); resolve(ok); };
        const run = async (action) => {
            if (action.redirect) { leaveFor(action.redirect, action.keeps || {}); return; }
            const given = {};
            for (const name of action.needs) if (inputs[name]) given[name] = inputs[name].value;
            const said = await answerForm(action, given);
            if (said.ok) done(true);
            else error.textContent = said.detail;
        };
        const buttons = el("div", "jac-sign-in-actions");
        const cancel = el("button", "jac-sign-in-cancel", "Cancel");
        cancel.type = "button";
        cancel.onclick = () => done(false);
        buttons.appendChild(cancel);
        asks.actions.forEach((action, k) => {
            const b = el("button", "jac-sign-in-action", action.label || action.name);
            b.type = k === 0 ? "submit" : "button";
            b.onclick = (ev) => { ev.preventDefault(); run(action); };
            buttons.appendChild(b);
        });
        form.appendChild(buttons);
        form.onsubmit = (ev) => { ev.preventDefault(); if (asks.actions.length > 0) run(asks.actions[0]); };
        back.onkeydown = (ev) => { if (ev.key === "Escape") done(false); };
        back.appendChild(form);
        document.body.appendChild(back);
        const first = form.querySelector("input");
        if (first) first.focus();
    });
}
