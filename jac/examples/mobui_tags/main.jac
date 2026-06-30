"""mobUI Tag System showcase.

A ``mobui`` project (``jac.toml``: ``client_kind = "mobui"``) is one source
tree that targets BOTH the web (via react-native-web) and React Native
(Android/iOS). Instead of HTML, it uses Jac's own ``@jac/ui`` component
vocabulary - View, Text, Pressable, TextInput, Image, ScrollView - which
projects totally to every target.

What this example shows off
---------------------------
1. The vocabulary. Every visible element below is an ``@jac/ui`` primitive.
   There is intentionally no ``<div>``, ``<span>``, ``<button>``, ``<input>``
   or ``<img>`` anywhere in this file.
2. Compile-time enforcement. In a mobUI project, raw HTML host tags are
   compile errors (E1105) with a fix-it pointing at the @jac/ui primitive to
   use instead. So a stray ``<div>`` would fail the build with a message like
   "JSX tag '<div>' is not in scope in a mobUI project; use View instead".
3. Scope-based tag resolution. Lowercase tags that resolve to an in-scope
   component are allowed (see ``<counter/>`` below); uppercase components are
   always allowed. Only *unresolved* lowercase names are treated as HTML host
   elements and rejected.

    jac check main.jac                         # 0 E1105 - the tag system is happy
    jac build main.jac                         # web bundle (via react-native-web)
    jac build main.jac --client react-native   # Android/iOS bundle

See README.md in this folder for the full tag -> @jac/ui mapping table and the
one-source-two-targets story.
"""

cl {
    import from "@jac/ui" {
        View,
        Text,
        Pressable,
        TextInput,
        Image,
        ScrollView,
        StyleSheet
    }

    # Design tokens, kept as flat scalars so attribute access stays clean.
    glob BG = "#10131c";
    glob SURFACE = "#1b2030";
    glob SURFACE_HI = "#242b40";
    glob TEXT = "#f4f5fb";
    glob MUTED = "#a6acc9";
    glob ACCENT = "#6c5ce7";
    glob ACCENT_HI = "#7f70ff";
    glob DANGER = "#e0556b";

    glob RADIUS_MD = 10;
    glob RADIUS_LG = 16;
    glob SPACE_MD = 12;
    glob SPACE_LG = 16;
    glob SPACE_XL = 24;
    glob FONT_BODY = 16;
    glob FONT_TITLE = 22;

    glob styles = StyleSheet.create(
             {
                 screen: {flex: 1, backgroundColor: BG},
                 content: {padding: SPACE_XL, gap: SPACE_LG},
                 card: {
                     padding: SPACE_LG,
                     borderRadius: RADIUS_LG,
                     backgroundColor: SURFACE,
                     gap: SPACE_MD
                 },
                 row: {flexDirection: "row", alignItems: "center", gap: SPACE_MD},
                 title: {fontSize: FONT_TITLE, fontWeight: "bold", color: TEXT},
                 label: {fontSize: FONT_BODY, color: MUTED},
                 value: {fontSize: FONT_BODY, fontWeight: "600", color: TEXT},
                 avatar: {width: 56, height: 56, borderRadius: 28},
                 input: {
                     padding: SPACE_MD,
                     borderRadius: RADIUS_MD,
                     backgroundColor: SURFACE_HI,
                     color: TEXT
                 },
                 button: {
                     padding: SPACE_MD,
                     borderRadius: RADIUS_MD,
                     backgroundColor: ACCENT,
                     alignItems: "center"
                 },
                 buttonLabel: {color: TEXT, fontWeight: "bold"}
             }
         );

    # A lowercase, in-scope component. Because ``counter`` resolves via scope
    # lookup, the mobUI guard treats it as a user component and ALLOWS it -
    # this is the scope-based half of the tag system (not a host HTML element).
    def counter(label: str, value: int) -> JsxElement {
        return
            <View style={styles.row}>
                <Text style={styles.label}>{label}</Text>
                <Text style={styles.value}>{value}</Text>
            </View>;
    }

    def:pub app -> JsxElement {
        has count: int = 0,
            name: str = "";

        return
            <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
                <Text style={styles.title}>mobUI Tag System</Text>
                <View style={styles.card}>
                    <Text style={styles.label}>Image</Text>
                    <Image
                        source={{uri: "https://reactnative.dev/img/tiny_logo.png"}}
                        style={styles.avatar}
                    />
                </View>
                <View style={styles.card}>
                    <Text style={styles.label}>Pressable + state</Text>
                    <counter label="Count" value={count}/>
                    <Pressable
                        style={styles.button}
                        onPress={lambda { count = count + 1; }}
                    >
                        <Text style={styles.buttonLabel}>Increment</Text>
                    </Pressable>
                </View>
                <View style={styles.card}>
                    <Text style={styles.label}>TextInput (controlled)</Text>
                    <TextInput
                        style={styles.input}
                        value={name}
                        placeholder="Type your name"
                        onChangeText={lambda t: str { name = t; }}
                    />
                    <Text style={styles.value}>Hello, {name or "stranger"}</Text>
                </View>
            </ScrollView>;
    }
}
