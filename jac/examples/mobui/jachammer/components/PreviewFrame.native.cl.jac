"""Native preview — the generated web app running in the sandbox, embedded in a
WebView. (The web build uses PreviewFrame.cl.jac instead.)

The sandbox URL is auth-gated: the store hands us the `/__auth?t=<token>&embed=1`
handshake URL, which responds with a Set-Cookie then 302-redirects into the app.
WKWebView (iOS) only persists that cookie across the redirect when
`sharedCookiesEnabled` is on — without it the sandbox re-shows its login page.
onError/onHttpError/onLoadEnd log the final resolved URL + any failure so a
still-broken preview is diagnosable from the Metro console.
"""

cl {
    import from 'react-native-webview' { WebView }

    def:pub PreviewFrame(url: str) -> JsxElement {
        return
            <WebView
                source={{uri: url}}
                style={{flex: 1}}
                startInLoadingState={True}
                originWhitelist={["*"]}
                sharedCookiesEnabled={True}
                thirdPartyCookiesEnabled={True}
                domStorageEnabled={True}
                javaScriptEnabled={True}
                onLoadEnd={lambda (e: any) { console.log(
                    "[jh] preview loaded url=",
                    (e.nativeEvent.url if (e and e.nativeEvent) else "")
                ); }}
                onError={lambda (e: any) { console.log(
                    "[jh] preview webview ERROR",
                    (e.nativeEvent.description if (e and e.nativeEvent) else "")
                ); }}
                onHttpError={lambda (e: any) { console.log(
                    "[jh] preview webview HTTP",
                    (e.nativeEvent.statusCode if (e and e.nativeEvent) else ""),
                    (e.nativeEvent.url if (e and e.nativeEvent) else "")
                ); }}
            />;
    }
}
