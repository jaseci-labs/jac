import from "@jac/mobui" { StyleSheet }
import from core.brand.tokens { Colors, spacing, radii, fonts, font_family }

def:pub makeStyles(C: Colors) -> any {
    S = spacing();
    R = radii();
    F = fonts();
    FONT = font_family();
    return StyleSheet.create(
        {
            "root": {"flex": 1, "backgroundColor": C.bg},
            "page": {
                "flex": 1,
                "width": "100%",
                "maxWidth": 640,
                "alignSelf": "center"
            },
            "center": {
                "flex": 1,
                "backgroundColor": C.bg,
                "alignItems": "center",
                "justifyContent": "center"
            },
            "body": {"flex": 1},
            "scrollBody": {"paddingBottom": S.huge},
            "rowGap": {"flexDirection": "row", "alignItems": "center", "gap": S.sm},
            "header": {
                "flexDirection": "row",
                "alignItems": "center",
                "justifyContent": "space-between",
                "gap": S.md,
                "paddingVertical": S.md,
                "paddingHorizontal": S.lg,
                "borderBottomWidth": 1,
                "borderBottomColor": C.border
            },
            "headerBrand": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.sm
            },
            "headerLogo": {
                "width": 30,
                "height": 30,
                "borderRadius": R.pill,
                "backgroundColor": C.accent,
                "alignItems": "center",
                "justifyContent": "center"
            },
            "headerTitle": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.lg,
                "fontWeight": "bold"
            },
            "headerHandle": {
                "color": C.muted,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "flexShrink": 1
            },
            "tabBar": {
                "flexDirection": "row",
                "borderTopWidth": 1,
                "borderTopColor": C.border,
                "backgroundColor": C.bg,
                "paddingVertical": S.sm
            },
            "tabItem": {
                "flex": 1,
                "alignItems": "center",
                "justifyContent": "center",
                "paddingVertical": S.xs,
                "gap": 2
            },
            "tabLabel": {"color": C.muted, "fontFamily": FONT, "fontSize": 11},
            "tabLabelActive": {
                "color": C.accent,
                "fontFamily": FONT,
                "fontSize": 11,
                "fontWeight": "bold"
            },
            "authWrap": {
                "flexGrow": 1,
                "width": "100%",
                "maxWidth": 400,
                "alignSelf": "center",
                "padding": S.xl,
                "justifyContent": "center",
                "gap": S.lg
            },
            "brandMark": {
                "width": 64,
                "height": 64,
                "borderRadius": R.xl,
                "backgroundColor": C.accent,
                "alignItems": "center",
                "justifyContent": "center",
                "alignSelf": "center"
            },
            "authTitle": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.xl,
                "fontWeight": "bold",
                "textAlign": "center"
            },
            "authSub": {
                "color": C.muted,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "textAlign": "center",
                "marginTop": 0 - S.sm
            },
            "errorBox": {
                "backgroundColor": C.dangerSoft,
                "borderRadius": R.md,
                "paddingVertical": S.sm,
                "paddingHorizontal": S.md
            },
            "errorText": {
                "color": C.danger,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "textAlign": "center"
            },
            "fieldRow": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.sm,
                "borderWidth": 1,
                "borderColor": C.border,
                "borderRadius": R.md,
                "backgroundColor": C.field,
                "paddingHorizontal": S.md
            },
            "fieldInput": {
                "flex": 1,
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.md,
                "paddingVertical": S.md
            },
            "primaryBtn": {
                "backgroundColor": C.accent,
                "borderRadius": R.pill,
                "paddingVertical": S.md,
                "alignItems": "center",
                "justifyContent": "center",
                "minHeight": 46
            },
            "primaryLabel": {
                "color": C.accentText,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "fontWeight": "bold"
            },
            "pillBtn": {
                "flexDirection": "row",
                "alignItems": "center",
                "justifyContent": "center",
                "gap": S.xs,
                "backgroundColor": C.accent,
                "borderRadius": R.pill,
                "paddingVertical": S.sm,
                "paddingHorizontal": S.lg,
                "minHeight": 36
            },
            "btnDisabled": {"opacity": 0.45},
            "outlineBtn": {
                "flexDirection": "row",
                "alignItems": "center",
                "justifyContent": "center",
                "gap": S.xs,
                "borderWidth": 1,
                "borderColor": C.border,
                "borderRadius": R.pill,
                "paddingVertical": S.sm,
                "paddingHorizontal": S.lg,
                "minHeight": 36
            },
            "outlineLabel": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "fontWeight": "bold"
            },
            "ghostBtn": {
                "borderRadius": R.pill,
                "paddingVertical": S.sm,
                "paddingHorizontal": S.md,
                "alignItems": "center",
                "justifyContent": "center"
            },
            "ghostLabel": {
                "color": C.muted,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "fontWeight": "bold"
            },
            "dangerBtn": {
                "backgroundColor": C.danger,
                "borderRadius": R.pill,
                "paddingVertical": S.sm,
                "paddingHorizontal": S.md,
                "alignItems": "center",
                "justifyContent": "center"
            },
            "dangerLabel": {
                "color": C.accentText,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "fontWeight": "bold"
            },
            "switchRow": {
                "flexDirection": "row",
                "justifyContent": "center",
                "alignItems": "center",
                "gap": S.xs
            },
            "switchText": {"color": C.muted, "fontFamily": FONT, "fontSize": F.sm},
            "switchLink": {
                "color": C.accent,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "fontWeight": "bold"
            },
            "footnote": {
                "color": C.muted,
                "fontFamily": FONT,
                "fontSize": F.xs,
                "textAlign": "center"
            },
            "banner": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.sm,
                "backgroundColor": C.dangerSoft,
                "borderBottomWidth": 1,
                "borderBottomColor": C.border,
                "paddingVertical": S.sm,
                "paddingHorizontal": S.lg
            },
            "bannerText": {
                "flex": 1,
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.xs
            },
            "bannerAction": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.xs,
                "borderWidth": 1,
                "borderColor": C.border,
                "borderRadius": R.pill,
                "paddingVertical": S.xs,
                "paddingHorizontal": S.sm
            },
            "bannerActionLabel": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.xs,
                "fontWeight": "bold"
            },
            "bannerClose": {"padding": S.xs},
            "composer": {
                "flexDirection": "row",
                "gap": S.md,
                "paddingVertical": S.md,
                "paddingHorizontal": S.lg,
                "borderBottomWidth": 1,
                "borderBottomColor": C.border
            },
            "composerCol": {"flex": 1, "gap": S.sm},
            "composerInput": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.md,
                "paddingVertical": S.sm,
                "minHeight": 48,
                "textAlignVertical": "top"
            },
            "composerFooter": {
                "flexDirection": "row",
                "justifyContent": "flex-end",
                "alignItems": "center",
                "gap": S.md
            },
            "counter": {"color": C.muted, "fontFamily": FONT, "fontSize": F.xs},
            "counterWarn": {
                "color": C.danger,
                "fontFamily": FONT,
                "fontSize": F.xs,
                "fontWeight": "bold"
            },
            "searchBar": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.sm,
                "marginHorizontal": S.lg,
                "marginVertical": S.md,
                "borderRadius": R.pill,
                "backgroundColor": C.field,
                "paddingHorizontal": S.md
            },
            "searchInput": {
                "flex": 1,
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "paddingVertical": S.sm
            },
            "card": {
                "flexDirection": "row",
                "gap": S.md,
                "paddingVertical": S.md,
                "paddingHorizontal": S.lg,
                "borderBottomWidth": 1,
                "borderBottomColor": C.border
            },
            "avatar": {"backgroundColor": C.elevated},
            "cardBody": {"flex": 1, "gap": S.xs},
            "cardHead": {"flexDirection": "row", "alignItems": "center", "gap": S.xs},
            "name": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "fontWeight": "bold",
                "flexShrink": 1
            },
            "handle": {
                "color": C.muted,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "flexShrink": 1
            },
            "cardText": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.md,
                "lineHeight": 22
            },
            "actions": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.xl,
                "marginTop": S.xs
            },
            "action": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.xs,
                "paddingVertical": S.xs
            },
            "actionCount": {"color": C.muted, "fontFamily": FONT, "fontSize": F.xs},
            "actionCountLiked": {
                "color": C.like,
                "fontFamily": FONT,
                "fontSize": F.xs,
                "fontWeight": "bold"
            },
            "confirmRow": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.sm,
                "marginTop": S.sm,
                "backgroundColor": C.dangerSoft,
                "borderRadius": R.md,
                "paddingVertical": S.xs,
                "paddingHorizontal": S.md
            },
            "confirmText": {
                "flex": 1,
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.sm
            },
            "commentList": {
                "marginTop": S.sm,
                "borderTopWidth": 1,
                "borderTopColor": C.border,
                "paddingTop": S.sm,
                "gap": S.sm
            },
            "commentRow": {
                "flexDirection": "row",
                "alignItems": "flex-start",
                "gap": S.sm
            },
            "commentBubble": {
                "flex": 1,
                "backgroundColor": C.surface,
                "borderRadius": R.lg,
                "borderTopLeftRadius": R.sm,
                "paddingVertical": S.sm,
                "paddingHorizontal": S.md,
                "gap": 2
            },
            "commentName": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.xs,
                "fontWeight": "bold"
            },
            "commentText": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "lineHeight": 20
            },
            "commentComposer": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.sm
            },
            "commentInput": {
                "flex": 1,
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "backgroundColor": C.field,
                "borderRadius": R.pill,
                "paddingVertical": S.sm,
                "paddingHorizontal": S.lg
            },
            "sendBtn": {
                "width": 38,
                "height": 38,
                "borderRadius": R.pill,
                "backgroundColor": C.accent,
                "alignItems": "center",
                "justifyContent": "center"
            },
            "empty": {"padding": S.huge, "alignItems": "center", "gap": S.sm},
            "emptyTitle": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.md,
                "fontWeight": "bold"
            },
            "emptyText": {
                "color": C.muted,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "textAlign": "center"
            },
            "skeletonList": {"padding": S.lg, "gap": S.lg},
            "skeletonRow": {"flexDirection": "row", "gap": S.md},
            "skeletonAvatar": {
                "width": 42,
                "height": 42,
                "borderRadius": R.pill,
                "backgroundColor": C.elevated
            },
            "skeletonBody": {"flex": 1, "gap": S.sm, "paddingTop": S.xs},
            "skeletonLine": {
                "height": 10,
                "width": "100%",
                "borderRadius": R.sm,
                "backgroundColor": C.elevated
            },
            "sectionLabel": {
                "color": C.muted,
                "fontFamily": FONT,
                "fontSize": F.xs,
                "fontWeight": "bold",
                "letterSpacing": 1,
                "textTransform": "uppercase",
                "paddingHorizontal": S.lg,
                "paddingTop": S.lg,
                "paddingBottom": S.sm
            },
            "sectionHint": {
                "color": C.muted,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "paddingHorizontal": S.lg
            },
            "chipRow": {
                "flexDirection": "row",
                "flexWrap": "wrap",
                "gap": S.sm,
                "paddingHorizontal": S.lg
            },
            "chip": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.xs,
                "backgroundColor": C.accentSoft,
                "borderRadius": R.pill,
                "paddingVertical": S.xs,
                "paddingHorizontal": S.md
            },
            "chipText": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "fontWeight": "bold"
            },
            "chipCount": {"color": C.muted, "fontFamily": FONT, "fontSize": F.xs},
            "personRow": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.md,
                "paddingVertical": S.md,
                "paddingHorizontal": S.lg,
                "borderBottomWidth": 1,
                "borderBottomColor": C.border
            },
            "personBody": {"flex": 1, "gap": 2},
            "personBio": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "opacity": 0.8
            },
            "createRow": {
                "flexDirection": "row",
                "alignItems": "center",
                "justifyContent": "center",
                "gap": S.sm,
                "backgroundColor": C.accent,
                "borderRadius": R.md,
                "marginHorizontal": S.lg,
                "marginVertical": S.md,
                "paddingVertical": S.md
            },
            "channelRow": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.md,
                "marginHorizontal": S.lg,
                "marginBottom": S.md,
                "borderWidth": 1,
                "borderColor": C.border,
                "borderRadius": R.lg,
                "backgroundColor": C.surface,
                "padding": S.lg
            },
            "channelRowInner": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.md
            },
            "channelIcon": {
                "width": 44,
                "height": 44,
                "borderRadius": R.md,
                "backgroundColor": C.accentSoft,
                "alignItems": "center",
                "justifyContent": "center"
            },
            "channelBody": {"flex": 1, "gap": 2},
            "channelName": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.md,
                "fontWeight": "bold"
            },
            "channelDesc": {"color": C.muted, "fontFamily": FONT, "fontSize": F.sm},
            "channelMeta": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.xs
            },
            "channelMetaText": {"color": C.muted, "fontFamily": FONT, "fontSize": F.xs},
            "badge": {
                "backgroundColor": C.elevated,
                "borderRadius": R.pill,
                "paddingVertical": S.xs,
                "paddingHorizontal": S.sm
            },
            "badgeText": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.xs,
                "fontWeight": "bold"
            },
            "detailHead": {
                "padding": S.lg,
                "gap": S.md,
                "borderBottomWidth": 1,
                "borderBottomColor": C.border
            },
            "backBtn": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S.xs,
                "alignSelf": "flex-start"
            },
            "backLabel": {"color": C.muted, "fontFamily": FONT, "fontSize": F.sm},
            "modalOverlay": {
                "flex": 1,
                "backgroundColor": C.scrim,
                "alignItems": "center",
                "justifyContent": "flex-end"
            },
            "modalCard": {
                "width": "100%",
                "maxWidth": 640,
                "backgroundColor": C.bg,
                "borderTopLeftRadius": R.xl,
                "borderTopRightRadius": R.xl,
                "borderWidth": 1,
                "borderColor": C.border,
                "padding": S.xl,
                "gap": S.md
            },
            "modalTitle": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.lg,
                "fontWeight": "bold"
            },
            "modalSub": {
                "color": C.muted,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "marginTop": 0 - S.sm
            },
            "modalInput": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.md,
                "backgroundColor": C.field,
                "borderWidth": 1,
                "borderColor": C.border,
                "borderRadius": R.md,
                "paddingVertical": S.md,
                "paddingHorizontal": S.md
            },
            "modalArea": {"minHeight": 72, "textAlignVertical": "top"},
            "modalFooter": {
                "flexDirection": "row",
                "justifyContent": "flex-end",
                "alignItems": "center",
                "gap": S.sm,
                "marginTop": S.xs
            },
            "profileHero": {"height": 110, "backgroundColor": C.accentSoft},
            "profileHead": {
                "paddingHorizontal": S.lg,
                "paddingBottom": S.lg,
                "gap": S.sm,
                "borderBottomWidth": 1,
                "borderBottomColor": C.border
            },
            "profileTopRow": {
                "flexDirection": "row",
                "justifyContent": "space-between",
                "alignItems": "flex-end",
                "marginTop": 0 - 38
            },
            "profileName": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.xl,
                "fontWeight": "bold",
                "marginTop": S.sm
            },
            "profileHandle": {
                "color": C.muted,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "marginTop": 0 - S.sm
            },
            "profileBio": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.md,
                "lineHeight": 22
            },
            "editBox": {"gap": S.sm},
            "bioInput": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.md,
                "backgroundColor": C.field,
                "borderWidth": 1,
                "borderColor": C.border,
                "borderRadius": R.md,
                "padding": S.md,
                "minHeight": 80,
                "textAlignVertical": "top"
            },
            "statsRow": {"flexDirection": "row", "gap": S.xl, "marginTop": S.xs},
            "stat": {"color": C.muted, "fontFamily": FONT, "fontSize": F.sm},
            "statNum": {
                "color": C.text,
                "fontFamily": FONT,
                "fontSize": F.sm,
                "fontWeight": "bold"
            }
        }
    );
}
