impl AuthScreen(
    error: str,
    loading: bool,
    onSignIn: Callable[[], Coroutine[any, any, None]],
    embedded: bool = False,
) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    viewport = useWindowDimensions();

    return <View
        style={[styles.root, {"height": "100%" if embedded else viewport.height, "paddingTop": 24 if embedded else 0}]}
    >
        <StatusBar
            barStyle={"light-content" if theme.dark else "dark-content"}
            backgroundColor={C.bg}
        />
        <ScrollView style={styles.body} contentContainerStyle={styles.authWrap}>
            <View style={{"alignItems": "center"}}><BrandMark size={40} /></View>
            <Text style={styles.authTitle}>Welcome to JacYac</Text>
            <Text style={styles.authSub}>Sign in to join the conversation</Text>
            {
                if error {
                    <View style={styles.errorBox}>
                        <Text style={styles.errorText}>{error}</Text>
                    </View>
                }
            }
            <Pressable
                accessibilityRole="button"
                style={[styles.primaryBtn, (styles.btnDisabled if loading else None)]}
                disabled={loading}
                onPress={lambda { onSignIn() }}
            >
                {
                    if loading {
                        <ActivityIndicator size="small" color={C.accentText} />
                    } else {
                        <Text style={styles.primaryLabel}>Sign in</Text>
                    }
                }
            </Pressable>
            <Text style={styles.footnote}>
                Same accounts and the same graph as jaclang.org/jacyac.
            </Text>
        </ScrollView>
    </View>;
}
