// `@jac/runtime` of a hermes space: stdjac's, and the form a caller signs in by,
// drawn with React Native's own views. A page's `sign_in()` asks the app's auth
// what signing in takes (session.js) and hands it here.
import React from "react";
import { AppRegistry, Keyboard, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { __showSignIn } from "./session.js";
export * from "./session.js";

// The form being asked for now, and who redraws when it changes.
let asked = null;
const watchers = new Set();
function show(next) {
    asked = next;
    for (const redraw of watchers) redraw();
}

// A way of signing in that leaves for a page has no way back to a phone's app,
// so it is not offered here: the form has the ways that answer in place.
__showSignIn((asks, answer) => {
    const actions = asks.actions.filter((a) => !a.redirect);
    if (actions.length === 0) return null;
    return new Promise((resolve) => {
        show({ fields: asks.fields, actions, answer, done: (ok) => { show(null); resolve(ok); } });
    });
});

const h = React.createElement;

function SignInForm({ fields, actions, answer, done }) {
    const [given, setGiven] = React.useState({});
    const [error, setError] = React.useState("");
    const [busy, setBusy] = React.useState(false);
    // The keyboard covers the foot of the screen and moves nothing: the form
    // keeps to what is left above it, and scrolls where that is too little.
    const [covered, setCovered] = React.useState(0);
    React.useEffect(() => {
        const up = Keyboard.addListener("keyboardDidShow", (e) => setCovered(e.endCoordinates.height));
        const down = Keyboard.addListener("keyboardDidHide", () => setCovered(0));
        return () => { up.remove(); down.remove(); };
    }, []);
    const run = async (action) => {
        if (busy) return;
        const sent = {};
        for (const name of action.needs) sent[name] = given[name] || "";
        setBusy(true);
        const said = await answer(action, sent);
        setBusy(false);
        if (said.ok) done(true);
        else setError(said.detail);
    };
    const rows = fields.map((f) => h(View, { key: f.name, style: styles.field },
        h(Text, { style: styles.label }, f.label || f.name),
        h(TextInput, {
            style: styles.input,
            value: given[f.name] || "",
            secureTextEntry: !!f.secret,
            autoCapitalize: "none",
            autoCorrect: false,
            accessibilityLabel: f.label || f.name,
            onChangeText: (text) => setGiven({ ...given, [f.name]: text }),
        }),
        f.choices.length > 0
            ? h(View, { style: styles.choices }, f.choices.map((c) => h(Pressable, {
                key: c, style: styles.choice, accessibilityRole: "button",
                onPress: () => setGiven({ ...given, [f.name]: c }),
            }, h(Text, null, c))))
            : null));
    const buttons = [
        h(Pressable, { key: "", style: styles.button, accessibilityRole: "button", onPress: () => done(false) },
            h(Text, { style: styles.buttonText }, "Cancel")),
        ...actions.map((a, k) => h(Pressable, {
            key: a.name, style: [styles.button, k === 0 ? styles.first : null], accessibilityRole: "button",
            disabled: busy, onPress: () => run(a),
        }, h(Text, { style: [styles.buttonText, k === 0 ? styles.firstText : null] }, a.label || a.name))),
    ];
    return h(Modal, { transparent: true, visible: true, animationType: "fade", onRequestClose: () => done(false) },
        h(View, { style: [styles.back, { paddingBottom: covered }] },
            h(ScrollView, {
                style: styles.sheet, contentContainerStyle: styles.form,
                keyboardShouldPersistTaps: "handled", accessibilityViewIsModal: true,
            },
                ...rows,
                h(Text, { style: styles.error, accessibilityRole: "alert" }, error),
                h(View, { style: styles.actions }, buttons))));
}

// What every app of the space is drawn inside: the app, and over it the form
// while one is asked for.
function SignInHost({ children }) {
    const [, redraw] = React.useReducer((n) => n + 1, 0);
    React.useEffect(() => {
        watchers.add(redraw);
        return () => { watchers.delete(redraw); };
    }, []);
    return h(React.Fragment, null, children, asked ? h(SignInForm, asked) : null);
}

AppRegistry.setWrapperComponentProvider(() => SignInHost);

const styles = StyleSheet.create({
    back: { flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: "rgba(0,0,0,0.45)" },
    sheet: { flexGrow: 0, width: "86%", maxWidth: 420, borderRadius: 12, backgroundColor: "#fff" },
    form: { padding: 20, gap: 12 },
    field: { gap: 4 },
    label: { fontSize: 14, color: "#333" },
    input: { fontSize: 16, padding: 10, borderWidth: 1, borderColor: "#bbb", borderRadius: 6, color: "#111" },
    choices: { flexDirection: "row", flexWrap: "wrap", gap: 6 },
    choice: { paddingVertical: 4, paddingHorizontal: 10, borderRadius: 12, backgroundColor: "#eee" },
    error: { minHeight: 20, color: "#b00020" },
    actions: { flexDirection: "row", flexWrap: "wrap", justifyContent: "flex-end", gap: 8 },
    button: { paddingVertical: 10, paddingHorizontal: 16, borderRadius: 6, backgroundColor: "#eee" },
    buttonText: { fontSize: 16, color: "#111" },
    first: { backgroundColor: "#1a73e8" },
    firstText: { color: "#fff" },
});
