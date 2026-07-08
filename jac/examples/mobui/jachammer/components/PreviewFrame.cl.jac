"""Web preview fallback — on the web build there's no WebView, so just offer to
open the running sandbox in a new tab. (Native uses PreviewFrame.native.cl.jac.)
"""

cl {
    import from "@jac/mobui" { View, Text, Pressable }
    import from "react-native" { Linking }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }

    def:pub PreviewFrame(url: str) -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"];
        return
            <View style={{flex: 1, alignItems: "center", justifyContent: "center", gap: 12, padding: 24}}>
                <Icon name="phone" size={30} color={C.muted} fill={False} width={1.6}/>
                <Text style={styles.emptyText}>Open the running preview in a browser tab.</Text>
                <Pressable style={styles.outlineBtn} onPress={lambda { Linking.openURL(url); }}>
                    <Icon name="server" size={16} color={C.text} fill={False} width={2}/>
                    <Text style={styles.outlineLabel}>Open preview</Text>
                </Pressable>
            </View>;
    }
}
