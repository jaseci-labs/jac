"""Design system — tokens + StyleSheet, shared by the whole app.

Platform-agnostic (no `.native` variant needed), so `main.jac` imports
`C` (colors), `S` (spacing), `R` (radii), `F` (font sizes) and `styles` from
here. Re-skin the entire app by editing the token globals below.
"""

cl {
    import from "@jac/mobui" { StyleSheet }

    # ── Design tokens — OLED-black theme ──────────────────────────────────────
    glob:pub C = {
             bg: "#000000",
             surface: "#16181c",
             elevated: "#1d1f23",
             border: "#2f3336",
             text: "#e7e9ea",
             muted: "#71767b",
             accent: "#1d9bf0",
             accentText: "#ffffff",
             like: "#f91880",
             rt: "#00ba7c",
             danger: "#f4212e",
             field: "#202327",
             scrim: "rgba(0,0,0,0.6)"
         };
    glob:pub S = {xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 28, huge: 40};
    glob:pub R = {sm: 8, md: 12, lg: 16, round: 24, pill: 999};
    glob:pub F = {xs: 13, sm: 15, md: 17, lg: 20, xl: 26, huge: 34};

    glob:pub styles = StyleSheet.create(
             {
                 root: {flex: 1, backgroundColor: C.bg},
                 page: {flex: 1, width: "100%", maxWidth: 640, alignSelf: "center"},
                 # splash
                 splash: {
                     flex: 1,
                     backgroundColor: C.bg,
                     alignItems: "center",
                     justifyContent: "center",
                     gap: S.lg
                 },
                 splashLogo: {
                     width: 84,
                     height: 84,
                     borderRadius: R.round,
                     backgroundColor: C.accent,
                     alignItems: "center",
                     justifyContent: "center"
                 },
                 splashTitle: {color: C.text, fontSize: F.huge, fontWeight: "bold"},
                 splashTag: {color: C.muted, fontSize: F.sm},
                 # auth — a centered card, capped so it stays a tidy column on wide web
                 authWrap: {
                     flex: 1,
                     width: "100%",
                     maxWidth: 380,
                     alignSelf: "center",
                     backgroundColor: C.bg,
                     padding: S.xl,
                     justifyContent: "center",
                     gap: S.lg
                 },
                 authLogo: {
                     width: 56,
                     height: 56,
                     borderRadius: R.pill,
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
                     marginTop: 0 - S.sm
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
                 primaryBtn: {
                     backgroundColor: C.accent,
                     borderRadius: R.pill,
                     paddingVertical: S.md,
                     alignItems: "center",
                     marginTop: S.xs
                 },
                 primaryLabel: {
                     color: C.accentText,
                     fontSize: F.md,
                     fontWeight: "bold"
                 },
                 switchRow: {
                     flexDirection: "row",
                     justifyContent: "center",
                     gap: S.xs,
                     marginTop: S.xs
                 },
                 switchText: {color: C.muted, fontSize: F.sm},
                 switchLink: {color: C.accent, fontSize: F.sm, fontWeight: "bold"},
                 # header
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
                     width: 32,
                     height: 32,
                     borderRadius: R.pill,
                     backgroundColor: C.accent,
                     alignItems: "center",
                     justifyContent: "center"
                 },
                 headerTitle: {color: C.text, fontSize: F.lg, fontWeight: "bold"},
                 avatarBtn: {borderRadius: R.pill, overflow: "hidden"},
                 # body / tab bar
                 body: {flex: 1},
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
                 # composer
                 composer: {
                     flexDirection: "row",
                     gap: S.md,
                     padding: S.lg,
                     borderBottomWidth: 1,
                     borderBottomColor: C.border
                 },
                 composerCol: {flex: 1, gap: S.sm},
                 composerInput: {
                     color: C.text,
                     fontSize: F.md,
                     paddingVertical: S.sm,
                     minHeight: 44
                 },
                 composerActions: {
                     flexDirection: "row",
                     justifyContent: "flex-end",
                     alignItems: "center",
                     gap: S.md
                 },
                 # tweet card
                 card: {
                     flexDirection: "row",
                     gap: S.md,
                     paddingVertical: S.lg,
                     paddingHorizontal: S.lg,
                     borderBottomWidth: 1,
                     borderBottomColor: C.border
                 },
                 avatar: {borderRadius: R.pill, backgroundColor: C.elevated},
                 cardBody: {flex: 1, gap: S.xs},
                 cardHead: {flexDirection: "row", alignItems: "center", gap: S.xs},
                 name: {color: C.text, fontSize: F.sm, fontWeight: "bold"},
                 handle: {color: C.muted, fontSize: F.sm},
                 cardText: {color: C.text, fontSize: F.md, lineHeight: 22},
                 actions: {
                     flexDirection: "row",
                     justifyContent: "space-between",
                     marginTop: S.sm,
                     paddingRight: S.huge
                 },
                 action: {flexDirection: "row", alignItems: "center", gap: S.xs},
                 actionCount: {fontSize: F.xs, color: C.muted},
                 actionCountLiked: {fontSize: F.xs, color: C.like},
                 actionCountRt: {fontSize: F.xs, color: C.rt},
                 # comment modal
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
                     maxWidth: 640,
                     maxHeight: "80%",
                     backgroundColor: C.bg,
                     borderTopLeftRadius: R.round,
                     borderTopRightRadius: R.round,
                     borderWidth: 1,
                     borderColor: C.border
                 },
                 modalHead: {
                     flexDirection: "row",
                     alignItems: "center",
                     justifyContent: "space-between",
                     paddingVertical: S.md,
                     paddingHorizontal: S.lg,
                     borderBottomWidth: 1,
                     borderBottomColor: C.border
                 },
                 modalTitle: {color: C.text, fontSize: F.md, fontWeight: "bold"},
                 modalList: {paddingHorizontal: S.lg},
                 commentRow: {
                     flexDirection: "row",
                     gap: S.sm,
                     paddingVertical: S.md,
                     borderBottomWidth: 1,
                     borderBottomColor: C.border
                 },
                 commentBody: {flex: 1, gap: 2},
                 commentName: {color: C.text, fontSize: F.sm, fontWeight: "bold"},
                 commentMeta: {color: C.muted, fontSize: F.xs},
                 commentText: {color: C.text, fontSize: F.sm, lineHeight: 20},
                 commentComposer: {
                     flexDirection: "row",
                     alignItems: "center",
                     gap: S.sm,
                     padding: S.md,
                     borderTopWidth: 1,
                     borderTopColor: C.border
                 },
                 commentInput: {
                     flex: 1,
                     color: C.text,
                     fontSize: F.sm,
                     backgroundColor: C.field,
                     borderRadius: R.pill,
                     paddingVertical: S.sm,
                     paddingHorizontal: S.lg
                 },
                 sendBtn: {
                     width: 40,
                     height: 40,
                     borderRadius: R.pill,
                     backgroundColor: C.accent,
                     alignItems: "center",
                     justifyContent: "center"
                 },
                 modalEmpty: {paddingVertical: S.huge, alignItems: "center"},
                 # search
                 searchBar: {
                     flexDirection: "row",
                     alignItems: "center",
                     gap: S.sm,
                     margin: S.lg,
                     borderRadius: R.pill,
                     backgroundColor: C.field,
                     paddingHorizontal: S.md,
                     paddingVertical: S.xs
                 },
                 searchInput: {
                     flex: 1,
                     color: C.text,
                     fontSize: F.md,
                     paddingVertical: S.sm
                 },
                 # notifications
                 noteRow: {
                     flexDirection: "row",
                     gap: S.md,
                     padding: S.lg,
                     alignItems: "flex-start",
                     borderBottomWidth: 1,
                     borderBottomColor: C.border
                 },
                 noteIcon: {
                     width: 36,
                     height: 36,
                     borderRadius: R.pill,
                     backgroundColor: C.elevated,
                     alignItems: "center",
                     justifyContent: "center"
                 },
                 noteBody: {flex: 1, gap: 2},
                 noteText: {color: C.text, fontSize: F.sm},
                 noteSnippet: {color: C.muted, fontSize: F.sm},
                 # profile
                 profileHead: {
                     padding: S.lg,
                     gap: S.md,
                     borderBottomWidth: 1,
                     borderBottomColor: C.border
                 },
                 profileTopRow: {
                     flexDirection: "row",
                     justifyContent: "space-between",
                     alignItems: "flex-start"
                 },
                 profileName: {color: C.text, fontSize: F.xl, fontWeight: "bold"},
                 profileHandle: {color: C.muted, fontSize: F.sm},
                 profileBio: {color: C.text, fontSize: F.md, lineHeight: 21},
                 profileMetaRow: {
                     flexDirection: "row",
                     alignItems: "center",
                     gap: S.xs
                 },
                 statsRow: {flexDirection: "row", gap: S.xl},
                 statText: {color: C.text, fontSize: F.sm, fontWeight: "bold"},
                 statMuted: {color: C.muted, fontSize: F.sm},
                 outlineBtn: {
                     borderWidth: 1,
                     borderColor: C.border,
                     borderRadius: R.pill,
                     paddingVertical: S.xs,
                     paddingHorizontal: S.lg,
                     flexDirection: "row",
                     alignItems: "center",
                     gap: S.xs
                 },
                 outlineLabel: {color: C.text, fontSize: F.sm, fontWeight: "bold"},
                 # empty / section
                 sectionLabel: {
                     color: C.muted,
                     fontSize: F.sm,
                     fontWeight: "bold",
                     paddingHorizontal: S.lg,
                     paddingTop: S.lg
                 },
                 empty: {padding: S.huge, alignItems: "center", gap: S.sm},
                 emptyTitle: {color: C.text, fontSize: F.md, fontWeight: "bold"},
                 emptyText: {color: C.muted, fontSize: F.sm, textAlign: "center"}
             }
         );
}
