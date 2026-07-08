"""jachammer app state hook — `useStudio()` over a React Context.

Same idea as jacBuilder's `useIDE()` (one hook returning a big `{state + actions}`
dict), adapted to React Native / Expo: instead of prop-drilling the dict down a
single page tree (jacBuilder's web-SPA approach), we distribute it through a
`StudioProvider` + Context. That's the idiomatic RN/Expo choice — sibling screens
mounted under one provider read the same state without threading a `studio` prop
through every level:

    s = useStudio();
    s["projects"];  s["deploy"](pid);  s["setTab"]("home");

`StudioProvider` holds every `has` field, the mount effect, the derived theme
(`C`/`styles`), and every action (which call the thin wrappers in
`services/api.cl.jac`). Components/screens read state, invoke actions, or
write UI state via the auto-generated `set<Field>` setters re-exported in the
context value dict.
"""

cl {
    import from "@jac/mobui" {
        View,
        Animated,
        Easing,
        createAnimatedValue,
        Keyboard,
        Platform
    }
    import from "react-native" { Alert }
    import from react { createContext, useContext }
    import from ..ui.theme { DARK, LIGHT, STYLES_DARK, STYLES_LIGHT }
    import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn }
    import from ..lib.constants { JB_API }
    import from ..lib.mappers { prettyModel, jbStatus, jbProj, jbComm, jbMsg }
    import from ..lib.authcookies { clearAuthCookies }
    import from ..services.api {
        jbMe, jbUserInfo, jbProjectsList, jbProjectCreate, jbProjectRename, jbProjectDelete,
        jbClaimSession,
        jbTemplatesList, jbCommunityList, jbCommunityClone, jbCommunitySubmit,
        jbChatStart, jbChatHistory, jbChatPoll, jbChatPersist, jbModelSwitch, jbFilesList, jbFileRead,
        jbDeploy, jbDestroy, jbMonitor, jbPreviewStart, jbDeployStatus
    }

    # ai_chat build events stream over this WS walker (jacBuilder's transport);
    # the HTTP `poll` action can't return events (no connection_id param).
    # NB: unlike the HTTP walker routes (/walker/X), the gateway's WS catchall
    # only routes paths under the service prefix — /ws/… alone connects then
    # closes with 1008 (verified against the live server). Hence /api/builder_sv.
    def wsBuildUrl(base: str) -> str {
        if base.startswith("https://") { return "wss://" + base[8:] + "/api/builder_sv/ws/ide_preview_stream"; }
        return "ws://" + base[7:] + "/api/builder_sv/ws/ide_preview_stream";
    }

    # Splash entrance animation value — created once at module load.
    glob:pub intro = createAnimatedValue(0);

    glob:pub StudioContext = createContext(None);

    # Consume the studio state from any screen/component.
    def:pub useStudio -> any {
        return useContext(StudioContext);
    }

    # ══════════════════════════════════════════════════════════════════════════
    #  PROVIDER — all state + actions live here; exposed via context value dict
    # ══════════════════════════════════════════════════════════════════════════
    def:pub StudioProvider(children: any) -> JsxElement {
        has screen: str = "splash",
            appTheme: str = "dark",
            authMode: str = "login",
            authUser: str = "",
            authPass: str = "",
            authPass2: str = "",
            authError: str = "",
            me: str = "",
            credits: int = 0,
            plan: str = "Free",
            billing: dict = {},
            model: str = "claude-opus-4-8",
            tab: str = "home",
            projects: list = [],
            activity: list = [],
            communityItems: list = [],
            curFiles: list = [],
            templates: list = [],
            models: list = [],
            monitor: dict = {},
            monLogs: list = [],
            monLoading: bool = False,
            messages: list = [],
            selId: str = "",
            detTab: str = "chat",
            projQuery: str = "",
            query: str = "",
            sort: str = "updated",
            prompt: str = "",
            showNew: bool = False,
            newMode: str = "template",
            newName: str = "",
            newTemplate: str = "",
            newRepo: str = "",
            fileView: str = "",
            fileBody: str = "",
            notifOpen: bool = False,
            modelSheet: bool = False,
            projMenu: str = "",
            renameId: str = "",
            renameVal: str = "",
            shareId: str = "",
            shareDesc: str = "",
            shareTags: str = "",
            deleteId: str = "",
            billingOpen: bool = False,
            seenCount: int = 0,
            notifEnabled: bool = True,
            previewOn: bool = False,
            previewReady: bool = False,
            previewUrl: str = "",
            previewNonce: int = 0,
            autoPreview: bool = False,
            connId: str = "",
            ssoUrl: str = "",
            ssoProvider: str = "",
            viewport: str = "mobile",
            deployMode: str = "sandbox",
            prodStep: int = 0,
            prodDomain: str = "",
            tlsOn: bool = True,
            # Per-operation loading flags, keyed by op name ("auth", "create",
            # "prompt", "chat", "deploy", "clone", "rename", "delete", "publish").
            busy: dict = {};

        # ── active theme (runtime toggle) ─────────────────────────────────────
        light = appTheme == "light";
        C = LIGHT if light else DARK;
        styles = STYLES_LIGHT if light else STYLES_DARK;

        async can with entry {
            # Route every walker call to the hosted jacBuilder backend (overrides
            # the dev-injected local URL). Checked first by the runtime resolver.
            globalThis.__JAC_API_BASE_URL__ = JB_API;
            # A stable per-client connection id for project session claims.
            connId = "jh-" + str(Math.floor(Math.random() * 1000000000));
            Animated.timing(
                intro,
                {toValue: 1, duration: 500, easing: Easing.out(Easing.cubic), useNativeDriver: True}
            ).start();
            # If a JWT is already stored, re-enter the app; otherwise → auth.
            restoreSession();
        }

        # Pure mappers (jbStatus / jbProj / jbComm / jbMsg / prettyModel) live in
        # lib/mappers.cl.jac — they need no component state.

        # ── loading flags — actions toggle these around their awaits so buttons
        #    can show a spinner + disable while a walker call is in flight ──────
        def markBusy(key: str, val: bool) -> None {
            console.log("[jh] markBusy", key, val);
            # Functional state update: several actions flip different busy keys in
            # the same tick (e.g. "chat" then "preview"); a plain `busy = {**busy…}`
            # reads a stale closure and the later call drops the earlier key. The
            # lambda receives the freshest state so every flag survives.
            busy = lambda(prev: dict) { nb = {** prev}; nb[key] = val; return nb; };
        }

        def isBusy(key: str) -> bool {
            return (key in busy) and busy[key];
        }

        # ── data loaders (call the service layer) ─────────────────────────────
        async def jbLoadProjects -> None {
            d = await jbProjectsList();
            if ("success" in d) and d["success"] {
                projects = [jbProj(p) for p in d["projects"]];
            }
        }

        # hint: the typed username on login (stored server-side as display_name);
        # "" on restore. Returns whether the account loaded.
        async def jbLoadAccount(hint: str) -> bool {
            d = await jbMe(hint);
            if not (("success" in d) and d["success"]) { return False; }
            b = d["billing"] if "billing" in d else {};
            billing = b;
            tier = b["tier"] if "tier" in b else "free";
            plan = tier[0].upper() + tier[1:] if len(tier) > 0 else "Free";
            bal = 0.0;
            if "remaining_usd" in b { bal = bal + float(b["remaining_usd"]); }
            if "topup_balance_usd" in b { bal = bal + float(b["topup_balance_usd"]); }
            credits = int(round(bal));
            allowed = b["models_allowed"] if "models_allowed" in b else [];
            dflt = b["default_model"] if "default_model" in b else "";
            models = [{"id": mid, "name": prettyModel(mid)} for mid in allowed];
            if dflt != "" { model = dflt; }
            # Prefer the real display name; fall back to the typed username we
            # already have, then to the user_id only as a last resort.
            u = d["user"] if "user" in d else {};
            dn = u["display_name"] if ("display_name" in u and u["display_name"]) else "";
            if dn != "" {
                me = dn;
            } elif me == "" {
                me = u["user_id"] if ("user_id" in u and u["user_id"]) else "you";
            }
            return True;
        }

        # Re-enter the app on cold start if a JWT is already stored (jacLogin
        # persists it in SecureStore/localStorage). The native token cache primes
        # asynchronously — await globalThis.__jacPlatformReady__ before checking.
        async def restoreSession -> None {
            ready = globalThis.__jacPlatformReady__;
            if ready { await ready; }
            if not jacIsLoggedIn() {
                if screen == "splash" { screen = "auth"; }
                return;
            }
            ok = await jbLoadAccount("");
            if not ok {
                if screen == "splash" { screen = "auth"; }
                return;
            }
            tab = "home";
            screen = "app";
            jbLoadProjects();
            loadCommunity();
            loadTemplates();
            # Resolve the real display name (not the user_id) on reload too.
            info = await jbUserInfo();
            hint = info["display_name"] if ("display_name" in info and info["display_name"]) else "";
            if hint != "" { me = hint; }
        }

        async def loadTemplates -> None {
            d = await jbTemplatesList();
            if ("success" in d) and d["success"] and ("templates" in d) {
                templates = [
                    {
                        "id": t["id"] if "id" in t else "",
                        "name": t["name"] if "name" in t else (t["id"] if "id" in t else "template"),
                        "desc": t["description"] if "description" in t else ""
                    }
                    for t in d["templates"]
                ];
                if newTemplate == "" and len(templates) > 0 {
                    newTemplate = templates[0]["id"];
                }
            }
        }

        async def loadCommunity -> None {
            d = await jbCommunityList(query);
            if "items" in d {
                communityItems = [jbComm(c) for c in d["items"]];
            }
        }

        async def loadFiles(pid: str) -> None {
            d = await jbFilesList(pid);
            if ("success" in d) and d["success"] and ("files" in d) {
                curFiles = [f for f in d["files"]];
            } else {
                curFiles = [];
            }
        }

        async def openFile(name: str) -> None {
            fileView = name;
            fileBody = "";
            d = await jbFileRead(selId, name);
            if ("success" in d) and d["success"] and ("content" in d) {
                fileBody = str(d["content"]);
            }
        }

        async def loadMonitor(pid: str) -> None {
            monLoading = True;
            monitor = {};
            monLogs = [];
            od = await jbMonitor(pid, "overview", 200, 30);
            md = await jbMonitor(pid, "metrics", 200, 30);
            merged = {** od};
            if ("prometheus" in md) { merged["prometheus"] = md["prometheus"]; }
            if ("resources" in md) { merged["resources"] = md["resources"]; }
            monitor = merged;
            if ("deployed" in od) and od["deployed"] {
                ld = await jbMonitor(pid, "logs", 80, 30);
                lines = [];
                comps: list = ld["components"] if "components" in ld else [];
                for c in comps {
                    clines: list = c["lines"] if "lines" in c else [];
                    for ln in clines {
                        lines = lines + [ln["text"] if "text" in ln else str(ln)];
                    }
                }
                monLogs = lines;
            }
            monLoading = False;
        }

        # ── billing display helpers ───────────────────────────────────────────
        def usd(key: str) -> str {
            v = billing[key] if key in billing else 0;
            return f"${float(v):.2f}";
        }

        def billingRemaining -> str {
            base = float(billing["remaining_usd"]) if "remaining_usd" in billing else 0.0;
            top = float(billing["topup_balance_usd"]) if "topup_balance_usd" in billing else 0.0;
            return f"${(base + top):.2f} left";
        }

        def billingSub -> str {
            used = billing["project_used"] if "project_used" in billing else 0;
            limit = billing["project_limit"] if "project_limit" in billing else 0;
            return f"{used}/{limit} projects · resets monthly";
        }

        # ── derived helpers ───────────────────────────────────────────────────
        def kbBehavior -> str {
            return "padding" if Platform.OS == "ios" else "height";
        }

        def unreadCount -> int {
            n = len(activity) - seenCount;
            return n if n > 0 else 0;
        }

        def selected -> any {
            hit = None;
            for p in projects {
                if p["id"] == selId {
                    hit = p;
                }
            }
            return hit;
        }

        def deviceWidth -> int {
            if viewport == "desktop" { return 320; }
            if viewport == "tablet" { return 300; }
            return 260;
        }

        def statusColor(s: str) -> str {
            if s == "running" { return C.ok; }
            if s == "building" { return C.warn; }
            if s == "failed" { return C.danger; }
            return C.muted;
        }

        def statusLabel(s: str) -> str {
            if s == "running" { return "Running"; }
            if s == "building" { return "Building"; }
            if s == "failed" { return "Failed"; }
            return "Stopped";
        }

        def kindColor(k: str) -> str {
            if k == "deploy" { return C.forge; }
            if k == "create" { return C.accent; }
            if k == "stop" { return C.danger; }
            return C.muted;
        }

        def patch(p: any, status: str, progress: int, updated: str) -> dict {
            return {
                "id": p["id"], "name": p["name"], "template": p["template"],
                "branch": p["branch"], "status": status, "progress": progress,
                "region": p["region"], "url": p["url"], "files": p["files"],
                "services": p["services"], "logs": p["logs"], "updated": updated
            };
        }

        def applyPatch(pid: str, status: str, progress: int, updated: str) -> None {
            projects = [(patch(p, status, progress, updated) if p["id"] == pid else p) for p in projects];
        }

        def logActivity(kind: str, icon: str, text: str) -> None {
            entry = {"id": f"a{len(activity)}-{text}", "kind": kind, "icon": icon, "text": text, "meta": "just now"};
            activity = [entry] + activity;
        }

        def sortByName(xs: list) -> list {
            arr = [x for x in xs];
            out = [];
            while len(arr) > 0 {
                best = arr[0];
                for x in arr {
                    if x["name"] < best["name"] { best = x; }
                }
                out = out + [best];
                arr = [x for x in arr if x["id"] != best["id"]];
            }
            return out;
        }

        def sortedProjects -> list {
            xs = [p for p in projects if projQuery == "" or projQuery in p["name"]];
            if sort == "name" {
                return sortByName(xs);
            }
            return xs;
        }

        def tabTitle -> str {
            if tab == "home" { return "Build something"; }
            if tab == "projects" { return f"{len(projects)} projects"; }
            if tab == "community" { return "Discover templates"; }
            if tab == "activity" { return "Recent deploys"; }
            return f"@{me}";
        }

        # ── deploy / stop / restart ───────────────────────────────────────────
        # Update a project's live status + url in place (deploy writes both).
        def setProjectDeploy(pid: str, status: str, url: str) -> None {
            out = [];
            for p in projects {
                if p["id"] == pid {
                    np = {** p, "status": status, "progress": (100 if status == "running" else 50)};
                    if url != "" { np["url"] = url; }
                    out = out + [np];
                } else {
                    out = out + [p];
                }
            }
            projects = out;
        }

        # After a deploy, deploy_ops(status) is what promotes "deploying" →
        # "running" and returns the live URL. Poll it every 5s until it leaves
        # "deploying" (jacBuilder does the same), then show the URL.
        async def pollDeploy(pid: str, mode: str, tries: int) -> None {
            if tries <= 0 { markBusy("deploy", False); return; }
            d = await jbDeployStatus(pid, mode);
            dep = d["deployment"] if ("deployment" in d) else {};
            st = str(dep["status"]) if "status" in dep else "";
            url = dep["url"] if "url" in dep else "";
            if st == "running" {
                setProjectDeploy(pid, "running", url);
                prodStep = 4;
                markBusy("deploy", False);
                return;
            }
            if st != "" and st != "deploying" {
                mapped = "failed" if (("fail" in st) or ("error" in st)) else "stopped";
                setProjectDeploy(pid, mapped, url);
                markBusy("deploy", False);
                return;
            }
            if url != "" { setProjectDeploy(pid, "building", url); }
            prodStep = 3;
            setTimeout(lambda { pollDeploy(pid, mode, tries - 1); }, 5000);
        }

        async def deploy(pid: str) -> None {
            if isBusy("deploy") { return; }
            markBusy("deploy", True);
            applyPatch(pid, "building", 30, "deploying…");
            prodStep = 1;
            m = deployMode;
            d = await jbDeploy(pid, m);
            dep = d["deployment"] if ("deployment" in d) else {};
            url0 = dep["url"] if "url" in dep else "";
            if url0 != "" { setProjectDeploy(pid, "building", url0); }
            prodStep = 2;
            label = "Production deploy started" if m == "permanent" else "Sandbox deploy started";
            logActivity("deploy", "rocket", label);
            pollDeploy(pid, m, 24);
        }

        async def stopProj(pid: str) -> None {
            if isBusy("deploy") { return; }
            markBusy("deploy", True);
            previewOn = False;
            prodStep = 0;
            applyPatch(pid, "stopped", 0, "stopping…");
            jbDestroy(pid, deployMode);
            logActivity("stop", "stop", "Deployment stopped");
            setTimeout(lambda { jbLoadProjects(); markBusy("deploy", False); }, 2500);
        }

        async def restartProj(pid: str) -> None {
            deploy(pid);
        }

        # ── preview workspace — ai_chat + ide_file_ops both need this ─────────
        # preview_control(start) spins the sandbox and creates the preview_dir.
        # Until it exists, ai_chat("start") reports "Preview not set up" and file
        # listing is empty. We start it lazily and remember it per project.
        # Reload the preview WebView (remounts via the nonce in its key).
        def bumpPreview -> None {
            previewNonce = previewNonce + 1;
        }

        # Returns the raw preview_control report so callers can surface the real
        # error.
        async def ensurePreview(pid: str) -> dict {
            console.log("[jh] ensurePreview pid=", pid, "previewReady=", previewReady);
            if previewReady { return {"success": True}; }
            markBusy("preview", True);
            # Claim the session first (jacBuilder does this on open) so the repo
            # is bound to this client's sandbox before we start the preview.
            cs = await jbClaimSession(pid, connId);
            console.log("[jh] claimSession →", cs);
            d = await jbPreviewStart(pid);
            console.log("[jh] previewStart →", d);
            markBusy("preview", False);
            if ("success" in d) and d["success"] {
                previewReady = True;
                if ("url" in d) and d["url"] { previewUrl = str(d["url"]); }
                loadFiles(pid);
            }
            return d;
        }

        # ── chat ──────────────────────────────────────────────────────────────
        # Just replace the thread with the persisted history. Turn completion is
        # tracked separately via ai_chat(poll) — see pollBuild.
        async def loadChat(pid: str) -> None {
            d = await jbChatHistory(pid);
            n = len(d["messages"]) if ("messages" in d) else 0;
            console.log("[jh] loadChat msgs=", n, "raw=", d);
            if ("success" in d) and d["success"] and ("messages" in d) and (len(d["messages"]) > 0) {
                messages = [jbMsg(m, i) for (i, m) in enumerate(d["messages"])];
            }
        }

        async def reloadChat -> None {
            if selId != "" {
                loadChat(selId);
            }
        }

        def chatError(text: str) -> None {
            markBusy("chat", False);
            messages = messages + [{"id": f"err-{len(messages)}", "role": "ai", "text": text, "steps": [], "done": True}];
        }

        def buildDone(pid: str) -> None {
            markBusy("chat", False);
            curFiles = [];
            loadFiles(pid);
            if autoPreview {
                autoPreview = False;
                detTab = "preview";
            }
            # Vite needs a few seconds to compile; reload the preview WebView so
            # the freshly-built app shows (HMR may not reach an embedded WebView).
            setTimeout(lambda { previewNonce = previewNonce + 1; }, 4000);
            setTimeout(lambda { previewNonce = previewNonce + 1; }, 12000);
        }

        # Finalize the turn once the agent_done event arrives: persist the reply
        # (writes the assistant message + clears the server's processing flag),
        # then refresh the thread, files and preview.
        async def finishBuild(pid: str, resp: str, promoted: list, isErr: bool, ckpt: str) -> None {
            console.log("[jh] finishBuild persist… isErr=", isErr, "files=", len(promoted));
            await jbChatPersist(pid, resp, promoted, isErr, ckpt);
            await loadChat(pid);
            buildDone(pid);
        }

        # jacBuilder's real build transport: open the ide_preview_stream WebSocket
        # and poll `ai_events` (with a fresh connection_id) ~every 500ms, draining
        # streamed events until `agent_done`/`agent_error`, then persist. The HTTP
        # `poll` action can't do this — the walker has no connection_id param, so
        # drain_events() always returns [].
        def streamBuild(pid: str, ckpt: str) -> None {
            token = globalThis.__jacGetLocalStorage__("jac_token");
            cid = "run-" + str(Math.floor(Math.random() * 1000000000));
            url = wsBuildUrl(JB_API);
            tokLen = len(token) if token else 0;
            console.log("[jh] streamBuild url=", url, "cid=", cid, "tokenLen=", tokLen);
            promoted = [];
            st = {"ticks": 0, "closed": False, "logged": False};
            ws = Reflect.construct(WebSocket, [url]);
            send = lambda {
                rid = "r" + str(Math.floor(Math.random() * 1000000000));
                try {
                    ws.send(JSON.stringify({"user_id": "", "project_id": pid, "action": "ai_events", "log_offset": 0, "token": token, "connection_id": cid, "request_id": rid}));
                } except Exception as e { console.log("[jh] ws send failed", e); }
            };
            ws.onopen = lambda(e: any) { console.log("[jh] ws open"); send(); };
            ws.onmessage = lambda(ev: any) {
                if not st["logged"] { st["logged"] = True; console.log("[jh] ws FIRST FULL msg:", str(ev.data)); }
                data = JSON.parse(ev.data);
                # Envelope: { ok, data: { result: { events, processing, … } } }.
                rep = data;
                if data and data.data and data.data.result { rep = data.data.result; }
                elif data and data.data and data.data.reports and (data.data.reports.length > 0) {
                    rep = data.data.reports[data.data.reports.length - 1];
                }
                evs = rep.events if (rep and rep.events) else [];
                proc = rep.processing if rep else False;
                done = False; isErr = False; resp = "";
                for evt in evs {
                    t = evt.type;
                    if t == "file_promoted" and evt.path { promoted.push(evt.path); }
                    elif t == "agent_done" { done = True; resp = (evt.response if evt.response else ""); }
                    elif t == "agent_error" { done = True; isErr = True; resp = (evt.error if evt.error else "The build failed."); }
                }
                if (len(evs) > 0) or done { console.log("[jh] ws events=", len(evs), "proc=", proc, "done=", done); }
                if done {
                    st["closed"] = True;
                    try { ws.close(); } except Exception as e {}
                    finishBuild(pid, resp, promoted, isErr, ckpt);
                } else {
                    st["ticks"] = st["ticks"] + 1;
                    if st["ticks"] > 600 {
                        st["closed"] = True;
                        try { ws.close(); } except Exception as e {}
                        loadChat(pid);
                        buildDone(pid);
                    } else {
                        setTimeout(send, 500);
                    }
                }
            };
            ws.onerror = lambda(e: any) { console.log("[jh] ws error", (e.message if e else "")); };
            ws.onclose = lambda(e: any) {
                console.log("[jh] ws closed clean=", st["closed"], "code=", (e.code if e else ""), "reason=", (e.reason if e else ""));
                # Unexpected drop mid-build → fall back so the spinner clears.
                if (not st["closed"]) and isBusy("chat") {
                    loadChat(pid);
                    buildDone(pid);
                }
            };
        }

        # Ensure the preview workspace, then kick off the build turn + stream.
        # A fresh project's repo may not be staged for a second or two, so the
        # preview start is retried a few times before giving up.
        async def startBuild(pid: str, txt: str, attempt: int) -> None {
            console.log("[jh] startBuild pid=", pid, "attempt=", attempt, "txt=", txt);
            pv = await ensurePreview(pid);
            if not (("success" in pv) and pv["success"]) {
                console.log("[jh] startBuild ensurePreview FAILED", pv);
                if attempt < 3 {
                    setTimeout(lambda { startBuild(pid, txt, attempt + 1); }, 3500);
                    return;
                }
                perr = pv["error"] if ("error" in pv and pv["error"]) else "Couldn't start the preview workspace.";
                chatError(f"⚠️ Preview: {perr}");
                return;
            }
            tryChatStart(pid, txt, 1);
        }

        # Start the build turn, then stream it. The FIRST start on a fresh project
        # has to create the (cold) JacCoder session and routinely 504s at the
        # gateway — but the walker keeps running and DOES start the turn. So a
        # 504 is not a failure: re-calling returns "a chat turn is already in
        # flight" carrying the checkpoint_ref, which means the turn is live and
        # we should just drain it over the WS. Only a genuine error surfaces.
        async def tryChatStart(pid: str, txt: str, attempt: int) -> None {
            d = await jbChatStart(pid, txt);
            console.log("[jh] jbChatStart attempt", attempt, "→", d);
            if ("success" in d) and d["success"] {
                ckpt = d["checkpoint_ref"] if ("checkpoint_ref" in d and d["checkpoint_ref"]) else "";
                streamBuild(pid, ckpt);
                return;
            }
            errStr = str(d["error"]) if ("error" in d and d["error"]) else "";
            ckpt = d["checkpoint_ref"] if ("checkpoint_ref" in d and d["checkpoint_ref"]) else "";
            inflight = ("already in flight" in errStr) or ("in flight" in errStr);
            is504 = ("504" in errStr) or ("Gateway Time-out" in errStr);
            # Turn is confirmed running (in-flight error carries the checkpoint) → stream.
            if inflight {
                console.log("[jh] turn in flight → stream ckpt=", ckpt);
                streamBuild(pid, ckpt);
                return;
            }
            # 504 → the turn likely started; re-call to get the in-flight ckpt.
            if (is504 or errStr == "") and attempt < 8 {
                setTimeout(lambda { tryChatStart(pid, txt, attempt + 1); }, 2500);
                return;
            }
            chatError(f"⚠️ {errStr if errStr != '' else 'The build turn could not start.'}");
        }

        # Takes the text from the (locally-stateful) chat composer, so typing
        # never re-renders the whole detail screen.
        async def sendChat(raw: str) -> None {
            txt = raw.strip();
            console.log("[jh] sendChat raw=", raw, "selId=", selId, "busyChat=", isBusy("chat"));
            if txt == "" or isBusy("chat") { return; }
            Keyboard.dismiss();
            markBusy("chat", True);
            # Optimistic user bubble only; the "working…" indicator comes from the
            # chat busy flag and stays put until the reply lands.
            messages = messages + [{"id": "tmp-u", "role": "user", "text": txt, "steps": [], "done": True}];
            startBuild(selId, txt, 1);
        }

        async def sendPrompt -> None {
            txt = prompt.strip();
            console.log("[jh] sendPrompt txt=", txt);
            if txt == "" or isBusy("prompt") { return; }
            markBusy("prompt", True);
            d = await jbProjectCreate("app", "", "");
            console.log("[jh] jbProjectCreate →", d);
            markBusy("prompt", False);
            if ("success" in d) and d["success"] and ("project" in d) {
                pid = d["project"]["id"];
                prompt = "";
                logActivity("create", "plus", f"Created “{d['project']['name'] if 'name' in d['project'] else 'app'}”");
                jbLoadProjects();
                # Open the project and run the prompt as a real build turn; when
                # the build finishes we auto-switch to the Preview tab. Use `pid`
                # directly — `selId` (just set) is a stale closure value here, so
                # relying on it would send an empty project_id to ai_chat.
                selId = pid;
                detTab = "chat";
                curFiles = [];
                previewReady = False;
                previewUrl = "";
                autoPreview = True;
                markBusy("chat", True);
                messages = [{"id": "tmp-u", "role": "user", "text": txt, "steps": [], "done": True}];
                startBuild(pid, txt, 1);
            } else {
                # Surface create failures (e.g. "Project limit reached (3)").
                err = d["error"] if ("error" in d and d["error"]) else "Couldn't create the project.";
                prompt = txt;
                Alert.alert("Can't create project", str(err));
            }
        }

        # ── model switch ──────────────────────────────────────────────────────
        async def chooseModel(mid: str) -> None {
            if selId != "" {
                d = await jbModelSwitch(selId, mid);
                if ("success" in d) and d["success"] { model = mid; }
            } else {
                model = mid;
            }
        }

        # ── project CRUD ──────────────────────────────────────────────────────
        async def createProject -> None {
            if isBusy("create") { return; }
            nm = newName.strip();
            if nm == "" { nm = "app"; }
            Keyboard.dismiss();
            markBusy("create", True);
            d = await jbProjectCreate(nm, newTemplate, "");
            markBusy("create", False);
            if ("success" in d) and d["success"] {
                showNew = False;
                newName = "";
                newRepo = "";
                logActivity("create", "plus", f"Created “{nm}”");
                jbLoadProjects();
                if "project" in d {
                    selId = d["project"]["id"];
                    detTab = "files";
                    curFiles = [];
                    loadFiles(d["project"]["id"]);
                }
            }
        }

        async def cloneTemplate(c: any) -> None {
            if isBusy("clone") { return; }
            markBusy("clone", True);
            tab = "projects";
            await jbCommunityClone(c["id"], c["name"]);
            logActivity("create", "clone", f"Cloned “{c['name']}” from community");
            jbLoadProjects();
            markBusy("clone", False);
        }

        async def doRename -> None {
            pid = renameId;
            nm = renameVal.strip();
            if nm == "" or isBusy("rename") { return; }
            markBusy("rename", True);
            await jbProjectRename(pid, nm);
            markBusy("rename", False);
            renameId = "";
            renameVal = "";
            logActivity("create", "settings", f"Renamed to “{nm}”");
            jbLoadProjects();
        }

        async def doDelete -> None {
            if isBusy("delete") { return; }
            pid = deleteId;
            nm = "project";
            for p in projects {
                if p["id"] == pid { nm = p["name"]; }
            }
            markBusy("delete", True);
            await jbProjectDelete(pid);
            markBusy("delete", False);
            deleteId = "";
            if selId == pid { selId = ""; }
            logActivity("stop", "close", f"Deleted “{nm}”");
            jbLoadProjects();
        }

        async def doPublish -> None {
            if isBusy("publish") { return; }
            pid = shareId;
            desc = shareDesc.strip();
            tags = shareTags;
            name = "project";
            for p in projects {
                if p["id"] == pid { name = p["name"]; }
            }
            markBusy("publish", True);
            await jbCommunitySubmit(name, desc, tags, pid);
            markBusy("publish", False);
            shareId = "";
            shareDesc = "";
            shareTags = "";
        }

        # ── auth / account ────────────────────────────────────────────────────
        async def submitAuth -> None {
            authError = "";
            u = authUser.strip();
            if len(u) < 3 { authError = "Username must be at least 3 characters."; return; }
            if len(authPass) < 6 { authError = "Password must be at least 6 characters."; return; }
            if authMode == "signup" and authPass != authPass2 { authError = "Passwords do not match."; return; }
            if isBusy("auth") { return; }
            Keyboard.dismiss();
            markBusy("auth", True);
            if authMode == "signup" {
                res = await jacSignup(u, authPass);
                if not (("success" in res) and res["success"]) {
                    authError = "Sign up failed — that account may already exist.";
                    markBusy("auth", False);
                    return;
                }
            }
            ok = await jacLogin(u, authPass);
            if not ok {
                authError = "Sign in failed — check your jacBuilder credentials.";
                markBusy("auth", False);
                return;
            }
            markBusy("auth", False);
            me = u;
            authPass = "";
            authPass2 = "";
            tab = "home";
            screen = "app";
            # Pass the username as the display-name hint so the profile shows a
            # real name (not the user_id) on future restores.
            jbLoadAccount(u);
            jbLoadProjects();
            loadCommunity();
            loadTemplates();
        }

        # ── social sign-in (jac cloud SSO, in an in-app WebView) ──────────────
        # jac cloud redirects to <configured>?token=<JWT> after auth (a mobile
        # deep link is rejected — only loopback callbacks are honoured — so we
        # let it land on the web callback and intercept the redirect in the
        # WebView instead). See SsoModal.
        def oauth(provider: str) -> None {
            authError = "";
            cb = encodeURIComponent(f"{JB_API}/auth/callback");
            ssoProvider = provider[0].upper() + provider[1:];
            ssoUrl = f"{JB_API}/sso/{provider}/login?client_callback={cb}";
        }

        def closeSso -> None {
            ssoUrl = "";
            ssoProvider = "";
        }

        # Manual query parse — React Native's URL polyfill has no searchParams.
        # Matches `key=` ONLY at a real param boundary (?key= or &key=), so
        # `token` never matches inside Google's `id_token=` / `access_token=`.
        def _ssoParam(url: str, key: str) -> str {
            for pre in ["?", "&"] {
                marker = pre + key + "=";
                idx = url.find(marker);
                if idx >= 0 {
                    rest = url[idx + len(marker):];
                    amp = rest.find("&");
                    val = rest if amp < 0 else rest[0:amp];
                    try { return decodeURIComponent(val); } except Exception as e { return val; }
                }
            }
            return "";
        }

        # Called for every WebView navigation. Returns False (blocks the load)
        # once it spots jac cloud's JWT / an error in the redirect, True otherwise.
        def onSsoNav(url: str) -> bool {
            tok = _ssoParam(url, "token");
            if tok != "" {
                # jac cloud's token is a JWT: header.payload.signature (2 dots).
                # This rules out any other single-segment token param.
                if len(tok.split(".")) >= 3 {
                    console.log("[jh] SSO token caught len=", len(tok), "url=", url[0:70]);
                    finishSso(tok);
                    return False;
                }
            }
            if _ssoParam(url, "error") != "" {
                console.log("[jh] SSO error url=", url[0:120]);
                closeSso();
                authError = "Sign-in was cancelled or failed. Try again or use a username.";
                return False;
            }
            return True;
        }

        async def finishSso(token: str) -> None {
            globalThis.__jacSetLocalStorage__("jac_token", token);
            ssoUrl = "";
            ssoProvider = "";
            authPass = "";
            authPass2 = "";
            tab = "home";
            screen = "app";
            # Log in first (known-good path), then resolve the display name.
            jbLoadAccount("");
            jbLoadProjects();
            loadCommunity();
            loadTemplates();
            # jac cloud's JWT/`me` only carry the user_id for SSO — fetch the real
            # display name from /user/me afterwards (non-blocking for login).
            info = await jbUserInfo();
            name = info["display_name"] if ("display_name" in info and info["display_name"]) else "";
            console.log("[jh] SSO display name=", name);
            if name != "" { me = name; }
        }

        def logout -> None {
            jacLogout();
            # Clear the SSO WebView's cookies so the next social sign-in shows
            # the account picker (needs the native cookie module — active in a
            # dev/standalone build, safe no-op in Expo Go).
            clearAuthCookies();
            me = "";
            authUser = "";
            authPass = "";
            authPass2 = "";
            selId = "";
            projects = [];
            screen = "auth";
            authMode = "login";
        }

        def cycleTheme -> None {
            if appTheme == "dark" {
                appTheme = "light";
            } else {
                if appTheme == "light" {
                    appTheme = "system";
                } else {
                    appTheme = "dark";
                }
            }
        }

        def startRename(pid: str) -> None {
            renameId = pid;
            for p in projects {
                if p["id"] == pid { renameVal = p["name"]; }
            }
            projMenu = "";
        }

        def openProject(pid: str) -> None {
            selId = pid;
            detTab = "chat";
            curFiles = [];
            messages = [];
            previewReady = False;
            previewUrl = "";
            autoPreview = False;
            loadChat(pid);
            # Warm up the preview workspace so chat + files work; also refreshes
            # the file tree once it's ready.
            ensurePreview(pid);
        }

        def closeProject -> None {
            selId = "";
        }

        def openNotifs -> None {
            notifOpen = True;
            seenCount = len(activity);
        }

        def openNew(mode: str) -> None {
            newMode = mode;
            newName = "";
            newRepo = "";
            if newTemplate == "" and len(templates) > 0 {
                newTemplate = templates[0]["id"];
            }
            showNew = True;
        }

        # ── the context value: everything screens/components consume ───────────
        value = {
            # state
            "screen": screen, "appTheme": appTheme, "authMode": authMode,
            "authUser": authUser, "authPass": authPass, "authPass2": authPass2,
            "authError": authError, "me": me, "credits": credits, "plan": plan,
            "billing": billing, "model": model, "tab": tab, "projects": projects,
            "activity": activity, "communityItems": communityItems,
            "curFiles": curFiles, "templates": templates, "models": models,
            "monitor": monitor, "monLogs": monLogs, "monLoading": monLoading,
            "messages": messages, "selId": selId, "detTab": detTab,
            "projQuery": projQuery, "query": query, "sort": sort, "prompt": prompt,
            "showNew": showNew, "newMode": newMode,
            "newName": newName, "newTemplate": newTemplate, "newRepo": newRepo,
            "fileView": fileView, "fileBody": fileBody, "notifOpen": notifOpen,
            "modelSheet": modelSheet, "projMenu": projMenu, "renameId": renameId,
            "renameVal": renameVal, "shareId": shareId, "shareDesc": shareDesc,
            "shareTags": shareTags, "deleteId": deleteId, "billingOpen": billingOpen,
            "seenCount": seenCount, "notifEnabled": notifEnabled, "previewOn": previewOn,
            "previewReady": previewReady, "previewUrl": previewUrl, "previewNonce": previewNonce,
            "ssoUrl": ssoUrl, "ssoProvider": ssoProvider,
            "viewport": viewport, "deployMode": deployMode, "prodStep": prodStep, "prodDomain": prodDomain,
            "tlsOn": tlsOn, "intro": intro, "busy": busy,
            # derived theme
            "light": light, "C": C, "styles": styles,
            # setters (auto-generated from `has`)
            "setScreen": setScreen, "setAppTheme": setAppTheme, "setAuthMode": setAuthMode,
            "setAuthUser": setAuthUser, "setAuthPass": setAuthPass, "setAuthPass2": setAuthPass2,
            "setAuthError": setAuthError, "setModel": setModel, "setTab": setTab,
            "setSelId": setSelId, "setDetTab": setDetTab, "setProjQuery": setProjQuery,
            "setQuery": setQuery, "setSort": setSort, "setPrompt": setPrompt,
            "setShowNew": setShowNew, "setNewMode": setNewMode,
            "setNewName": setNewName, "setNewTemplate": setNewTemplate, "setNewRepo": setNewRepo,
            "setFileView": setFileView, "setFileBody": setFileBody, "setNotifOpen": setNotifOpen,
            "setModelSheet": setModelSheet, "setProjMenu": setProjMenu, "setRenameId": setRenameId,
            "setRenameVal": setRenameVal, "setShareId": setShareId, "setShareDesc": setShareDesc,
            "setShareTags": setShareTags, "setDeleteId": setDeleteId, "setBillingOpen": setBillingOpen,
            "setNotifEnabled": setNotifEnabled, "setPreviewOn": setPreviewOn, "setViewport": setViewport,
            "setProdStep": setProdStep, "setProdDomain": setProdDomain, "setTlsOn": setTlsOn,
            "setDeployMode": setDeployMode,
            # helpers
            "jbStatus": jbStatus, "statusColor": statusColor, "statusLabel": statusLabel,
            "kindColor": kindColor, "usd": usd, "billingRemaining": billingRemaining,
            "billingSub": billingSub, "kbBehavior": kbBehavior, "unreadCount": unreadCount,
            "selected": selected, "deviceWidth": deviceWidth, "sortedProjects": sortedProjects,
            "tabTitle": tabTitle, "isBusy": isBusy,
            # actions
            "jbLoadProjects": jbLoadProjects, "jbLoadAccount": jbLoadAccount,
            "loadTemplates": loadTemplates, "loadCommunity": loadCommunity,
            "loadFiles": loadFiles, "openFile": openFile, "loadMonitor": loadMonitor,
            "ensurePreview": ensurePreview, "bumpPreview": bumpPreview,
            "deploy": deploy, "stopProj": stopProj, "restartProj": restartProj,
            "loadChat": loadChat, "reloadChat": reloadChat, "sendChat": sendChat,
            "sendPrompt": sendPrompt, "chooseModel": chooseModel, "createProject": createProject,
            "cloneTemplate": cloneTemplate, "doRename": doRename, "doDelete": doDelete,
            "doPublish": doPublish, "submitAuth": submitAuth, "oauth": oauth, "logout": logout,
            "closeSso": closeSso, "onSsoNav": onSsoNav,
            "cycleTheme": cycleTheme, "startRename": startRename, "openProject": openProject,
            "closeProject": closeProject, "openNotifs": openNotifs, "openNew": openNew,
            "logActivity": logActivity, "applyPatch": applyPatch
        };

        return <StudioContext.Provider value={value}>{children}</StudioContext.Provider>;
    }
}
