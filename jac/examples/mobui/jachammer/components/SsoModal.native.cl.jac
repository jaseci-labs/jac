"""In-app WebView for jac cloud social sign-in (Google / GitHub).

jac cloud only honours a *loopback* client_callback, so a mobile deep link is
rejected — the token instead lands on the configured web callback. We load the
SSO URL in a WebView and intercept that `…?token=<JWT>` redirect before it
renders, hand the JWT to the store, and dismiss. (Google may refuse to run its
consent screen inside a WebView; that's a provider policy, not our bug.)
"""

cl {
    import from "@jac/mobui" { View, Text, Pressable, Platform }
    import from 'react-native-webview' { WebView }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }

    def:pub SsoModal -> JsxElement {
        s = useStudio();
        C = s["C"];
        url = s["ssoUrl"];
        if url == "" {
            return <View/>;
        }
        top = 54 if Platform.OS == "ios" else 26;
        return
            <View style={{position: "absolute", top: 0, left: 0, right: 0, bottom: 0, backgroundColor: C.bg, zIndex: 200}}>
                <View
                    style={{
                        paddingTop: top,
                        paddingBottom: 12,
                        paddingHorizontal: 16,
                        flexDirection: "row",
                        alignItems: "center",
                        justifyContent: "space-between",
                        borderBottomWidth: 1,
                        borderBottomColor: C.border,
                        backgroundColor: C.surface
                    }}
                >
                    <Text style={{color: C.text, fontSize: 16, fontWeight: "700"}}>{"Sign in with " + s["ssoProvider"]}</Text>
                    <Pressable onPress={lambda { s["closeSso"](); }} hitSlop={12}>
                        <Icon name="close" size={22} color={C.muted} fill={False} width={2}/>
                    </Pressable>
                </View>
                <WebView
                    source={{uri: url}}
                    style={{flex: 1, backgroundColor: C.bg}}
                    startInLoadingState={True}
                    originWhitelist={["*"]}
                    userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
                    onShouldStartLoadWithRequest={lambda(req: any) { return s["onSsoNav"](req.url); }}
                    onNavigationStateChange={lambda(st: any) { s["onSsoNav"](st.url); }}
                />
            </View>;
    }
}
