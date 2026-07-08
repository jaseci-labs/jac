"""Native preview — the generated web app running in the sandbox, embedded in a
WebView. (The web build uses PreviewFrame.cl.jac instead.)
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
            />;
    }
}
