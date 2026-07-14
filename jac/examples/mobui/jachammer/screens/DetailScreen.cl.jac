"""jachammer project detail — the mini IDE (Chat / Files / Preview / Deploy /
Monitor). One screen component; each tab + the SDUI preview renderer + the
deploy-telemetry derivations live as nested helpers over the store snapshot.
"""

cl {
    import from "@jac/mobui" {
        View,
        Text,
        Pressable,
        TextInput,
        ScrollView,
        Image,
        KeyboardAvoidingView
    }
    import from ..ui.icon { Icon }
    import from ..ui.theme { S }
    import from ..hooks.useStudio { useStudio }
    import from ..components.StatusPill { StatusPill }
    import from ..components.Progress { Progress }
    import from ..components.Toggle { Toggle }
    import from ..components.DetTab { DetTab }
    import from ..components.MsgRow { MsgRow }
    import from ..components.ModelChip { ModelChip }
    import from ..components.DnsRow { DnsRow }
    import from ..components.StepRow { StepRow }
    import from ..components.Spinner { Spinner }
    import from ..components.ChatComposer { ChatComposer }
    import from ..components.PreviewFrame { PreviewFrame }

    def:pub DetailScreen -> JsxElement {
        s = useStudio();
        C = s["C"];
        styles = s["styles"];
        selected = s["selected"];
        deviceWidth = s["deviceWidth"];
        kbBehavior = s["kbBehavior"];
        statusColor = s["statusColor"];
        messages = s["messages"];
        curFiles = s["curFiles"];
        selId = s["selId"];
        detTab = s["detTab"];
        prodDomain = s["prodDomain"];
        tlsOn = s["tlsOn"];
        monitor = s["monitor"];
        monLogs = s["monLogs"];
        monLoading = s["monLoading"];

        p = selected();
        if p == None {
            return <View/>;
        }

        # ── chat tab ──────────────────────────────────────────────────────────
        def renderChatTab -> JsxElement {
            thinking = s["isBusy"]("chat");
            # Once the stream has upserted an in-flight assistant bubble (a message
            # still marked not-done), that bubble's own "working…" row is the live
            # indicator — so suppress the generic spinner to avoid a double one.
            hasLive = False;
            for m in messages {
                if not m["done"] {
                    hasLive = True;
                }
            }
            thinkMsg = "Starting your workspace…"
                if s["isBusy"]("preview")
                else "Generating your app — this can take a minute…";
            return
                <View style={styles.flex1}>
                    <ScrollView
                        style={styles.scroll}
                        contentContainerStyle={{paddingVertical: S.md, gap: S.xs}}
                        keyboardShouldPersistTaps="handled"
                    >
                        {(
                            <View style={styles.empty}>
                                <Icon
                                    name="spark"
                                    size={30}
                                    color={C.muted}
                                    fill={False}
                                    width={1.6}
                                />
                                <Text style={styles.emptyTitle}>Build with AI</Text>
                                <Text style={styles.emptyText}>
                                    Ask for a feature and I'll edit the code.
                                </Text>
                            </View>
                        )
                            if (len(messages) == 0 and not thinking)
                            else (
                                <View>
                                    {[<MsgRow key={m["id"]} m={m}/> for m in messages]}{(
                                        <View style={styles.msgAIRow}>
                                            <View style={styles.aiAvatar}>
                                                <Icon
                                                    name="spark"
                                                    size={16}
                                                    color={C.accent}
                                                    fill={True}
                                                    width={2}
                                                />
                                            </View>
                                            <View style={styles.bubbleAI}>
                                                <View style={styles.tlRow}>
                                                    <Spinner color={C.accent}/>
                                                    <Text style={styles.tlText}>
                                                        {thinkMsg}
                                                    </Text>
                                                </View>
                                            </View>
                                        </View>
                                    )
                                        if (thinking and not hasLive)
                                        else <View/>}
                                </View>
                            )}
                    </ScrollView>
                    <ChatComposer/>
                </View>;
        }

        # ── files tab ─────────────────────────────────────────────────────────
        def renderFilesTab -> JsxElement {
            return
                <ScrollView
                    style={styles.scroll}
                    contentContainerStyle={styles.scrollBody}
                    keyboardShouldPersistTaps="handled"
                >
                    <View style={styles.panel}>
                        <View style={styles.panelHead}>
                            <Icon
                                name="file"
                                size={16}
                                color={C.muted}
                                fill={False}
                                width={2}
                            />
                            <Text style={styles.panelTitle}>Files</Text>
                            <Text style={styles.cardMeta}>{len(curFiles)}</Text>
                            <Pressable
                                style={styles.iconBtn}
                                onPress={lambda { s["ensurePreview"](selId); }}
                            >
                                <Icon
                                    name="restart"
                                    size={16}
                                    color={C.muted}
                                    fill={False}
                                    width={2}
                                />
                            </Pressable>
                        </View>
                        {(
                            <View style={styles.empty}>
                                <Text style={styles.emptyText}>
                                    No files yet — start a preview or ask the assistant to build something.
                                </Text>
                            </View>
                        )
                            if len(curFiles) == 0
                            else <View/>}
                        {[
                            <Pressable
                                style={styles.row}
                                key={f}
                                onPress={lambda { s["openFile"](f); }}
                            >
                                <Icon
                                    name="file"
                                    size={16}
                                    color={C.muted}
                                    fill={False}
                                    width={2}
                                />
                                <Text style={[styles.rowTitle, {flex: 1}]}>{f}</Text>
                                <Icon
                                    name="chevron"
                                    size={16}
                                    color={C.faint}
                                    fill={False}
                                    width={2}
                                />
                            </Pressable> for f in curFiles
                        ]}
                    </View>
                </ScrollView>;
        }

        # ── live preview: the real generated web app, in a WebView ────────────
        def renderPreviewTab -> JsxElement {
            previewUrl = s["previewUrl"];
            previewAuthUrl = s["previewAuthUrl"];
            nonce = s["previewNonce"];
            building = s["isBusy"]("chat");
            starting = s["isBusy"]("preview");
            # The sandbox URL is auth-gated. A native WebView top-level-navigates,
            # so jacBuilder's iframe-only `/__auth?t=<token>&embed=1` handshake is
            # rejected by the sandbox proxy (its embed check needs
            # `Sec-Fetch-Dest: iframe`) and bounces to the builder login page.
            # Instead the store mints a signed *handoff* URL
            # (`/__auth?handoff=<h>&next=/`, see refreshPreviewAuth) which the
            # sandbox accepts without an embed check. Wait for that before loading.
            waiting = building
            or starting
            or (previewUrl == "")
            or (previewAuthUrl == "");
            previewSrc = previewAuthUrl;
            return
                <View style={styles.flex1}>
                    <View style={styles.previewBar}>
                        <View style={styles.chip}>
                            <Icon
                                name="phone"
                                size={12}
                                color={C.accent}
                                fill={False}
                                width={2}
                            />
                            <Text style={styles.chipText}>Live preview</Text>
                        </View>
                        <View style={styles.urlBar}>
                            <Icon
                                name="lock"
                                size={12}
                                color={C.muted}
                                fill={False}
                                width={2}
                            />
                            <Text style={styles.urlText}>
                                {previewUrl if previewUrl != "" else "starting…"}
                            </Text>
                        </View>
                        <Pressable
                            style={styles.iconBtn}
                            onPress={lambda { s["bumpPreview"](); }}
                        >
                            <Icon
                                name="restart"
                                size={18}
                                color={C.muted}
                                fill={False}
                                width={2}
                            />
                        </Pressable>
                    </View>
                    {(
                        <View style={styles.empty}>
                            <Spinner color={C.accent}/>
                            <Text style={styles.emptyTitle}>
                                {(
                                    "Generating your app…"
                                        if building
                                        else (
                                            "Starting preview…"
                                                if starting
                                                else "Authorizing preview…"
                                        )
                                )}
                            </Text>
                            <Text style={styles.emptyText}>
                                Your live app renders here as soon as it's built.
                            </Text>
                        </View>
                    )
                        if waiting
                        else (
                            <PreviewFrame
                                url={previewSrc}
                                key={f"{previewUrl}-{nonce}"}
                            />
                        )}
                </View>;
        }

        # ── deploy tab ────────────────────────────────────────────────────────
        def renderDeployTab -> JsxElement {
            deployMode = s["deployMode"];
            busyDeploy = s["isBusy"]("deploy");
            return
                <ScrollView
                    style={styles.scroll}
                    contentContainerStyle={styles.scrollBody}
                    keyboardShouldPersistTaps="handled"
                >
                    <View style={styles.segRow}>
                        {[
                            <Pressable
                                style={(
                                    [styles.segItem, styles.segItemActive]
                                        if deployMode == mo["id"]
                                        else styles.segItem
                                )}
                                key={mo["id"]}
                                onPress={lambda { s["setDeployMode"](mo["id"]); }}
                            >
                                <Text
                                    style={(
                                        styles.segTextActive
                                            if deployMode == mo["id"]
                                            else styles.segText
                                    )}
                                >
                                    {mo["label"]}
                                </Text>
                            </Pressable>
                            for mo in [
                                {"id": "sandbox", "label": "Sandbox"},
                                {"id": "permanent", "label": "Production"}
                            ]
                        ]}
                    </View>
                    <Text style={styles.cardMeta}>
                        {(
                            "A 7-day shareable sandbox for testing."
                                if deployMode == "sandbox"
                                else "A permanent deployment with a public URL, scaling and TLS."
                        )}
                    </Text>
                    <View style={styles.actionRow}>
                        {(
                            <Pressable
                                style={styles.forgeBtn}
                                onPress={lambda { s["stopProj"](p["id"]); }}
                                disabled={busyDeploy}
                            >
                                {(<Spinner color={C.forgeText}/>)
                                    if busyDeploy
                                    else (
                                        <Icon
                                            name="stop"
                                            size={16}
                                            color={C.forgeText}
                                            fill={True}
                                            width={2}
                                        />
                                    )}
                                <Text style={styles.forgeLabel}>Stop</Text>
                            </Pressable>
                        )
                            if (p["status"] == "running")
                            else (
                                <Pressable
                                    style={styles.forgeBtn}
                                    onPress={lambda { s["deploy"](p["id"]); }}
                                    disabled={busyDeploy}
                                >
                                    {(<Spinner color={C.forgeText}/>)
                                        if busyDeploy
                                        else (
                                            <Icon
                                                name="rocket"
                                                size={16}
                                                color={C.forgeText}
                                                fill={False}
                                                width={2}
                                            />
                                        )}
                                    <Text style={styles.forgeLabel}>
                                        {(
                                            "Deploying…"
                                                if busyDeploy
                                                else (
                                                    "Deploy to production"
                                                        if deployMode == "permanent"
                                                        else "Deploy sandbox"
                                                )
                                        )}
                                    </Text>
                                </Pressable>
                            )}
                        <Pressable
                            style={[styles.outlineBtn, {flex: 1}]}
                            onPress={lambda { s["restartProj"](p["id"]); }}
                            disabled={busyDeploy}
                        >
                            {(<Spinner color={C.text}/>)
                                if busyDeploy
                                else (
                                    <Icon
                                        name="restart"
                                        size={16}
                                        color={C.text}
                                        fill={False}
                                        width={2}
                                    />
                                )}
                            <Text style={styles.outlineLabel}>Restart</Text>
                        </Pressable>
                    </View>
                    {(<Progress pct={p["progress"]}/>)
                        if (p["status"] == "building")
                        else <View/>}
                    {(
                        <View style={styles.panel}>
                            <View style={styles.panelHead}>
                                <Icon
                                    name="rocket"
                                    size={16}
                                    color={C.ok}
                                    fill={False}
                                    width={2}
                                />
                                <Text style={styles.panelTitle}>Live URL</Text>
                                {(
                                    <Icon
                                        name="dot"
                                        size={10}
                                        color={C.ok}
                                        fill={True}
                                        width={2}
                                    />
                                )
                                    if (p["status"] == "running")
                                    else <View/>}
                            </View>
                            <View style={styles.rowLast}>
                                <Icon
                                    name="server"
                                    size={14}
                                    color={C.accent}
                                    fill={False}
                                    width={2}
                                />
                                <Text style={[styles.monoSmall, {flex: 1}]}>
                                    {p["url"]}
                                </Text>
                            </View>
                        </View>
                    )
                        if (p["url"] != "" and p["url"] != "jacbuilder.app")
                        else <View/>}
                    <View style={styles.panel}>
                        <View style={styles.panelHead}>
                            <Icon
                                name="server"
                                size={16}
                                color={C.muted}
                                fill={False}
                                width={2}
                            />
                            <Text style={styles.panelTitle}>Services</Text>
                            <Text style={styles.cardMeta}>{len(p["services"])}</Text>
                        </View>
                        {(
                            <View style={styles.rowLast}>
                                <Text style={styles.rowMeta}>
                                    No services yet — deploy to spin up.
                                </Text>
                            </View>
                        )
                            if (len(p["services"]) == 0)
                            else (
                                <View>
                                    {[
                                        <View style={styles.row} key={svc["name"]}>
                                            <Icon
                                                name="dot"
                                                size={10}
                                                color={statusColor(svc["status"])}
                                                fill={True}
                                                width={2}
                                            />
                                            <View style={styles.rowBody}>
                                                <Text style={styles.rowTitle}>
                                                    {svc["name"]}
                                                </Text>
                                                <Text style={styles.rowMeta}>
                                                    {svc["replicas"]} replicas · {svc[
                                                        "status"
                                                    ]}
                                                </Text>
                                            </View>
                                        </View> for svc in p["services"]
                                    ]}
                                </View>
                            )}
                    </View>
                    {(
                        <View style={styles.panel}>
                            <View style={styles.panelHead}>
                                <Icon
                                    name="rocket"
                                    size={16}
                                    color={C.muted}
                                    fill={False}
                                    width={2}
                                />
                                <Text style={styles.panelTitle}>
                                    Custom domain &amp; TLS
                                </Text>
                            </View>
                            <View style={{padding: S.lg, gap: S.sm}}>
                                <View style={styles.fieldRow}>
                                    <Icon
                                        name="branch"
                                        size={16}
                                        color={C.muted}
                                        fill={False}
                                        width={2}
                                    />
                                    <TextInput
                                        style={styles.fieldInput}
                                        value={prodDomain}
                                        placeholder="app.yourdomain.com"
                                        placeholderTextColor={C.muted}
                                        autoCapitalize="none"
                                        onChangeText={lambda v: str { s[
                                            "setProdDomain"
                                        ](
                                            v
                                        ); }}
                                    />
                                </View>
                                <StepRow idx={1} label="Provision subdomain"/>
                                <StepRow idx={2} label="Issue TLS certificate"/>
                                <StepRow idx={3} label="Roll out services"/>
                                <StepRow idx={4} label="Live"/>
                                <Text style={styles.sectionLabel}>DNS records</Text>
                                <DnsRow kind="A" host="@" val="76.76.21.21"/>
                                <DnsRow kind="CNAME" host="www" val={p["url"]}/>
                                <Pressable
                                    style={styles.row}
                                    onPress={lambda { s["setTlsOn"](not tlsOn); }}
                                >
                                    <Icon
                                        name="lock"
                                        size={16}
                                        color={C.muted}
                                        fill={False}
                                        width={2}
                                    />
                                    <Text style={[styles.rowTitle, {flex: 1}]}>
                                        Auto TLS (Let's Encrypt)
                                    </Text>
                                    <Toggle on={tlsOn}/>
                                </Pressable>
                            </View>
                        </View>
                    )
                        if (deployMode == "permanent")
                        else (
                            <View style={styles.panel}>
                                <View style={styles.rowLast}>
                                    <Icon
                                        name="clock"
                                        size={16}
                                        color={C.muted}
                                        fill={False}
                                        width={2}
                                    />
                                    <Text style={[styles.rowMeta, {flex: 1}]}>
                                        Sandbox deploys are shareable for 7 days. Switch to Production for a custom domain, TLS and scaling.
                                    </Text>
                                </View>
                            </View>
                        )}
                    <View style={styles.panel}>
                        <View style={styles.panelHead}>
                            <Icon
                                name="terminal"
                                size={16}
                                color={C.muted}
                                fill={False}
                                width={2}
                            />
                            <Text style={styles.panelTitle}>Logs</Text>
                        </View>
                        <View style={styles.logBox}>
                            {[
                                <Text style={styles.logLine} key={line}>{line}</Text>
                                for line in p["logs"]
                            ]}
                        </View>
                    </View>
                </ScrollView>;
        }

        # ── monitor tab (deploy_monitoring) ───────────────────────────────────
        def monDeployed -> bool {
            return ("deployed" in monitor) and monitor["deployed"];
        }

        def monPods -> list {
            return monitor["pods"] if ("pods" in monitor and monitor["pods"]) else [];
        }

        def monReadyCount -> int {
            n = 0;
            for pod in monPods() {
                if ("ready" in pod) and pod["ready"] {
                    n = n + 1;
                }
            }
            return n;
        }

        def monRestarts -> int {
            n = 0;
            for pod in monPods() {
                n = n + (pod["restarts"] if "restarts" in pod else 0);
            }
            return n;
        }

        def monSpark -> list {
            prom = monitor["prometheus"] if "prometheus" in monitor else {};
            series = prom["series"] if ("series" in prom) else {};
            pts = series["request_rate"] if "request_rate" in series else [];
            vals = [
                float(pt[1])
                for pt in pts
                if len(pt) > 1
            ];
            if len(vals) == 0 {
                return [];
            }
            top = max(vals);
            if top <= 0.0 {
                top = 1.0;
            }
            return [int((v / top) * 36) + 4 for v in vals];
        }

        def monErrorRate -> str {
            prom = monitor["prometheus"] if "prometheus" in monitor else {};
            series = prom["series"] if ("series" in prom) else {};
            pts = series["error_rate"] if "error_rate" in series else [];
            if len(pts) == 0 {
                return "—";
            }
            last = pts[len(pts) - 1];
            v = float(last[1]) if len(last) > 1 else 0.0;
            return f"{(v * 100):.1f}%";
        }

        def renderMonitorTab -> JsxElement {
            bars = monSpark();
            return
                <ScrollView
                    style={styles.scroll}
                    contentContainerStyle={styles.scrollBody}
                    keyboardShouldPersistTaps="handled"
                >
                    {(
                        <View style={styles.empty}>
                            <Icon
                                name="activity"
                                size={30}
                                color={C.muted}
                                fill={False}
                                width={1.6}
                            />
                            <Text style={styles.emptyTitle}>Loading…</Text>
                            <Text style={styles.emptyText}>
                                Fetching live deployment metrics.
                            </Text>
                        </View>
                    )
                        if monLoading
                        else (
                            (
                                <View style={styles.empty}>
                                    <Icon
                                        name="activity"
                                        size={30}
                                        color={C.muted}
                                        fill={False}
                                        width={1.6}
                                    />
                                    <Text style={styles.emptyTitle}>
                                        No live metrics
                                    </Text>
                                    <Text style={styles.emptyText}>
                                        Sandbox previews don't expose cluster metrics — deploy this project to a permanent environment to see pods, request rates and pod logs here.
                                    </Text>
                                </View>
                            )
                                if (not monDeployed())
                                else (
                                    <View style={{gap: S.md}}>
                                        <View style={styles.metricRow}>
                                            <View style={styles.metricTile}>
                                                <Text style={styles.metricBig}>
                                                    {monReadyCount()}/{len(monPods())}
                                                </Text>
                                                <Text style={styles.metricLabel}>
                                                    pods ready
                                                </Text>
                                            </View>
                                            <View style={styles.metricTile}>
                                                <Text style={styles.metricBig}>
                                                    {monRestarts()}
                                                </Text>
                                                <Text style={styles.metricLabel}>
                                                    restarts
                                                </Text>
                                            </View>
                                            <View style={styles.metricTile}>
                                                <Text
                                                    style={[
                                                        styles.metricBig,
                                                        {color: C.ok}
                                                    ]}
                                                >
                                                    {monErrorRate()}
                                                </Text>
                                                <Text style={styles.metricLabel}>
                                                    error rate
                                                </Text>
                                            </View>
                                        </View>
                                        <View style={styles.panel}>
                                            <View style={styles.panelHead}>
                                                <Icon
                                                    name="activity"
                                                    size={16}
                                                    color={C.muted}
                                                    fill={False}
                                                    width={2}
                                                />
                                                <Text style={styles.panelTitle}>
                                                    Requests / sec
                                                </Text>
                                                <Text style={styles.cardMeta}>
                                                    {"live"
                                                        if len(bars) > 0
                                                        else "no data"}
                                                </Text>
                                            </View>
                                            <View style={{padding: S.lg}}>
                                                {(
                                                    <View style={styles.sparkRow}>
                                                        {[
                                                            <View
                                                                style={[
                                                                    styles.sparkBar,
                                                                    {height: v}
                                                                ]}
                                                                key={f"sb-{i}"}
                                                            />
                                                            for (i, v) in enumerate(
                                                                bars
                                                            )
                                                        ]}
                                                    </View>
                                                )
                                                    if len(bars) > 0
                                                    else <Text style={styles.cardMeta}>
                                                        No request samples in the last 30 min.
                                                    </Text>}
                                            </View>
                                        </View>
                                        <View style={styles.panel}>
                                            <View style={styles.panelHead}>
                                                <Icon
                                                    name="server"
                                                    size={16}
                                                    color={C.muted}
                                                    fill={False}
                                                    width={2}
                                                />
                                                <Text style={styles.panelTitle}>
                                                    Endpoint
                                                </Text>
                                            </View>
                                            <View style={styles.rowLast}>
                                                <Icon
                                                    name="dot"
                                                    size={10}
                                                    color={C.ok}
                                                    fill={True}
                                                    width={2}
                                                />
                                                <Text
                                                    style={[
                                                        styles.monoSmall,
                                                        {flex: 1}
                                                    ]}
                                                >
                                                    {monitor["url"]
                                                        if (
                                                            "url" in monitor
                                                            and monitor["url"]
                                                        )
                                                        else p["url"]}
                                                </Text>
                                            </View>
                                        </View>
                                        <View style={styles.panel}>
                                            <View style={styles.panelHead}>
                                                <Icon
                                                    name="terminal"
                                                    size={16}
                                                    color={C.muted}
                                                    fill={False}
                                                    width={2}
                                                />
                                                <Text style={styles.panelTitle}>
                                                    Pod logs
                                                </Text>
                                                <Text style={styles.cardMeta}>
                                                    {len(monLogs)}
                                                </Text>
                                            </View>
                                            <View style={styles.logBox}>
                                                {[
                                                    <Text
                                                        style={styles.logLine}
                                                        key={f"ml-{i}"}
                                                    >
                                                        {line}
                                                    </Text>
                                                    for (i, line) in enumerate(monLogs)
                                                ]}
                                            </View>
                                        </View>
                                    </View>
                                )
                        )}
                </ScrollView>;
        }

        # ── detail shell ──────────────────────────────────────────────────────
        return
            <View style={styles.page}>
                <View style={styles.detailHead}>
                    <View style={styles.detailTitleRow}>
                        <Pressable style={styles.iconBtn} onPress={s["closeProject"]}>
                            <Icon
                                name="back"
                                size={24}
                                color={C.text}
                                fill={False}
                                width={2}
                            />
                        </Pressable>
                        <View style={{flex: 1, gap: 2}}>
                            <Text style={styles.detailTitle}>{p["name"]}</Text>
                            <View style={styles.cardMetaRow}>
                                <Icon
                                    name="branch"
                                    size={12}
                                    color={C.muted}
                                    fill={False}
                                    width={2}
                                />
                                <Text style={styles.cardMeta}>
                                    {p["branch"]} · {p["region"]}
                                </Text>
                            </View>
                        </View>
                        <StatusPill status={p["status"]}/>
                        <Pressable
                            style={styles.overflowBtn}
                            onPress={lambda { s["setShareId"](p["id"]); }}
                        >
                            <Icon
                                name="clone"
                                size={18}
                                color={C.muted}
                                fill={False}
                                width={2}
                            />
                        </Pressable>
                    </View>
                </View>
                <View style={styles.detailTabs}>
                    <DetTab tabKey="chat" icon="spark" label="Chat"/>
                    <DetTab tabKey="files" icon="file" label="Files"/>
                    <DetTab tabKey="preview" icon="phone" label="Preview"/>
                    <DetTab tabKey="deploy" icon="rocket" label="Deploy"/>
                    <DetTab tabKey="monitor" icon="activity" label="Monitor"/>
                </View>
                <View style={styles.flex1}>
                    {renderChatTab()
                        if (detTab == "chat")
                        else (
                            renderFilesTab()
                                if (detTab == "files")
                                else (
                                    renderPreviewTab()
                                        if (detTab == "preview")
                                        else (
                                            renderDeployTab()
                                                if (detTab == "deploy")
                                                else renderMonitorTab()
                                        )
                                )
                        )}
                </View>
            </View>;
    }
}
