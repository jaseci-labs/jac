"""Design tokens and the StyleSheet for {{name}}.

Tokens are `obj` types instantiated once into typed globals, so `C.accent`,
`S.lg`, `R.pill` and `F.md` are attribute reads the compiler checks. Re-skin
the whole app by editing the defaults below. `styles` is a React Native
StyleSheet: the same objects work on the web (react-native-web) and on native.
"""

import from "@jac/mobui" { StyleSheet }

obj Palette {
    has bg: str = "#0b0d12",
        surface: str = "#141826",
        border: str = "#232a3d",
        field: str = "#181d2e",
        text: str = "#e6e9ef",
        muted: str = "#8a93a6",
        accent: str = "#7c5cff",
        onAccent: str = "#ffffff",
        danger: str = "#f4544e";
}

obj Spacing {
    has xs: int = 4,
        sm: int = 8,
        md: int = 12,
        lg: int = 16,
        xl: int = 24;
}

obj Radius {
    has sm: int = 8,
        md: int = 12,
        lg: int = 16,
        pill: int = 999;
}

obj FontSize {
    has sm: int = 14,
        md: int = 16,
        lg: int = 20,
        xl: int = 28;
}

glob:pub C: Palette = Palette(),
     S: Spacing = Spacing(),
     R: Radius = Radius(),
     F: FontSize = FontSize();

glob:pub styles = StyleSheet.create(
         {
             screen: {flex: 1, backgroundColor: C.bg},
             content: {
                 width: "100%",
                 maxWidth: 560,
                 alignSelf: "center",
                 padding: S.lg,
                 gap: S.lg
             },
             header: {gap: S.xs, paddingTop: S.xl},
             titleRow: {flexDirection: "row", alignItems: "center", gap: S.sm},
             title: {color: C.text, fontSize: F.xl, fontWeight: "bold"},
             subtitle: {color: C.muted, fontSize: F.sm},
             composer: {flexDirection: "row", alignItems: "center", gap: S.sm},
             input: {
                 flex: 1,
                 color: C.text,
                 fontSize: F.md,
                 backgroundColor: C.field,
                 borderWidth: 1,
                 borderColor: C.border,
                 borderRadius: R.md,
                 paddingVertical: S.md,
                 paddingHorizontal: S.lg
             },
             list: {gap: S.sm},
             row: {
                 flexDirection: "row",
                 alignItems: "center",
                 gap: S.md,
                 backgroundColor: C.surface,
                 borderWidth: 1,
                 borderColor: C.border,
                 borderRadius: R.lg,
                 paddingVertical: S.md,
                 paddingHorizontal: S.lg
             },
             rowText: {flex: 1, color: C.text, fontSize: F.md},
             empty: {alignItems: "center", gap: S.sm, paddingVertical: S.xl},
             emptyText: {color: C.muted, fontSize: F.sm, textAlign: "center"}
         }
     );
