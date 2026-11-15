impl AuthScreen(
    isSignup: bool,
    username: str,
    password: str,
    error: str,
    loading: bool,
    onUsernameChange: Callable[[str], None],
    onPasswordChange: Callable[[str], None],
    email: str = "",
    onEmailChange: Callable[[str], None] = lambda (t: str) {},
    onSubmit: Callable[[], None],
    onToggleMode: Callable[[], None],
    githubEnabled: bool = False,
    onGithub: Callable[[], None] = lambda {},
    embedded: bool = False,
) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    viewport = useWindowDimensions();
    can_submit = username.strip() != ""
        and password != ""
        and (not isSignup or email.strip() != "")
        and not loading;

    <KeyboardAvoidingView
        style={[
            styles.root,
            {
                "height": "100%" if embedded else viewport.height,
                "paddingTop": 24 if embedded else 0
            }
        ]}
        behavior={"padding" if Platform.OS == "ios" else "height"}
    >
        <StatusBar
            barStyle={"light-content" if theme.dark else "dark-content"}
            backgroundColor={C.bg}
        />
        <ScrollView
            style={styles.body}
            contentContainerStyle={styles.authWrap}
            keyboardShouldPersistTaps="handled"
        >
            <View style={{"alignItems": "center"}}>
                <BrandMark size={40}/>
            </View>
            <Text style={styles.authTitle}>
                {"Create your account" if isSignup else "Welcome back"}
            </Text>
            <Text style={styles.authSub}>
                {"Join the conversation on JacYac"
                    if isSignup
                    else "Sign in to your JacYac account"}
            </Text>
            {if error {
                <View style={styles.errorBox}>
                    <Text style={styles.errorText}>{error}</Text>
                </View>
            }}
            {if githubEnabled {
                <Pressable
                    accessibilityRole="button"
                    style={styles.outlineBtn}
                    disabled={loading}
                    onPress={onGithub}
                >
                    <Text style={styles.outlineLabel}>Continue with GitHub</Text>
                </Pressable>
            }}
            <View style={styles.fieldRow}>
                <Icon name="at" size={18} color={C.muted}/>
                <TextInput
                    style={styles.fieldInput}
                    value={username}
                    placeholder={"Username" if isSignup else "Username or email"}
                    placeholderTextColor={C.muted}
                    autoCapitalize="none"
                    autoCorrect={False}
                    onChangeText={onUsernameChange}
                />
            </View>
            {if isSignup {
                <View style={styles.fieldRow}>
                    <Icon name="mail" size={18} color={C.muted}/>
                    <TextInput
                        style={styles.fieldInput}
                        value={email}
                        placeholder="Email"
                        placeholderTextColor={C.muted}
                        autoCapitalize="none"
                        autoCorrect={False}
                        keyboardType="email-address"
                        onChangeText={onEmailChange}
                    />
                </View>
            }}
            <View style={styles.fieldRow}>
                <Icon name="lock" size={18} color={C.muted}/>
                <TextInput
                    style={styles.fieldInput}
                    value={password}
                    placeholder="Password"
                    placeholderTextColor={C.muted}
                    secureTextEntry={True}
                    onChangeText={onPasswordChange}
                    onSubmitEditing={lambda { if can_submit { onSubmit(); }}}
                />
            </View>
            <Pressable
                accessibilityRole="button"
                style={[
                    styles.primaryBtn,
                    (styles.btnDisabled if not can_submit else None)
                ]}
                disabled={not can_submit}
                onPress={lambda { onSubmit(); }}
            >
                {if loading {
                    <ActivityIndicator size="small" color={C.accentText}/>
                } else {
                    <Text style={styles.primaryLabel}>
                        {"Sign up" if isSignup else "Log in"}
                    </Text>
                } }
            </Pressable>
            <View style={styles.switchRow}>
                <Text style={styles.switchText}>
                    {"Already have an account?" if isSignup else "New to JacYac?"}
                </Text>
                <Pressable
                    accessibilityRole="button"
                    onPress={lambda { onToggleMode(); }}
                >
                    <Text style={styles.switchLink}>
                        {"Log in" if isSignup else "Sign up"}
                    </Text>
                </Pressable>
            </View>
            <Text style={styles.footnote}>
                Same accounts and the same graph as jaclang.org/jacyac.
            </Text>
        </ScrollView>
    </KeyboardAvoidingView>
}
