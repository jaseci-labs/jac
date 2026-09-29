import from "@jac/mobui" { StyleSheet }

obj Colors {
    has ink: str = "#282c28",
        muted: str = "#75796e",
        paper: str = "#f6f5ee",
        card: str = "#fffef9",
        line: str = "#dedfd3",
        accent: str = "#355d45";
}

glob:pub C = Colors(),
     S = StyleSheet.create(
         {
             "screen": {"flex": 1, "backgroundColor": C.paper},
             "page": {
                 "width": "100%",
                 "maxWidth": 1120,
                 "alignSelf": "center",
                 "padding": 24,
                 "gap": 28
             },
             "header": {
                 "flexDirection": "row",
                 "justifyContent": "space-between",
                 "alignItems": "center",
                 "paddingVertical": 12
             },
             "brand": {
                 "fontSize": 25,
                 "fontWeight": "800",
                 "color": C.ink,
                 "letterSpacing": -1
             },
             "eyebrow": {
                 "fontSize": 11,
                 "fontWeight": "700",
                 "letterSpacing": 2,
                 "color": C.accent
             },
             "title": {
                 "fontSize": 42,
                 "fontWeight": "700",
                 "letterSpacing": -2,
                 "color": C.ink
             },
             "subtitle": {"fontSize": 16, "lineHeight": 25, "color": C.muted},
             "row": {
                 "flexDirection": "row",
                 "gap": 12,
                 "alignItems": "center",
                 "flexWrap": "wrap"
             },
             "between": {
                 "flexDirection": "row",
                 "justifyContent": "space-between",
                 "alignItems": "center",
                 "gap": 12
             },
             "stack": {"gap": 16},
             "card": {
                 "backgroundColor": C.card,
                 "borderWidth": 1,
                 "borderColor": C.line,
                 "borderRadius": 18,
                 "padding": 22,
                 "gap": 16
             },
             "input": {
                 "borderWidth": 1,
                 "borderColor": C.line,
                 "borderRadius": 10,
                 "padding": 12,
                 "fontSize": 15,
                 "color": C.ink,
                 "backgroundColor": "#fff"
             },
             "composer": {"minHeight": 90, "textAlignVertical": "top"},
             "button": {
                 "backgroundColor": C.accent,
                 "paddingHorizontal": 18,
                 "paddingVertical": 11,
                 "borderRadius": 10,
                 "alignItems": "center"
             },
             "buttonText": {"color": "#fff", "fontWeight": "700", "fontSize": 14},
             "quiet": {"backgroundColor": "#ebeee5"},
             "quietText": {"color": C.accent},
             "body": {"fontSize": 16, "lineHeight": 25, "color": C.ink},
             "small": {"fontSize": 12, "color": C.muted, "lineHeight": 19},
             "name": {"fontSize": 14, "fontWeight": "700", "color": C.ink},
             "avatar": {
                 "width": 42,
                 "height": 42,
                 "borderRadius": 21,
                 "backgroundColor": "#e5eadc",
                 "justifyContent": "center",
                 "alignItems": "center"
             },
             "score": {
                 "fontSize": 56,
                 "fontWeight": "700",
                 "color": C.accent,
                 "letterSpacing": -3
             },
             "error": {
                 "padding": 14,
                 "borderRadius": 10,
                 "backgroundColor": "#fbe9e2",
                 "color": "#8c3524",
                 "fontSize": 14
             },
             "footer": {
                 "paddingVertical": 20,
                 "borderTopWidth": 1,
                 "borderTopColor": C.line
             },

         }
     );
