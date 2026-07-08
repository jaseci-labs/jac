"""Design system — palettes + a StyleSheet factory, shared by the whole app.

Two palettes (`DARK`, `LIGHT`) share the same key set; `buildStyles(palette)`
bakes a StyleSheet from whichever is active, so the app can flip themes at
runtime (`main.jac` prebuilds both and picks one). `S`/`R`/`F` (spacing, radii,
font sizes) are theme-independent. Re-skin by editing a palette below.
"""

cl {
    import from "@jac/mobui" { StyleSheet }

    # ── palettes (same keys, two looks) ───────────────────────────────────────
    glob:pub DARK = {
             bg: "#0b0d12",
             surface: "#12151c",
             elevated: "#181c25",
             border: "#232936",
             text: "#e6e9ef",
             muted: "#8a93a6",
             faint: "#59617a",
             accent: "#7c5cff",
             accentSoft: "#241f3d",
             accentText: "#ffffff",
             forge: "#ff9d3c",
             forgeText: "#1a1206",
             ok: "#31c76a",
             warn: "#f5b83d",
             danger: "#f4544e",
             field: "#171b23",
             track: "#232936",
             scrim: "rgba(0,0,0,0.62)"
         };
    glob:pub LIGHT = {
             bg: "#f5f6fb",
             surface: "#ffffff",
             elevated: "#eef0f7",
             border: "#e2e5ee",
             text: "#14161c",
             muted: "#5c6579",
             faint: "#99a0b3",
             accent: "#6b46ff",
             accentSoft: "#ece8ff",
             accentText: "#ffffff",
             forge: "#e8760a",
             forgeText: "#ffffff",
             ok: "#1a9e52",
             warn: "#b07d0a",
             danger: "#d6342c",
             field: "#ffffff",
             track: "#e2e5ee",
             scrim: "rgba(15,18,25,0.35)"
         };
    glob:pub S = {xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 28, huge: 40};
    glob:pub R = {sm: 8, md: 12, lg: 16, round: 22, pill: 999};
    glob:pub F = {xs: 12, sm: 14, md: 16, lg: 20, xl: 26, huge: 34};

    def:pub buildStyles(C: dict) -> dict {
        return StyleSheet.create(
            {
                root: {flex: 1, backgroundColor: C.bg},
                page: {flex: 1, width: "100%", maxWidth: 560, alignSelf: "center"},
                scroll: {flex: 1},
                scrollBody: {padding: S.lg, gap: S.md, paddingBottom: S.huge},
                body: {flex: 1},
                divider: {height: 1, backgroundColor: C.border},
                flex1: {flex: 1},
                kav: {flex: 1, width: "100%"},

                # splash
                splash: {
                    flex: 1,
                    backgroundColor: C.bg,
                    alignItems: "center",
                    justifyContent: "center",
                    gap: S.lg
                },
                splashLogo: {
                    width: 88,
                    height: 88,
                    borderRadius: R.round,
                    backgroundColor: C.accent,
                    alignItems: "center",
                    justifyContent: "center"
                },
                splashTitle: {color: C.text, fontSize: F.huge, fontWeight: "bold"},
                splashTag: {color: C.muted, fontSize: F.sm},

                # auth
                authWrap: {
                    flex: 1,
                    width: "100%",
                    maxWidth: 400,
                    alignSelf: "center",
                    backgroundColor: C.bg,
                    padding: S.xl,
                    justifyContent: "center",
                    gap: S.md
                },
                authLogo: {
                    width: 60,
                    height: 60,
                    borderRadius: R.round,
                    backgroundColor: C.accent,
                    alignItems: "center",
                    justifyContent: "center",
                    alignSelf: "center"
                },
                authTitle: {
                    color: C.text,
                    fontSize: F.xl,
                    fontWeight: "bold",
                    textAlign: "center"
                },
                authSub: {
                    color: C.muted,
                    fontSize: F.sm,
                    textAlign: "center",
                    marginTop: 0 - S.xs
                },
                fieldRow: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.sm,
                    borderWidth: 1,
                    borderColor: C.border,
                    borderRadius: R.md,
                    backgroundColor: C.field,
                    paddingHorizontal: S.md
                },
                fieldInput: {
                    flex: 1,
                    color: C.text,
                    fontSize: F.md,
                    paddingVertical: S.md
                },
                errorText: {color: C.danger, fontSize: F.sm, textAlign: "center"},
                switchRow: {
                    flexDirection: "row",
                    justifyContent: "center",
                    gap: S.xs,
                    marginTop: S.xs
                },
                switchText: {color: C.muted, fontSize: F.sm},
                switchLink: {color: C.accent, fontSize: F.sm, fontWeight: "bold"},
                oauthBtn: {
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: S.sm,
                    borderWidth: 1,
                    borderColor: C.border,
                    borderRadius: R.pill,
                    paddingVertical: S.md,
                    backgroundColor: C.field
                },
                oauthText: {color: C.text, fontSize: F.sm, fontWeight: "600"},
                orRow: {flexDirection: "row", alignItems: "center", gap: S.sm},
                orLine: {flex: 1, height: 1, backgroundColor: C.border},
                orText: {color: C.faint, fontSize: F.xs},

                # buttons
                primaryBtn: {
                    backgroundColor: C.accent,
                    borderRadius: R.pill,
                    paddingVertical: S.md,
                    paddingHorizontal: S.lg,
                    alignItems: "center",
                    justifyContent: "center",
                    flexDirection: "row",
                    gap: S.sm
                },
                primaryLabel: {color: C.accentText, fontSize: F.md, fontWeight: "bold"},
                forgeBtn: {
                    backgroundColor: C.forge,
                    borderRadius: R.pill,
                    paddingVertical: S.md,
                    paddingHorizontal: S.lg,
                    alignItems: "center",
                    justifyContent: "center",
                    flexDirection: "row",
                    gap: S.sm,
                    flex: 1
                },
                forgeLabel: {color: C.forgeText, fontSize: F.sm, fontWeight: "bold"},
                outlineBtn: {
                    borderWidth: 1,
                    borderColor: C.border,
                    borderRadius: R.pill,
                    paddingVertical: S.md,
                    paddingHorizontal: S.lg,
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: S.sm
                },
                outlineLabel: {color: C.text, fontSize: F.sm, fontWeight: "bold"},
                dangerBtn: {
                    borderWidth: 1,
                    borderColor: C.danger,
                    borderRadius: R.pill,
                    paddingVertical: S.md,
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: S.sm
                },
                dangerLabel: {color: C.danger, fontSize: F.sm, fontWeight: "bold"},

                # header + tab bar
                header: {
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "space-between",
                    paddingVertical: S.md,
                    paddingHorizontal: S.lg,
                    borderBottomWidth: 1,
                    borderBottomColor: C.border
                },
                headerBrand: {flexDirection: "row", alignItems: "center", gap: S.sm},
                headerLogo: {
                    width: 34,
                    height: 34,
                    borderRadius: R.md,
                    backgroundColor: C.accent,
                    alignItems: "center",
                    justifyContent: "center"
                },
                headerTitle: {color: C.text, fontSize: F.lg, fontWeight: "bold"},
                headerSub: {color: C.muted, fontSize: F.xs},
                headerRight: {flexDirection: "row", alignItems: "center", gap: S.sm},
                iconBtn: {
                    width: 40,
                    height: 40,
                    borderRadius: R.pill,
                    alignItems: "center",
                    justifyContent: "center"
                },
                tabBar: {
                    flexDirection: "row",
                    borderTopWidth: 1,
                    borderTopColor: C.border,
                    backgroundColor: C.bg,
                    paddingVertical: S.sm
                },
                tabItem: {
                    flex: 1,
                    alignItems: "center",
                    justifyContent: "center",
                    paddingVertical: S.xs,
                    gap: 2
                },
                tabLabel: {fontSize: 11},

                # section label
                sectionRow: {
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "space-between",
                    paddingHorizontal: S.xs,
                    paddingTop: S.sm
                },
                sectionLabel: {color: C.muted, fontSize: F.sm, fontWeight: "bold"},
                sectionAction: {flexDirection: "row", alignItems: "center", gap: S.xs},
                sectionActionText: {color: C.accent, fontSize: F.sm, fontWeight: "bold"},

                # generic card
                card: {
                    backgroundColor: C.surface,
                    borderRadius: R.lg,
                    borderWidth: 1,
                    borderColor: C.border,
                    padding: S.lg,
                    gap: S.md
                },
                cardTop: {flexDirection: "row", alignItems: "center", gap: S.md},
                cardIcon: {
                    width: 44,
                    height: 44,
                    borderRadius: R.md,
                    backgroundColor: C.accentSoft,
                    alignItems: "center",
                    justifyContent: "center"
                },
                cardHeadCol: {flex: 1, gap: 2},
                cardName: {color: C.text, fontSize: F.md, fontWeight: "bold"},
                cardMetaRow: {flexDirection: "row", alignItems: "center", gap: S.xs},
                cardMeta: {color: C.muted, fontSize: F.xs},
                overflowBtn: {padding: S.xs},

                # status pill
                pill: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.xs,
                    paddingVertical: 3,
                    paddingHorizontal: S.sm,
                    borderRadius: R.pill,
                    backgroundColor: C.elevated
                },
                pillText: {fontSize: F.xs, fontWeight: "bold"},

                # progress
                progressTrack: {
                    height: 6,
                    borderRadius: R.pill,
                    backgroundColor: C.track,
                    overflow: "hidden"
                },
                progressFill: {height: 6, borderRadius: R.pill, backgroundColor: C.forge},
                progressRow: {
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "space-between"
                },

                # chips
                chipRow: {flexDirection: "row", flexWrap: "wrap", gap: S.sm},
                chip: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.xs,
                    paddingVertical: S.xs,
                    paddingHorizontal: S.sm,
                    borderRadius: R.pill,
                    backgroundColor: C.elevated
                },
                chipText: {color: C.muted, fontSize: F.xs},
                chipActive: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.xs,
                    paddingVertical: S.xs,
                    paddingHorizontal: S.md,
                    borderRadius: R.pill,
                    backgroundColor: C.accent
                },
                chipActiveText: {color: C.accentText, fontSize: F.sm, fontWeight: "bold"},
                tag: {
                    paddingVertical: 2,
                    paddingHorizontal: S.sm,
                    borderRadius: R.pill,
                    backgroundColor: C.elevated
                },
                tagText: {color: C.muted, fontSize: F.xs},

                # segmented control
                segRow: {
                    flexDirection: "row",
                    backgroundColor: C.elevated,
                    borderRadius: R.pill,
                    padding: 3
                },
                segItem: {
                    flex: 1,
                    alignItems: "center",
                    paddingVertical: S.xs,
                    borderRadius: R.pill
                },
                segItemActive: {backgroundColor: C.accent},
                segText: {color: C.muted, fontSize: F.xs, fontWeight: "600"},
                segTextActive: {color: C.accentText, fontSize: F.xs, fontWeight: "bold"},
                sortPill: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.xs,
                    paddingVertical: S.xs,
                    paddingHorizontal: S.md,
                    borderRadius: R.pill,
                    borderWidth: 1,
                    borderColor: C.border
                },

                # detail
                detailHead: {
                    padding: S.lg,
                    gap: S.md,
                    borderBottomWidth: 1,
                    borderBottomColor: C.border
                },
                detailTitleRow: {flexDirection: "row", alignItems: "center", gap: S.md},
                detailTitle: {color: C.text, fontSize: F.xl, fontWeight: "bold"},
                actionRow: {flexDirection: "row", gap: S.sm},
                detailTabs: {
                    flexDirection: "row",
                    borderBottomWidth: 1,
                    borderBottomColor: C.border
                },
                detailTab: {
                    flex: 1,
                    alignItems: "center",
                    paddingVertical: S.sm,
                    gap: 2,
                    borderBottomWidth: 2,
                    borderBottomColor: "transparent"
                },
                detailTabActive: {borderBottomColor: C.accent},
                detailTabText: {fontSize: 10},
                panel: {
                    backgroundColor: C.surface,
                    borderRadius: R.lg,
                    borderWidth: 1,
                    borderColor: C.border,
                    overflow: "hidden"
                },
                panelHead: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.sm,
                    paddingVertical: S.md,
                    paddingHorizontal: S.lg,
                    borderBottomWidth: 1,
                    borderBottomColor: C.border
                },
                panelTitle: {color: C.text, fontSize: F.sm, fontWeight: "bold", flex: 1},

                # rows
                row: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.md,
                    paddingVertical: S.md,
                    paddingHorizontal: S.lg,
                    borderBottomWidth: 1,
                    borderBottomColor: C.border
                },
                rowLast: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.md,
                    paddingVertical: S.md,
                    paddingHorizontal: S.lg
                },
                rowBody: {flex: 1, gap: 2},
                rowTitle: {color: C.text, fontSize: F.sm, fontWeight: "600"},
                rowMeta: {color: C.muted, fontSize: F.xs},
                optionLabel: {color: C.text, fontSize: F.sm, flex: 1},

                # logs / code
                logBox: {backgroundColor: "#05070b", padding: S.md, gap: 2},
                logLine: {color: C.muted, fontSize: F.xs, fontFamily: "monospace"},
                codeBox: {backgroundColor: "#05070b", padding: S.md, borderRadius: R.md},
                codeLine: {
                    color: "#e6e9ef",
                    fontSize: 13,
                    fontFamily: "monospace",
                    lineHeight: 20
                },
                monoSmall: {color: C.text, fontSize: F.xs, fontFamily: "monospace"},

                # community
                commCard: {
                    backgroundColor: C.surface,
                    borderRadius: R.lg,
                    borderWidth: 1,
                    borderColor: C.border,
                    padding: S.lg,
                    gap: S.sm
                },
                commTopRow: {flexDirection: "row", alignItems: "center", gap: S.md},
                commBody: {flex: 1, gap: 2},
                commDesc: {color: C.muted, fontSize: F.sm, lineHeight: 20},
                commFoot: {
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "space-between",
                    marginTop: S.xs
                },

                # activity
                actIcon: {
                    width: 38,
                    height: 38,
                    borderRadius: R.pill,
                    backgroundColor: C.elevated,
                    alignItems: "center",
                    justifyContent: "center"
                },
                actText: {color: C.text, fontSize: F.sm, lineHeight: 20},
                actMeta: {color: C.faint, fontSize: F.xs},

                # profile
                profHead: {alignItems: "center", gap: S.sm, padding: S.xl},
                profAvatar: {
                    width: 84,
                    height: 84,
                    borderRadius: R.pill,
                    backgroundColor: C.accentSoft,
                    alignItems: "center",
                    justifyContent: "center"
                },
                profName: {color: C.text, fontSize: F.xl, fontWeight: "bold"},
                profHandle: {color: C.muted, fontSize: F.sm},
                statsRow: {
                    flexDirection: "row",
                    justifyContent: "center",
                    gap: S.xxl,
                    marginTop: S.sm
                },
                statBig: {
                    color: C.text,
                    fontSize: F.lg,
                    fontWeight: "bold",
                    textAlign: "center"
                },
                statLabel: {color: C.muted, fontSize: F.xs, textAlign: "center"},

                # toggle
                switchTrack: {
                    width: 46,
                    height: 28,
                    borderRadius: R.pill,
                    backgroundColor: C.track,
                    padding: 3,
                    flexDirection: "row",
                    alignItems: "center"
                },
                switchTrackOn: {backgroundColor: C.accent, justifyContent: "flex-end"},
                switchThumb: {
                    width: 22,
                    height: 22,
                    borderRadius: R.pill,
                    backgroundColor: "#ffffff"
                },

                # notifications badge
                badge: {
                    position: "absolute",
                    top: 4,
                    right: 4,
                    minWidth: 16,
                    height: 16,
                    borderRadius: R.pill,
                    backgroundColor: C.forge,
                    alignItems: "center",
                    justifyContent: "center",
                    paddingHorizontal: 3
                },
                badgeText: {color: C.forgeText, fontSize: 10, fontWeight: "bold"},
                unreadDot: {width: 9, height: 9, borderRadius: R.pill, backgroundColor: C.accent},

                # home / prompt
                greeting: {color: C.text, fontSize: F.xl, fontWeight: "bold"},
                greetingSub: {color: C.muted, fontSize: F.sm},
                promptCard: {
                    backgroundColor: C.surface,
                    borderRadius: R.lg,
                    borderWidth: 1,
                    borderColor: C.border,
                    padding: S.md,
                    gap: S.sm
                },
                promptInput: {
                    color: C.text,
                    fontSize: F.md,
                    minHeight: 60,
                    textAlignVertical: "top"
                },
                promptBar: {
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "space-between"
                },
                promptTools: {flexDirection: "row", alignItems: "center", gap: S.sm},
                sendFab: {
                    width: 40,
                    height: 40,
                    borderRadius: R.pill,
                    backgroundColor: C.accent,
                    alignItems: "center",
                    justifyContent: "center"
                },
                modelChip: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.xs,
                    paddingVertical: S.xs,
                    paddingHorizontal: S.sm,
                    borderRadius: R.pill,
                    backgroundColor: C.elevated
                },
                modelChipText: {color: C.muted, fontSize: F.xs, fontWeight: "600"},
                creditsPill: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.xs,
                    paddingVertical: 4,
                    paddingHorizontal: S.sm,
                    borderRadius: R.pill,
                    backgroundColor: C.accentSoft
                },
                creditsText: {color: C.accent, fontSize: F.xs, fontWeight: "bold"},
                tileRow: {flexDirection: "row", gap: S.md},
                tile: {
                    flex: 1,
                    backgroundColor: C.surface,
                    borderRadius: R.lg,
                    borderWidth: 1,
                    borderColor: C.border,
                    padding: S.md,
                    gap: S.xs,
                    alignItems: "flex-start"
                },
                tileTitle: {color: C.text, fontSize: F.sm, fontWeight: "600"},
                tileMeta: {color: C.muted, fontSize: F.xs},

                # chat
                msgUserRow: {
                    flexDirection: "row",
                    justifyContent: "flex-end",
                    paddingHorizontal: S.lg,
                    paddingVertical: S.xs
                },
                msgAIRow: {
                    flexDirection: "row",
                    paddingHorizontal: S.lg,
                    paddingVertical: S.xs,
                    gap: S.sm
                },
                bubbleUser: {
                    backgroundColor: C.accent,
                    borderRadius: R.lg,
                    paddingVertical: S.sm,
                    paddingHorizontal: S.md,
                    maxWidth: "82%"
                },
                bubbleUserText: {color: C.accentText, fontSize: F.sm, lineHeight: 20},
                aiAvatar: {
                    width: 30,
                    height: 30,
                    borderRadius: R.pill,
                    backgroundColor: C.accentSoft,
                    alignItems: "center",
                    justifyContent: "center"
                },
                bubbleAI: {
                    flex: 1,
                    backgroundColor: C.surface,
                    borderWidth: 1,
                    borderColor: C.border,
                    borderRadius: R.lg,
                    padding: S.md,
                    gap: S.sm
                },
                aiText: {color: C.text, fontSize: F.sm, lineHeight: 21},
                tlRow: {flexDirection: "row", alignItems: "center", gap: S.sm},
                tlText: {color: C.muted, fontSize: F.xs, flex: 1},
                tlTextDone: {color: C.ok, fontSize: F.xs, flex: 1},
                revertBtn: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.xs,
                    alignSelf: "flex-start",
                    paddingVertical: 4,
                    paddingHorizontal: S.sm,
                    borderRadius: R.pill,
                    borderWidth: 1,
                    borderColor: C.border
                },
                revertText: {color: C.muted, fontSize: F.xs},
                clarifyCard: {backgroundColor: C.accentSoft, borderRadius: R.md, padding: S.md, gap: S.sm},
                chatComposer: {
                    flexDirection: "row",
                    alignItems: "flex-end",
                    gap: S.sm,
                    padding: S.md,
                    borderTopWidth: 1,
                    borderTopColor: C.border
                },
                chatInput: {
                    flex: 1,
                    color: C.text,
                    fontSize: F.sm,
                    backgroundColor: C.field,
                    borderRadius: R.lg,
                    paddingVertical: S.sm,
                    paddingHorizontal: S.md,
                    maxHeight: 120
                },
                composerBtn: {
                    width: 36,
                    height: 36,
                    borderRadius: R.pill,
                    alignItems: "center",
                    justifyContent: "center"
                },

                # preview / device
                deviceWrap: {alignItems: "center", padding: S.lg, gap: S.md},
                previewBar: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.sm,
                    padding: S.sm,
                    borderBottomWidth: 1,
                    borderBottomColor: C.border
                },
                urlBar: {
                    flex: 1,
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.xs,
                    backgroundColor: C.field,
                    borderRadius: R.pill,
                    paddingVertical: S.xs,
                    paddingHorizontal: S.md
                },
                urlText: {color: C.muted, fontSize: F.xs, flex: 1},
                deviceFrame: {
                    borderWidth: 8,
                    borderColor: "#000000",
                    borderRadius: 30,
                    overflow: "hidden",
                    backgroundColor: C.bg
                },
                mockApp: {padding: S.lg, gap: S.md, flex: 1},
                mockBar: {
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "space-between",
                    paddingBottom: S.sm,
                    borderBottomWidth: 1,
                    borderBottomColor: C.border
                },
                mockRow: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.sm,
                    paddingVertical: S.sm
                },
                mockDot: {
                    width: 32,
                    height: 32,
                    borderRadius: R.pill,
                    backgroundColor: C.accentSoft
                },
                mockLineWide: {height: 8, borderRadius: R.pill, backgroundColor: C.elevated, flex: 1},
                mockLineThin: {height: 6, borderRadius: R.pill, backgroundColor: C.elevated, width: "60%"},

                # monitor
                metricRow: {flexDirection: "row", gap: S.sm},
                metricTile: {
                    flex: 1,
                    backgroundColor: C.surface,
                    borderWidth: 1,
                    borderColor: C.border,
                    borderRadius: R.md,
                    padding: S.md,
                    gap: S.xs
                },
                metricBig: {color: C.text, fontSize: F.lg, fontWeight: "bold"},
                metricLabel: {color: C.muted, fontSize: F.xs},
                sparkRow: {
                    flexDirection: "row",
                    alignItems: "flex-end",
                    gap: 2,
                    height: 28,
                    marginTop: S.xs
                },
                sparkBar: {flex: 1, backgroundColor: C.accent, borderRadius: 2},
                copyBtn: {
                    flexDirection: "row",
                    alignItems: "center",
                    gap: S.xs,
                    paddingVertical: S.xs,
                    paddingHorizontal: S.sm,
                    borderRadius: R.sm,
                    backgroundColor: C.elevated
                },

                # deploy steps
                stepRow: {flexDirection: "row", alignItems: "center", gap: S.sm, paddingVertical: S.xs},
                stepDot: {
                    width: 22,
                    height: 22,
                    borderRadius: R.pill,
                    alignItems: "center",
                    justifyContent: "center"
                },
                stepText: {color: C.text, fontSize: F.sm, flex: 1},

                # billing
                planCard: {
                    backgroundColor: C.surface,
                    borderWidth: 1,
                    borderColor: C.accent,
                    borderRadius: R.lg,
                    padding: S.lg,
                    gap: S.sm
                },
                priceBig: {color: C.text, fontSize: F.xl, fontWeight: "bold"},
                compareCol: {
                    flex: 1,
                    backgroundColor: C.surface,
                    borderWidth: 1,
                    borderColor: C.border,
                    borderRadius: R.md,
                    padding: S.md,
                    gap: S.xs
                },

                # modals
                modalOverlay: {
                    position: "absolute",
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    backgroundColor: C.scrim,
                    alignItems: "center",
                    justifyContent: "flex-end"
                },
                modalCard: {
                    width: "100%",
                    maxWidth: 560,
                    backgroundColor: C.bg,
                    borderTopLeftRadius: R.round,
                    borderTopRightRadius: R.round,
                    borderWidth: 1,
                    borderColor: C.border,
                    padding: S.lg,
                    gap: S.md
                },
                modalHead: {
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "space-between"
                },
                modalTitle: {color: C.text, fontSize: F.md, fontWeight: "bold"},
                sheetScroll: {maxHeight: 380},

                # empty
                empty: {padding: S.huge, alignItems: "center", gap: S.sm},
                emptyTitle: {color: C.text, fontSize: F.md, fontWeight: "bold"},
                emptyText: {color: C.muted, fontSize: F.sm, textAlign: "center"}
            }
        );
    }

    # Prebuild both palettes once; screens pick one per render (runtime toggle).
    glob:pub STYLES_DARK = buildStyles(DARK);
    glob:pub STYLES_LIGHT = buildStyles(LIGHT);
}
