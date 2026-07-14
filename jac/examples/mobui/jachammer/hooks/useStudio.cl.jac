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
    import from ..kit.constants { JB_API }
    import from ..kit.mappers { prettyModel, jbStatus, jbProj, jbComm, jbMsg }
    import from ..kit.authcookies { clearAuthCookies }
    import from ..services.api {
        jbMe,
        jbUserInfo,
        jbProjectsList,
        jbProjectCreate,
        jbProjectRename,
        jbProjectDelete,
        jbClaimSession,
        jbTemplatesList,
        jbCommunityList,
        jbCommunityClone,
        jbCommunitySubmit,
        jbChatStart,
        jbChatHistory,
        jbChatPoll,
        jbChatPersist,
        jbModelSwitch,
        jbFilesList,
        jbFileRead,
        jbDeploy,
        jbDestroy,
        jbMonitor,
        jbPreviewStart,
        jbPreviewStatus,
        jbPreviewAuth,
        jbDeployStatus
    }

    # ai_chat build events stream over this WS walker (jacBuilder's transport);
    # the HTTP `poll` action can't return events (no connection_id param).
    # NB: unlike the HTTP walker routes (/walker/X), the gateway's WS catchall
    # only routes paths under the service prefix — /ws/… alone connects then
    # closes with 1008 (verified against the live server). Hence /api/builder_sv.
    def wsBuildUrl(base: str) -> str {
        path = "/api/builder_sv/ws/ide_preview_stream";
        if base.startswith("https://") {
            return "wss://" + base[8:] + path;
        }
        if base.startswith("http://") {
            return "ws://" + base[7:] + path;
        }
        # already ws(s):// or a bare host — don't blind-slice a wrong prefix.
        return base + path;
    }

    # Splash entrance animation value — created once at module load.
    glob:pub intro = createAnimatedValue(0);

    glob:pub StudioContext = createContext(None);

    # Render-independent mirror of the open project id. `selId` is React state, so
    # every closure created during a render captures the value it had *at that
    # render* — and a build turn's whole async chain (startBuild → streamBuild →
    # finishBuild) lives in closures made before the project was even opened. In
    # the create-from-prompt flow that meant finishBuild's `selId` was still ""
    # while pid was the new project, so its `selId == pid` guards all failed: the
    # in-flight bubble never flipped to the reply (stuck on "working…"), history
    # never reconciled, and the preview tab never auto-revealed. LIVE is written
    # by applySel() on every selection change and read by those guards instead.
    # "purl" (previewUrl) and "auto" (autoPreview) are mirrored for the same
    # reason: buildDone reads both, and in the create-from-prompt flow it runs in
    # that same pre-project closure — where previewUrl is "" (so the WebView's
    # handoff never got minted) and autoPreview is False (so the finished build
    # never revealed the Preview tab).
    # (Two dicts, not one: a mixed str/bool dict widens to `str | bool` and the
    # typed accessors below can't return it.)
    glob LIVE = {"sel": "", "purl": ""};

    glob LIVE_AUTO = {"on": False};

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
            previewPid: str = "",
            previewUrl: str = "",
            previewToken: str = "",
            previewAuthUrl: str = "",
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
                {
                    toValue: 1,
                    duration: 500,
                    easing: Easing.out(Easing.cubic),
                    useNativeDriver: True
                }
            ).start();
            # If a JWT is already stored, re-enter the app; otherwise → auth.
            restoreSession();
        }

        # Pure mappers (jbStatus / jbProj / jbComm / jbMsg / prettyModel) live in
        # lib/mappers.cl.jac — they need no component state.

        # ── loading flags — actions toggle these around their awaits so buttons
        #    can show a spinner + disable while a walker call is in flight ──────
        def markBusy(key: str, val: bool) {
            console.log("[jh] markBusy", key, val);
            # Functional state update: several actions flip different busy keys in
            # the same tick (e.g. "chat" then "preview"); a plain `busy = {**busy…}`
            # reads a stale closure and the later call drops the earlier key. The
            # lambda receives the freshest state so every flag survives.
            busy = lambda (prev: dict) {
                nb = {** prev};
                nb[key] = val;
                return nb;
            };
        }

        def isBusy(key: str) -> bool {
            return (key in busy) and busy[key];
        }

        # Always change the selection through this: it keeps LIVE (read by async
        # callbacks, which see a stale `selId`) in step with the state field.
        def applySel(pid: str) {
            selId = pid;
            LIVE["sel"] = pid;
        }

        # The open project as of *now* — safe to call from an async callback.
        def liveSel -> str {
            return LIVE["sel"];
        }

        # Same contract for the preview URL: always set it through here.
        def applyPreviewUrl(url: str) {
            previewUrl = url;
            LIVE["purl"] = url;
        }

        def livePreviewUrl -> str {
            return LIVE["purl"];
        }

        # …and for the "reveal the preview when this build lands" intent.
        def applyAutoPreview(on: bool) {
            autoPreview = on;
            LIVE_AUTO["on"] = on;
        }

        def liveAutoPreview -> bool {
            return LIVE_AUTO["on"];
        }

        # ── data loaders (call the service layer) ─────────────────────────────
        async def jbLoadProjects {
            d = await jbProjectsList();
            if ("success" in d) and d["success"] {
                projects = [jbProj(p) for p in d["projects"]];
            }
        }

        # hint: the typed username on login (stored server-side as display_name);
        # "" on restore. Returns whether the account loaded.
        async def jbLoadAccount(hint: str) -> bool {
            d = await jbMe(hint);
            if not (("success" in d) and d["success"]) {
                return False;
            }
            b = d["billing"] if "billing" in d else {};
            billing = b;
            tier = b["tier"] if "tier" in b else "free";
            plan = tier[0].upper() + tier[1:] if len(tier) > 0 else "Free";
            bal = 0.0;
            if "remaining_usd" in b {
                bal = bal + float(b["remaining_usd"]);
            }
            if "topup_balance_usd" in b {
                bal = bal + float(b["topup_balance_usd"]);
            }
            credits = int(round(bal));
            allowed = b["models_allowed"] if "models_allowed" in b else [];
            dflt = b["default_model"] if "default_model" in b else "";
            models = [{"id": mid, "name": prettyModel(mid)} for mid in allowed];
            if dflt != "" {
                model = dflt;
            }
            # Prefer the real display name; fall back to the typed username we
            # already have, then to the user_id only as a last resort.
            u = d["user"] if "user" in d else {};
            dn = u["display_name"]
                if ("display_name" in u and u["display_name"])
                else "";
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
            if ready {
                await ready;
            }
            if not jacIsLoggedIn() {
                if screen == "splash" {
                    screen = "auth";
                }
                return;
            }
            ok = await jbLoadAccount("");
            if not ok {
                if screen == "splash" {
                    screen = "auth";
                }
                return;
            }
            tab = "home";
            screen = "app";
            jbLoadProjects();
            loadCommunity();
            loadTemplates();
            # Resolve the real display name (not the user_id) on reload too.
            info = await jbUserInfo();
            hint = info["display_name"]
                if ("display_name" in info and info["display_name"])
                else "";
            if hint != "" {
                me = hint;
            }
        }

        async def loadTemplates {
            d = await jbTemplatesList();
            if ("success" in d) and d["success"] and ("templates" in d) {
                templates = [
                    {
                        "id": t["id"] if "id" in t else "",
                        "name": t["name"]
                            if "name" in t
                            else (t["id"] if "id" in t else "template"),
                        "desc": t["description"] if "description" in t else ""
                    } for t in d["templates"]
                ];
                if newTemplate == "" and len(templates) > 0 {
                    newTemplate = templates[0]["id"];
                }
            }
        }

        async def loadCommunity {
            d = await jbCommunityList(query);
            if "items" in d {
                communityItems = [jbComm(c) for c in d["items"]];
            }
        }

        async def loadFiles(pid: str) {
            d = await jbFilesList(pid);
            if ("success" in d) and d["success"] and ("files" in d) {
                curFiles = [f for f in d["files"]];
            } else {
                curFiles = [];
            }
        }

        async def openFile(name: str) {
            fileView = name;
            fileBody = "";
            d = await jbFileRead(selId, name);
            if ("success" in d) and d["success"] and ("content" in d) {
                fileBody = str(d["content"]);
            }
        }

        async def loadMonitor(pid: str) {
            monLoading = True;
            monitor = {};
            monLogs = [];
            od = await jbMonitor(pid, "overview", 200, 30);
            md = await jbMonitor(pid, "metrics", 200, 30);
            merged = {** od};
            if ("prometheus" in md) {
                merged["prometheus"] = md["prometheus"];
            }
            if ("resources" in md) {
                merged["resources"] = md["resources"];
            }
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
            base = float(billing["remaining_usd"])
                if "remaining_usd" in billing
                else 0.0;
            top = float(billing["topup_balance_usd"])
                if "topup_balance_usd" in billing
                else 0.0;
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
            if viewport == "desktop" {
                return 320;
            }
            if viewport == "tablet" {
                return 300;
            }
            return 260;
        }

        def statusColor(s: str) -> str {
            if s == "running" {
                return C.ok;
            }
            if s == "building" {
                return C.warn;
            }
            if s == "failed" {
                return C.danger;
            }
            return C.muted;
        }

        def statusLabel(s: str) -> str {
            if s == "running" {
                return "Running";
            }
            if s == "building" {
                return "Building";
            }
            if s == "failed" {
                return "Failed";
            }
            return "Stopped";
        }

        def kindColor(k: str) -> str {
            if k == "deploy" {
                return C.forge;
            }
            if k == "create" {
                return C.accent;
            }
            if k == "stop" {
                return C.danger;
            }
            return C.muted;
        }

        def patch(p: any, status: str, progress: int, updated: str) -> dict {
            return {
                "id": p["id"],
                "name": p["name"],
                "template": p["template"],
                "branch": p["branch"],
                "status": status,
                "progress": progress,
                "region": p["region"],
                "url": p["url"],
                "files": p["files"],
                "services": p["services"],
                "logs": p["logs"],
                "updated": updated
            };
        }

        def applyPatch(pid: str, status: str, progress: int, updated: str) {
            projects = [
                (patch(p, status, progress, updated) if p["id"] == pid else p)
                for p in projects
            ];
        }

        def logActivity(kind: str, icon: str, text: str) {
            entry = {
                "id": f"a{len(activity)}-{text}",
                "kind": kind,
                "icon": icon,
                "text": text,
                "meta": "just now"
            };
            activity = [entry] + activity;
        }

        def sortByName(xs: list) -> list {
            arr = [x for x in xs];
            out = [];
            while len(arr) > 0 {
                best = arr[0];
                for x in arr {
                    if x["name"] < best["name"] {
                        best = x;
                    }
                }
                out = out + [best];
                arr = [
                    x
                    for x in arr
                    if x["id"] != best["id"]
                ];
            }
            return out;
        }

        def sortedProjects -> list {
            xs = [
                p
                for p in projects
                if projQuery == "" or projQuery in p["name"]
            ];
            if sort == "name" {
                return sortByName(xs);
            }
            return xs;
        }

        def tabTitle -> str {
            if tab == "home" {
                return "Build something";
            }
            if tab == "projects" {
                return f"{len(projects)} projects";
            }
            if tab == "community" {
                return "Discover templates";
            }
            if tab == "activity" {
                return "Recent deploys";
            }
            return f"@{me}";
        }

        # ── deploy / stop / restart ───────────────────────────────────────────
        # Update a project's live status + url in place (deploy writes both).
        def setProjectDeploy(pid: str, status: str, url: str) {
            out = [];
            for p in projects {
                if p["id"] == pid {
                    np = {
                        ** p,
                        "status": status,
                        "progress": (100 if status == "running" else 50)
                    };
                    if url != "" {
                        np["url"] = url;
                    }
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
            if tries <= 0 {
                markBusy("deploy", False);
                return;
            }
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
            if url != "" {
                setProjectDeploy(pid, "building", url);
            }
            prodStep = 3;
            setTimeout(lambda { pollDeploy(pid, mode, tries - 1); }, 5000);
        }

        async def deploy(pid: str) -> None {
            if isBusy("deploy") {
                return;
            }
            markBusy("deploy", True);
            applyPatch(pid, "building", 30, "deploying…");
            prodStep = 1;
            m = deployMode;
            d = await jbDeploy(pid, m);
            dep = d["deployment"] if ("deployment" in d) else {};
            url0 = dep["url"] if "url" in dep else "";
            if url0 != "" {
                setProjectDeploy(pid, "building", url0);
            }
            prodStep = 2;
            label = "Production deploy started"
                if m == "permanent"
                else "Sandbox deploy started";
            logActivity("deploy", "rocket", label);
            pollDeploy(pid, m, 24);
        }

        async def stopProj(pid: str) -> None {
            if isBusy("deploy") {
                return;
            }
            markBusy("deploy", True);
            previewOn = False;
            prodStep = 0;
            applyPatch(pid, "stopped", 0, "stopping…");
            jbDestroy(pid, deployMode);
            logActivity("stop", "stop", "Deployment stopped");
            setTimeout(
                lambda {
                    jbLoadProjects();
                    markBusy("deploy", False);
                },
                2500
            );
        }

        async def restartProj(pid: str) {
            deploy(pid);
        }

        # ── preview workspace — ai_chat + ide_file_ops both need this ─────────
        # preview_control(start) spins the sandbox and creates the preview_dir.
        # Until it exists, ai_chat("start") reports "Preview not set up" and file
        # listing is empty. We start it lazily and remember it per project.
        # Reload the preview WebView (remounts via the nonce in its key).
        def bumpPreview {
            # A reload re-mints the handoff (it's short-lived) so the WebView
            # re-authenticates cleanly; refreshPreviewAuth bumps the nonce on
            # success. With no preview yet, just remount.
            if livePreviewUrl() != "" {
                refreshPreviewAuth();
            } else {
                previewNonce = previewNonce + 1;
            }
        }

        # Mint the sandbox preview's handoff auth URL (see jbPreviewAuth) and hand
        # it to the WebView. The native WebView can't use jacBuilder's iframe-only
        # `/__auth?t=…&embed=1` handshake (it top-level-navigates, so the sandbox
        # proxy rejects the token and bounces to the builder login), so we fetch a
        # signed handoff URL the sandbox accepts without an embed/Sec-Fetch check.
        # Called when the preview becomes visible (build done, Preview tab opened,
        # manual reload); the handoff TTL is short, so we mint late, not early.
        async def refreshPreviewAuth -> None {
            # livePreviewUrl(), not `previewUrl`: buildDone calls this from the
            # build's stream callback, whose closure predates preview start.
            url = livePreviewUrl();
            if url == "" {
                return;
            }
            console.log("[jh] refreshPreviewAuth for", url);
            d = await jbPreviewAuth(url);
            if ("success" in d)
            and d["success"]
            and ("auth_url" in d)
            and d["auth_url"] {
                previewAuthUrl = str(d["auth_url"]);
                # Functional bump — buildDone mints three times (now, +4s, +12s)
                # from one closure, so `previewNonce + 1` would compute the same
                # value each time and the WebView would never remount on the
                # rebuilt app.
                previewNonce = lambda (prev: int) { return prev + 1; };
                console.log("[jh] previewAuthUrl minted");
            } else {
                console.log("[jh] refreshPreviewAuth failed", d);
            }
        }

        # Returns the raw preview_control report so callers can surface the real
        # error.
        async def ensurePreview(pid: str) -> dict {
            console.log(
                "[jh] ensurePreview pid=",
                pid,
                "previewReady=",
                previewReady,
                "previewPid=",
                previewPid
            );
            # previewReady is only valid for the project it was started for.
            # Creating/opening another project leaves it True from the old one;
            # honoring it here would skip claim+start for the new project and its
            # preview_control(status) would report "none" forever (the sandbox was
            # never started). Re-start whenever the ready preview is a different
            # project.
            if previewReady and (previewPid == pid) {
                return {"success": True};
            }
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
                previewPid = pid;
                if ("url" in d) and d["url"] {
                    applyPreviewUrl(str(d["url"]));
                }
                # The preview URL is auth-gated; the token authorizes the
                # WebView via the /__auth handshake (see previewSrc()). Without
                # it the sandbox shows its login page instead of the built app.
                if ("preview_token" in d) and d["preview_token"] {
                    previewToken = str(d["preview_token"]);
                }
                loadFiles(pid);
            }
            return d;
        }

        # ── chat ──────────────────────────────────────────────────────────────
        # Just replace the thread with the persisted history. Turn completion is
        # tracked separately via ai_chat(poll) — see pollBuild.
        async def loadChat(pid: str) {
            d = await jbChatHistory(pid);
            n = len(d["messages"]) if ("messages" in d) else 0;
            console.log("[jh] loadChat msgs=", n, "raw=", d);
            if ("success" in d)
            and d["success"]
            and ("messages" in d)
            and (len(d["messages"]) > 0) {
                # Don't clobber an in-flight timeline: mid-build the history is
                # just the user message with ai_processing=true (the assistant
                # reply isn't persisted until the turn ends). Replacing here
                # would blank the streamed progress steps down to the lone user
                # bubble — so if the turn is still processing and there's no AI
                # message yet, keep what's already on screen.
                stillProcessing = ("ai_processing" in d) and d["ai_processing"];
                hasAi = False;
                for m in d["messages"] {
                    if ("role" in m) and (m["role"] != "user") {
                        hasAi = True;
                    }
                }
                if stillProcessing and (not hasAi) {
                    console.log(
                        "[jh] loadChat skip — turn still processing, no AI msg"
                    );
                    return;
                }
                messages = [jbMsg(m, i) for (i, m) in enumerate(d["messages"])];
            }
        }

        async def reloadChat {
            if selId != "" {
                loadChat(selId);
            }
        }

        def chatError(text: str) {
            markBusy("chat", False);
            # Functional update — `messages` is a stale closure here (see
            # markBusy), so both the append and the id have to read `prev`.
            messages = lambda (prev: list) { return prev + [
                {
                    "id": f"err-{len(prev)}",
                    "role": "ai",
                    "text": text,
                    "steps": [],
                    "done": True
                }
            ]; };
        }

        def buildDone(pid: str) {
            markBusy("chat", False);
            # Only touch the detail view if the built project is still on screen —
            # the user may have navigated to a different project mid-build.
            # liveSel(), not `selId`: this runs from the stream callback, whose
            # `selId` closure predates the project being opened.
            if liveSel() != pid {
                applyAutoPreview(False);
                return;
            }
            curFiles = [];
            loadFiles(pid);
            if liveAutoPreview() {
                applyAutoPreview(False);
                detTab = "preview";
            }
            # Authorize + load the preview. Mint a fresh handoff now, then again
            # after Vite has had a few seconds to compile the freshly-built app
            # (HMR may not reach the WebView, so we force reloads). Each mint
            # bumps the nonce, remounting the WebView on the newly-built output —
            # and a fresh handoff also sidesteps the short handoff TTL.
            refreshPreviewAuth();
            setTimeout(lambda { refreshPreviewAuth(); }, 4000);
            setTimeout(lambda { refreshPreviewAuth(); }, 12000);
        }

        # Finalize the turn once the agent_done event arrives. Order matters:
        # UNBLOCK THE UI FIRST (flip the in-flight bubble to the finished reply,
        # clear the chat-busy flag, reveal the preview), THEN persist + refresh
        # in the background. Doing it the other way round — awaiting persist and
        # history before buildDone — wedged the screen on "working…" and
        # "Generating your app…" whenever those calls were slow (e.g. against a
        # sandbox that had just gone idle), even though the build had succeeded:
        # buildDone (which clears isBusy("chat")) simply never got reached.
        async def finishBuild(
            pid: str, resp: str, promoted: list, isErr: bool, ckpt: str
        ) {
            console.log(
                "[jh] finishBuild persist… isErr=", isErr, "files=", len(promoted)
            );
            # Only touch shared UI state if this project is still on screen (the
            # user may have navigated away mid-build). liveSel() — see buildDone.
            if liveSel() == pid {
                # Flip the streamed in-flight bubble into the finished reply,
                # keeping the progress timeline it accumulated. If the history
                # refresh below fails or is empty, this optimistic message still
                # shows the result instead of a stuck "working…" row. Functional
                # update: reading `messages` directly here is a stale closure
                # (see markBusy), so the flip must operate on the freshest `prev`
                # — otherwise it can't find the live tmp-ai and the last upsert's
                # "working…" row wins.
                respText = resp;
                messages = lambda (prev: list) {
                    out = [];
                    flipped = False;
                    for m in prev {
                        if not m["done"] {
                            out.push(
                                {
                                    "id": m["id"],
                                    "role": "ai",
                                    "text": respText,
                                    "steps": m["steps"],
                                    "done": True
                                }
                            );
                            flipped = True;
                        } else {
                            out.push(m);
                        }
                    }
                    if not flipped {
                        out.push(
                            {
                                "id": f"tmp-ai-{len(prev)}",
                                "role": "ai",
                                "text": respText,
                                "steps": [],
                                "done": True
                            }
                        );
                    }
                    return out;
                };
            }
            # Clears chat-busy, reloads files, and reveals/auto-switches preview.
            buildDone(pid);
            # Reconcile with the server in the background — persist writes the
            # canonical assistant message + clears the processing flag, then
            # history replaces the optimistic bubble with the stored thread. The
            # UI is already usable regardless of how long these take.
            await jbChatPersist(pid, resp, promoted, isErr, ckpt);
            if liveSel() == pid {
                await loadChat(pid);
            }
        }

        # Map a streamed build event to a short, human-readable progress line for
        # the in-flight assistant bubble. Returns "" for events we deliberately
        # skip — the caller drops those. Observed event types (see the drain's
        # `types=` log): llm_tool_call / llm_tool_result, file_promoted,
        # file_activity, phase_change, preview_status, llm_thought,
        # validation_result, turn_summary, llm_steps_done, preview_verdict,
        # agent_done, agent_error. We keep the timeline to concrete ACTIONS —
        # tool calls, file writes, phase banners — and skip the rest:
        # llm_tool_result just echoes its call, and llm_thought / turn_summary
        # arrive as many partial prose chunks that would shatter into one
        # check-marked fragment each (the final reply is shown whole on done).
        def liveStepLabel(evt: any) -> str {
            t = str(evt.type) if evt.type else "";
            # Tool invocations — the readable "what it's doing now" signal.
            if t == "llm_tool_call" {
                nm = "";
                if evt.name {
                    nm = str(evt.name);
                } elif evt.tool {
                    nm = str(evt.tool);
                }
                if nm == "" {
                    return "";
                }
                pretty = " ".join(nm.split("_"));
                return f"Running {pretty}…";
            }
            # Concrete file writes.
            if t == "file_promoted" {
                p = str(evt.path) if evt.path else "";
                if p == "" {
                    return "";
                }
                parts = p.split("/");
                return f"Wrote {parts[len(parts) - 1]}";
            }
            # Coarse phase banners, when the backend sends a named phase.
            if t == "phase_change" {
                ph = "";
                if evt.phase {
                    ph = str(evt.phase);
                } elif evt.label {
                    ph = str(evt.label);
                } elif evt.name {
                    ph = str(evt.name);
                }
                if ph == "" {
                    return "";
                }
                ph = " ".join(ph.split("_"));
                return ph[0].upper() + ph[1:] if len(ph) > 0 else "";
            }
            return "";
        }

        # jacBuilder's real build transport: open the ide_preview_stream WebSocket
        # and poll `ai_events` (with a fresh connection_id) ~every 500ms, draining
        # streamed events until `agent_done`/`agent_error`, then persist. The HTTP
        # `poll` action can't do this — the walker has no connection_id param, so
        # drain_events() always returns [].
        #
        # The server closes the socket after a drain (observed: one `ai_events`
        # response then close 1000). A single connection therefore can't see the
        # whole turn, so on an unexpected close mid-build we REOPEN with a fresh
        # cid — the ai_events consumer group reads the Redis stream from earliest,
        # so reconnecting re-reads every event (incl. a late agent_done) and never
        # loses the reply. `reconnects` bounds this. Without it jachammer only ever
        # saw the first (empty) drain and fell back to load_history — which shows a
        # stale/recovered message and makes builds look slow/incomplete.
        def streamBuild(pid: str, ckpt: str, reconnects: int) {
            token = globalThis.__jacGetLocalStorage__("jac_token");
            cid = "run-" + str(Math.floor(Math.random() * 1000000000));
            url = wsBuildUrl(JB_API);
            tokLen = len(token) if token else 0;
            console.log(
                "[jh] streamBuild url=",
                url,
                "cid=",
                cid,
                "tokenLen=",
                tokLen,
                "reconnects=",
                reconnects
            );
            promoted = [];
            steps = [];
            st = {"ticks": 0, "closed": False, "logged": False, "lastProc": False};
            ws = Reflect.construct(WebSocket, [url]);
            send = lambda {
                rid = "r" + str(Math.floor(Math.random() * 1000000000));
                try {
                    ws.send(
                        JSON.stringify(
                            {
                                "user_id": "",
                                "project_id": pid,
                                "action": "ai_events",
                                "log_offset": 0,
                                "token": token,
                                "connection_id": cid,
                                "request_id": rid
                            }
                        )
                    );
                } except Exception as e {
                    console.log("[jh] ws send failed", e);
                }
            };
            ws.onopen = lambda (e: any) {
                console.log("[jh] ws open");
                send();
            };
            ws.onmessage = lambda (ev: any) {
                if not st["logged"] {
                    st["logged"] = True;
                    console.log("[jh] ws FIRST FULL msg:", str(ev.data));
                }
                data = JSON.parse(ev.data);
                # Envelope: { ok, data: { result: { reports: [ { data: {
                #   events, processing } } ] }, reports: [ … same … ] } }. The
                # events/processing live on reports[last].data — NOT on `result`
                # directly (reading `result.events` yields undefined, which is
                # why drains looked empty and proc came back undefined).
                rep = None;
                if data and data.data {
                    dd = data.data;
                    reps = None;
                    if dd.result and dd.result.reports {
                        reps = dd.result.reports;
                    } elif dd.reports {
                        reps = dd.reports;
                    }
                    if reps and (reps.length > 0) {
                        last = reps[reps.length - 1];
                        rep = last.data if (last and last.data) else last;
                    } elif dd.result {
                        rep = dd.result;
                    }
                }
                if not rep {
                    rep = data;
                }
                evs = rep.events if (rep and rep.events) else [];
                proc = True if (rep and rep.processing) else False;
                done = False;
                isErr = False;
                resp = "";
                types = [];
                for evt in evs {
                    t = evt.type;
                    if t {
                        types.push(t);
                    }
                    if t == "file_promoted" and evt.path {
                        promoted.push(evt.path);
                    } elif t == "agent_done" {
                        done = True;
                        resp = evt.response or "";
                    } elif t == "agent_error" {
                        done = True;
                        isErr = True;
                        resp = evt.error or "The build failed.";
                    }
                    # Accumulate a live progress line, skipping empties and
                    # consecutive dupes (so token-by-token or repeated events
                    # don't spam the timeline).
                    lbl = liveStepLabel(evt);
                    if lbl != ""
                    and ((len(steps) == 0) or (steps[len(steps) - 1] != lbl)) {
                        steps.push(lbl);
                    }
                }
                # Bound the timeline on long turns; a reconnect re-reads from
                # earliest and rebuilds this identically, so trimming is safe.
                if len(steps) > 60 {
                    steps = steps[len(steps) - 60:];
                }
                procChanged = proc != st["lastProc"];
                st["lastProc"] = proc;
                # Log on any event, completion, a processing-state change, or a
                # heartbeat every ~20 drains — enough to trace a turn without
                # spamming one line per 500ms poll.
                if (len(evs) > 0) or done or procChanged or (st["ticks"] % 20 == 0) {
                    console.log(
                        "[jh] ws drain events=",
                        len(evs),
                        "proc=",
                        proc,
                        "done=",
                        done,
                        "tick=",
                        st["ticks"],
                        "recon=",
                        reconnects,
                        "types=",
                        types
                    );
                }
                # Surface progress live: upsert an in-flight assistant bubble whose
                # timeline is the steps drained so far. Only once there's something
                # to show — until then the detail screen's generic "Generating…"
                # spinner covers the gap.
                if (not done) and (len(steps) > 0) {
                    # Functional update — reading the `messages` closure directly
                    # here is stale (see markBusy), so rebuild off the freshest
                    # `prev`. Snapshot `steps` so the stored array doesn't keep
                    # mutating under React after this render.
                    stepsSnap = [s for s in steps];
                    messages = lambda (prev: list) {
                        # The in-flight bubble is the only one with done=False —
                        # match on that, not on a fixed id, so ids stay unique
                        # per turn (duplicate React keys) and this upsert can't
                        # sweep away a *previous* turn's finished reply.
                        base = [
                            m
                            for m in prev
                            if m["done"]
                        ];
                        live = [
                            m["id"]
                            for m in prev
                            if not m["done"]
                        ];
                        return base + [
                            {
                                "id": live[0]
                                    if len(live) > 0
                                    else f"tmp-ai-{len(prev)}",
                                "role": "ai",
                                "text": "",
                                "steps": stepsSnap,
                                "done": False
                            }
                        ];
                    };
                }
                if done {
                    st["closed"] = True;
                    try {
                        ws.close();
                    } except Exception as e { }
                    finishBuild(pid, resp, promoted, isErr, ckpt);
                } else {
                    st["ticks"] = st["ticks"] + 1;
                    # Absolute ceiling on a single drained turn. At ~500ms/tick
                    # this is ~30min — a real full-stack build (many files +
                    # validation loops) runs well past the old 5-min (600-tick)
                    # cap while still reporting proc=true, so the low cap was
                    # aborting live builds mid-flight and blanking the timeline.
                    if st["ticks"] > 3600 {
                        console.log("[jh] ws tick cap reached → load history");
                        st["closed"] = True;
                        try {
                            ws.close();
                        } except Exception as e { }
                        loadChat(pid);
                        buildDone(pid);
                    } else {
                        setTimeout(send, 500);
                    }
                }
            };
            ws.onerror = lambda (e: any) { console.log(
                "[jh] ws error", (e.message if e else "")
            ); };
            ws.onclose = lambda (e: any) {
                console.log(
                    "[jh] ws closed clean=",
                    st["closed"],
                    "code=",
                    (e.code if e else ""),
                    "reason=",
                    (e.reason if e else ""),
                    "recon=",
                    reconnects
                );
                # Clean end (agent_done / tick cap) → nothing to do.
                if st["closed"] {
                    return;
                }
                # Turn no longer on screen / already cleared → stop.
                if not isBusy("chat") {
                    return;
                }
                # Server closed mid-build. Reopen and keep draining (fresh cid
                # re-reads from earliest, so no events are missed) until the turn
                # completes or we hit the reconnect cap.
                if reconnects < 400 {
                    setTimeout(lambda { streamBuild(pid, ckpt, reconnects + 1); }, 700);
                } else {
                    console.log("[jh] ws reconnect cap reached → load history");
                    loadChat(pid);
                    buildDone(pid);
                }
            };
        }

        # Gate the build turn on the sandbox pod being "running" — this is the
        # step jacBuilder's web client has and jachammer was missing (see
        # useChatMode.sendMessage → `await ide.waitForPreviewReady()`). The
        # ai_chat(start) turn runs inside the project's JacCoder session, which
        # only reaches its Redis event bus once the pod is up; firing it while
        # the sandbox is still "starting" is what returns
        # "…Redis…Connection refused". preview_control(start) returns
        # status:"starting", NOT running, so we must poll preview_control(status)
        # until "running" before starting the turn. (Web is event-driven via a
        # status WS; that isn't wired on RN, so we poll ~2.5s for up to ~120s.)
        # On a terminal state we surface it; on timeout we proceed anyway (web
        # does too — the chat-start retry loop covers a slightly-late pod).
        async def waitPreviewRunning(pid: str, txt: str, polls: int) -> None {
            st = await jbPreviewStatus(pid);
            status = str(st["status"]) if ("status" in st and st["status"]) else "";
            url = str(st["url"]) if ("url" in st and st["url"]) else "";
            tok = str(st["preview_token"])
                if ("preview_token" in st and st["preview_token"])
                else "";
            console.log(
                "[jh] previewStatus poll left=",
                polls,
                "status=",
                status,
                "url=",
                url,
                "tokenLen=",
                len(tok)
            );
            if url != "" {
                applyPreviewUrl(url);
            }
            # Refresh the auth token from status (jacBuilder does the same) so
            # the WebView authorizes with the freshest token on load/reload.
            if tok != "" {
                previewToken = tok;
            }
            if status == "running" {
                console.log("[jh] preview running → starting chat turn");
                tryChatStart(pid, txt, 1);
                return;
            }
            if (status == "error")
            or (status == "stopped")
            or (status == "destroyed") {
                console.log("[jh] preview terminal state", status, "→ abort build");
                chatError(f"⚠️ Preview {status} — couldn't start the sandbox.");
                return;
            }
            if polls > 0 {
                setTimeout(lambda { waitPreviewRunning(pid, txt, polls - 1); }, 2500);
                return;
            }
            console.log("[jh] preview never reached running — starting chat anyway");
            tryChatStart(pid, txt, 1);
        }

        # Ensure the preview workspace, then wait for the sandbox to be running
        # (waitPreviewRunning) before kicking off the build turn + stream. A
        # fresh project's repo may not be staged for a second or two, so the
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
                perr = pv["error"]
                    if ("error" in pv and pv["error"])
                    else "Couldn't start the preview workspace.";
                chatError(f"⚠️ Preview: {perr}");
                return;
            }
            # Wait for the pod to be "running" (~120s budget) before ai_chat.
            waitPreviewRunning(pid, txt, 48);
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
                ckpt = d["checkpoint_ref"]
                    if ("checkpoint_ref" in d and d["checkpoint_ref"])
                    else "";
                streamBuild(pid, ckpt, 0);
                return;
            }
            errStr = str(d["error"]) if ("error" in d and d["error"]) else "";
            ckpt = d["checkpoint_ref"]
                if ("checkpoint_ref" in d and d["checkpoint_ref"])
                else "";
            lowered = errStr.lower();
            inflight = ("already in flight" in errStr) or ("in flight" in errStr);
            is504 = ("504" in errStr) or ("Gateway Time-out" in errStr);
            # A cold sandbox whose JacCoder/Redis isn't reachable yet returns a
            # transient connection error — retryable, not fatal (the pod is just
            # still warming). The preview-ready gate should prevent most of these,
            # but a pod can drop its Redis link briefly right after "running".
            transient = (
                ("connection refused" in lowered)
                or ("connecting to" in lowered)
                or ("redis" in lowered)
                or ("temporarily unavailable" in lowered)
                or ("503" in errStr)
            );
            console.log(
                "[jh] chatStart classify attempt=",
                attempt,
                "inflight=",
                inflight,
                "is504=",
                is504,
                "transient=",
                transient,
                "err=",
                errStr
            );
            # Turn is confirmed running (in-flight error carries the checkpoint) → stream.
            if inflight {
                console.log("[jh] turn in flight → stream ckpt=", ckpt);
                streamBuild(pid, ckpt, 0);
                return;
            }
            # 504 / transient cold-start / empty → the turn likely started or the
            # pod is warming; re-call to get the in-flight ckpt or a clean start.
            if (is504 or transient or errStr == "") and attempt < 8 {
                console.log("[jh] chatStart retry in 2.5s → attempt", attempt + 1);
                setTimeout(lambda { tryChatStart(pid, txt, attempt + 1); }, 2500);
                return;
            }
            chatError(
                f"⚠️ {errStr if errStr != '' else 'The build turn could not start.'}"
            );
        }

        # Takes the text from the (locally-stateful) chat composer, so typing
        # never re-renders the whole detail screen.
        async def sendChat(raw: str) -> None {
            txt = raw.strip();
            console.log(
                "[jh] sendChat raw=",
                raw,
                "selId=",
                liveSel(),
                "busyChat=",
                isBusy("chat")
            );
            if txt == "" or isBusy("chat") {
                return;
            }
            Keyboard.dismiss();
            markBusy("chat", True);
            # Optimistic user bubble only; the "working…" indicator comes from the
            # chat busy flag and stays put until the reply lands. Functional
            # update (see markBusy): `messages` is a stale closure here, and the
            # id must be derived from the freshest `prev` — a fixed "tmp-u" gave
            # every turn the same React key once a turn's bubbles outlived their
            # history reconcile (slow persist, or the user navigating away).
            messages = lambda (prev: list) { return prev + [
                {
                    "id": f"tmp-u-{len(prev)}",
                    "role": "user",
                    "text": txt,
                    "steps": [],
                    "done": True
                }
            ]; };
            startBuild(liveSel(), txt, 1);
        }

        async def sendPrompt -> None {
            txt = prompt.strip();
            console.log("[jh] sendPrompt txt=", txt);
            if txt == "" or isBusy("prompt") {
                return;
            }
            markBusy("prompt", True);
            d = await jbProjectCreate("app", "", "");
            console.log("[jh] jbProjectCreate →", d);
            markBusy("prompt", False);
            if ("success" in d) and d["success"] and ("project" in d) {
                pid = d["project"]["id"];
                prompt = "";
                logActivity(
                    "create",
                    "plus",
                    f"Created “{d['project']['name']
                        if 'name' in d['project']
                        else 'app'}”"
                );
                jbLoadProjects();
                # Open the project and run the prompt as a real build turn; when
                # the build finishes we auto-switch to the Preview tab. Use `pid`
                # directly — `selId` (just set) is a stale closure value here, so
                # relying on it would send an empty project_id to ai_chat.
                applySel(pid);
                detTab = "chat";
                curFiles = [];
                previewReady = False;
                previewPid = "";
                applyPreviewUrl("");
                previewToken = "";
                previewAuthUrl = "";
                applyAutoPreview(True);
                markBusy("chat", True);
                messages = [
                    {
                        "id": "tmp-u-0",
                        "role": "user",
                        "text": txt,
                        "steps": [],
                        "done": True
                    }
                ];
                startBuild(pid, txt, 1);
            } else {
                # Surface create failures (e.g. "Project limit reached (3)").
                err = d["error"]
                    if ("error" in d and d["error"])
                    else "Couldn't create the project.";
                prompt = txt;
                Alert.alert("Can't create project", str(err));
            }
        }

        # ── model switch ──────────────────────────────────────────────────────
        async def chooseModel(mid: str) {
            if selId != "" {
                d = await jbModelSwitch(selId, mid);
                if ("success" in d) and d["success"] {
                    model = mid;
                }
            } else {
                model = mid;
            }
        }

        # ── project CRUD ──────────────────────────────────────────────────────
        async def createProject -> None {
            if isBusy("create") {
                return;
            }
            nm = newName.strip();
            if nm == "" {
                nm = "app";
            }
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
                    applySel(d["project"]["id"]);
                    detTab = "files";
                    curFiles = [];
                    loadFiles(d["project"]["id"]);
                }
            }
        }

        async def cloneTemplate(c: any) -> None {
            if isBusy("clone") {
                return;
            }
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
            if nm == "" or isBusy("rename") {
                return;
            }
            markBusy("rename", True);
            await jbProjectRename(pid, nm);
            markBusy("rename", False);
            renameId = "";
            renameVal = "";
            logActivity("create", "settings", f"Renamed to “{nm}”");
            jbLoadProjects();
        }

        async def doDelete -> None {
            if isBusy("delete") {
                return;
            }
            pid = deleteId;
            nm = "project";
            for p in projects {
                if p["id"] == pid {
                    nm = p["name"];
                }
            }
            markBusy("delete", True);
            await jbProjectDelete(pid);
            markBusy("delete", False);
            deleteId = "";
            if liveSel() == pid {
                applySel("");
            }
            logActivity("stop", "close", f"Deleted “{nm}”");
            jbLoadProjects();
        }

        async def doPublish -> None {
            if isBusy("publish") {
                return;
            }
            pid = shareId;
            desc = shareDesc.strip();
            tags = shareTags;
            name = "project";
            for p in projects {
                if p["id"] == pid {
                    name = p["name"];
                }
            }
            markBusy("publish", True);
            await jbCommunitySubmit(name, desc, tags, pid);
            markBusy("publish", False);
            shareId = "";
            shareDesc = "";
            shareTags = "";
        }

        # ── auth / account ────────────────────────────────────────────────────
        # Turn a jacSignup failure into something true. It used to always say the
        # account already exists, which is a guess — and a wrong one for the two
        # most common failures: the backend being down (5xx, which returns an
        # nginx HTML page, not JSON) and the device having no route to it. Only a
        # 409 / "exists" actually means the username is taken.
        def signupFailMsg(res: dict) -> str {
            err = str(res["error"]) if ("error" in res) and res["error"] else "";
            code = res["status"] if ("status" in res) and res["status"] else 0;
            low = err.lower();
            if (code == 409) or ("exist" in low) or ("duplicate" in low) {
                return "That username is taken — log in instead.";
            }
            if code >= 500 {
                return f"jacBuilder is unavailable right now ({code}). Try again in a few minutes.";
            }
            if code == 0 {
                return f"Couldn't reach jacBuilder — check your connection. ({err[0:80]})";
            }
            # A real, specific server message (a bare HTML error page isn't one).
            if err == "" or err.startswith("<") {
                return f"Sign up failed ({code}).";
            }
            return f"Sign up failed: {err[0:120]}";
        }

        async def submitAuth -> None {
            authError = "";
            u = authUser.strip();
            if len(u) < 3 {
                authError = "Username must be at least 3 characters.";
                return;
            }
            if len(authPass) < 6 {
                authError = "Password must be at least 6 characters.";
                return;
            }
            if authMode == "signup" and authPass != authPass2 {
                authError = "Passwords do not match.";
                return;
            }
            if isBusy("auth") {
                return;
            }
            Keyboard.dismiss();
            markBusy("auth", True);
            # jacSignup/jacLogin fetch without catching: a rejected request (no
            # network, DNS/TLS failure) used to escape here and leave "auth" busy
            # forever — the button just spun with no message.
            if authMode == "signup" {
                res: dict = {};
                try {
                    res = await jacSignup(u, authPass);
                } except Exception as e {
                    res = {"success": False, "status": 0, "error": str(e)};
                }
                console.log("[jh] signup →", res);
                if not (("success" in res) and res["success"]) {
                    authError = signupFailMsg(res);
                    markBusy("auth", False);
                    return;
                }
            }
            ok = False;
            try {
                ok = await jacLogin(u, authPass);
            } except Exception as e {
                console.log("[jh] login threw", e);
                authError = "Couldn't reach jacBuilder — check your connection.";
                markBusy("auth", False);
                return;
            }
            console.log("[jh] login ok=", ok);
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
        def oauth(provider: str) {
            authError = "";
            cb = encodeURIComponent(f"{JB_API}/auth/callback");
            ssoProvider = provider[0].upper() + provider[1:];
            ssoUrl = f"{JB_API}/sso/{provider}/login?client_callback={cb}";
        }

        def closeSso {
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
                    try {
                        return decodeURIComponent(val);
                    } except Exception as e {
                        return val;
                    }
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
                    console.log(
                        "[jh] SSO token caught len=", len(tok), "url=", url[0:70]
                    );
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

        async def finishSso(token: str) {
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
            name = info["display_name"]
                if ("display_name" in info and info["display_name"])
                else "";
            console.log("[jh] SSO display name=", name);
            if name != "" {
                me = name;
            }
        }

        def logout {
            jacLogout();
            # Clear the SSO WebView's cookies so the next social sign-in shows
            # the account picker (needs the native cookie module — active in a
            # dev/standalone build, safe no-op in Expo Go).
            clearAuthCookies();
            me = "";
            authUser = "";
            authPass = "";
            authPass2 = "";
            applySel("");
            projects = [];
            screen = "auth";
            authMode = "login";
        }

        def cycleTheme {
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

        def startRename(pid: str) {
            renameId = pid;
            for p in projects {
                if p["id"] == pid {
                    renameVal = p["name"];
                }
            }
            projMenu = "";
        }

        def openProject(pid: str) {
            applySel(pid);
            detTab = "chat";
            curFiles = [];
            messages = [];
            previewReady = False;
            previewPid = "";
            applyPreviewUrl("");
            previewToken = "";
            previewAuthUrl = "";
            applyAutoPreview(False);
            loadChat(pid);
            # Warm up the preview workspace so chat + files work; also refreshes
            # the file tree once it's ready.
            ensurePreview(pid);
        }

        def closeProject {
            applySel("");
        }

        def openNotifs {
            notifOpen = True;
            seenCount = len(activity);
        }

        def openNew(mode: str) {
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
            "screen": screen,
            "appTheme": appTheme,
            "authMode": authMode,
            "authUser": authUser,
            "authPass": authPass,
            "authPass2": authPass2,
            "authError": authError,
            "me": me,
            "credits": credits,
            "plan": plan,
            "billing": billing,
            "model": model,
            "tab": tab,
            "projects": projects,
            "activity": activity,
            "communityItems": communityItems,
            "curFiles": curFiles,
            "templates": templates,
            "models": models,
            "monitor": monitor,
            "monLogs": monLogs,
            "monLoading": monLoading,
            "messages": messages,
            "selId": selId,
            "detTab": detTab,
            "projQuery": projQuery,
            "query": query,
            "sort": sort,
            "prompt": prompt,
            "showNew": showNew,
            "newMode": newMode,
            "newName": newName,
            "newTemplate": newTemplate,
            "newRepo": newRepo,
            "fileView": fileView,
            "fileBody": fileBody,
            "notifOpen": notifOpen,
            "modelSheet": modelSheet,
            "projMenu": projMenu,
            "renameId": renameId,
            "renameVal": renameVal,
            "shareId": shareId,
            "shareDesc": shareDesc,
            "shareTags": shareTags,
            "deleteId": deleteId,
            "billingOpen": billingOpen,
            "seenCount": seenCount,
            "notifEnabled": notifEnabled,
            "previewOn": previewOn,
            "previewReady": previewReady,
            "previewUrl": previewUrl,
            "previewToken": previewToken,
            "previewAuthUrl": previewAuthUrl,
            "previewNonce": previewNonce,
            "ssoUrl": ssoUrl,
            "ssoProvider": ssoProvider,
            "viewport": viewport,
            "deployMode": deployMode,
            "prodStep": prodStep,
            "prodDomain": prodDomain,
            "tlsOn": tlsOn,
            "intro": intro,
            "busy": busy,
            # derived theme
            "light": light,
            "C": C,
            "styles": styles,
            # setters (auto-generated from `has`)
            "setScreen": setScreen,
            "setAppTheme": setAppTheme,
            "setAuthMode": setAuthMode,
            "setAuthUser": setAuthUser,
            "setAuthPass": setAuthPass,
            "setAuthPass2": setAuthPass2,
            "setAuthError": setAuthError,
            "setModel": setModel,
            "setTab": setTab,
            "setSelId": setSelId,
            "setDetTab": setDetTab,
            "setProjQuery": setProjQuery,
            "setQuery": setQuery,
            "setSort": setSort,
            "setPrompt": setPrompt,
            "setShowNew": setShowNew,
            "setNewMode": setNewMode,
            "setNewName": setNewName,
            "setNewTemplate": setNewTemplate,
            "setNewRepo": setNewRepo,
            "setFileView": setFileView,
            "setFileBody": setFileBody,
            "setNotifOpen": setNotifOpen,
            "setModelSheet": setModelSheet,
            "setProjMenu": setProjMenu,
            "setRenameId": setRenameId,
            "setRenameVal": setRenameVal,
            "setShareId": setShareId,
            "setShareDesc": setShareDesc,
            "setShareTags": setShareTags,
            "setDeleteId": setDeleteId,
            "setBillingOpen": setBillingOpen,
            "setNotifEnabled": setNotifEnabled,
            "setPreviewOn": setPreviewOn,
            "setViewport": setViewport,
            "setProdStep": setProdStep,
            "setProdDomain": setProdDomain,
            "setTlsOn": setTlsOn,
            "setDeployMode": setDeployMode,
            # helpers
            "jbStatus": jbStatus,
            "statusColor": statusColor,
            "statusLabel": statusLabel,
            "kindColor": kindColor,
            "usd": usd,
            "billingRemaining": billingRemaining,
            "billingSub": billingSub,
            "kbBehavior": kbBehavior,
            "unreadCount": unreadCount,
            "selected": selected,
            "deviceWidth": deviceWidth,
            "sortedProjects": sortedProjects,
            "tabTitle": tabTitle,
            "isBusy": isBusy,
            # actions
            "jbLoadProjects": jbLoadProjects,
            "jbLoadAccount": jbLoadAccount,
            "loadTemplates": loadTemplates,
            "loadCommunity": loadCommunity,
            "loadFiles": loadFiles,
            "openFile": openFile,
            "loadMonitor": loadMonitor,
            "ensurePreview": ensurePreview,
            "bumpPreview": bumpPreview,
            "refreshPreviewAuth": refreshPreviewAuth,
            "deploy": deploy,
            "stopProj": stopProj,
            "restartProj": restartProj,
            "loadChat": loadChat,
            "reloadChat": reloadChat,
            "sendChat": sendChat,
            "sendPrompt": sendPrompt,
            "chooseModel": chooseModel,
            "createProject": createProject,
            "cloneTemplate": cloneTemplate,
            "doRename": doRename,
            "doDelete": doDelete,
            "doPublish": doPublish,
            "submitAuth": submitAuth,
            "oauth": oauth,
            "logout": logout,
            "closeSso": closeSso,
            "onSsoNav": onSsoNav,
            "cycleTheme": cycleTheme,
            "startRename": startRename,
            "openProject": openProject,
            "closeProject": closeProject,
            "openNotifs": openNotifs,
            "openNew": openNew,
            "logActivity": logActivity,
            "applyPatch": applyPatch
        };

        return
            <StudioContext.Provider value={value}>{children}</StudioContext.Provider>;
    }
}
