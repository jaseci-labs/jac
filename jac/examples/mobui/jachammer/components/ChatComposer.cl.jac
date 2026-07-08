"""Chat message composer. Keeps the draft in LOCAL component state so typing
re-renders only this small component — not the whole DetailScreen. It also
lifts itself above the keyboard with a manual keyboard-height listener (a plain
`KeyboardAvoidingView` doesn't lift a flex-bottom composer reliably on iOS).
On send it hands the text to the store's `sendChat` action.
"""

cl {
    import from "@jac/mobui" { View, Pressable, TextInput, Keyboard, Platform }
    import from react { useEffect }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }
    import from .ModelChip { ModelChip }

    def:pub ChatComposer -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"];
        has draft: str = "";
        has kb: int = 0;

        # Track the keyboard height and lift the composer by that much.
        useEffect(lambda {
            showEvt = "keyboardWillShow" if Platform.OS == "ios" else "keyboardDidShow";
            hideEvt = "keyboardWillHide" if Platform.OS == "ios" else "keyboardDidHide";
            sub1 = Keyboard.addListener(showEvt, lambda(e: any) { kb = e.endCoordinates.height; });
            sub2 = Keyboard.addListener(hideEvt, lambda(e: any) { kb = 0; });
            return lambda {
                sub1.remove();
                sub2.remove();
            };
        }, []);

        def send -> None {
            t = draft;
            console.log("[jh] ChatComposer.send draft=", t);
            draft = "";
            s["sendChat"](t);
        }

        return
            <View style={[styles.chatComposer, {marginBottom: kb}]}>
                <ModelChip/>
                <TextInput
                    style={styles.chatInput}
                    value={draft}
                    placeholder="Describe a change…"
                    placeholderTextColor={C.muted}
                    multiline={True}
                    onChangeText={lambda v: str { draft = v; }}
                />
                <Pressable style={styles.sendFab} onPress={send}>
                    <Icon name="send" size={18} color={C.accentText} fill={False} width={2}/>
                </Pressable>
            </View>;
    }
}
