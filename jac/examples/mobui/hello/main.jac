"""mobUI primitives demo — one source, two platforms.

Exercises every @jac/mobui primitive (View, Text, Pressable, TextInput, Image,
ScrollView) plus StyleSheet.create. There is no div/span/button here on
purpose — mobUI apps import portable primitives from @jac/mobui and never touch
raw HTML tags. The bundler aliases @jac/mobui to the compiled client_mobui.js and
(on web only) rewrites react-native -> react-native-web.

    jac start main.jac                       # web   -> View=<div>, Text=<span> (via react-native-web)
    jac start main.jac --client react-native # native -> real RN components
"""

import from "@jac/mobui" {
    View,
    Text,
    Pressable,
    TextInput,
    Image,
    ScrollView,
    StyleSheet
}

# NOTE: ``Animated`` (entrance fades via ``createAnimatedValue``) lives in
# ``client_mobui.shims.js`` but is not yet surfaced through the core
# ``@jac/mobui`` module surface, so the Animated entrance is omitted here.
glob color = {
         bg: "#1e1e2f",
         surface: "#2a2a40",
         text: "#ffffff",
         muted: "#c9c9e0",
         accent: "#6c5ce7",
         field: "#ffffff"
     },
     space = {xs: 4, sm: 8, md: 12, lg: 16, xl: 24},
     radius = {md: 8, pill: 12, round: 32},
     size = {sm: 14, md: 18, lg: 22},
     weight = {semibold: "600", bold: "bold"},
     styles = StyleSheet.create(
         {
             screen: {flex: 1, backgroundColor: color.bg},
             content: {padding: space.xl, gap: space.lg},
             title: {fontSize: size.lg, fontWeight: weight.bold, color: color.text},
             card: {
                 padding: space.lg,
                 borderRadius: radius.pill,
                 backgroundColor: color.surface,
                 gap: space.sm
             },
             label: {fontSize: size.sm, color: color.muted},
             value: {fontSize: size.md, fontWeight: weight.semibold, color: color.text},
             input: {
                 padding: space.md,
                 borderRadius: radius.md,
                 backgroundColor: color.field,
                 color: color.bg
             },
             button: {
                 padding: space.md,
                 borderRadius: radius.md,
                 backgroundColor: color.accent,
                 alignItems: "center"
             },
             buttonLabel: {color: color.text, fontWeight: weight.bold},
             avatar: {width: 64, height: 64, borderRadius: radius.round}
         }
     );

def:pub app -> JsxElement {
    has count: int = 0,
        name: str = "";

    return
        <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
            <View style={styles.card}>
                <Text style={styles.title}>mobUI primitives</Text>
            </View>
            <View style={styles.card}>
                <Text style={styles.label}>Image</Text>
                <Image
                    source={{uri: "https://reactnative.dev/img/tiny_logo.png"}}
                    style={styles.avatar}
                />
            </View>
            <View style={styles.card}>
                <Text style={styles.label}>Pressable + state</Text>
                <Text style={styles.value}>Count: {count}</Text>
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
                    onChangeText={lambda (t: str) { name = t; }}
                />
                <Text style={styles.value}>Hello, {name}</Text>
            </View>
        </ScrollView>;
}
