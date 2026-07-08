"""jachammer entry screens — animated Splash and the Auth (login/signup) form."""

cl {
    import from "@jac/mobui" { View, Text, Pressable, TextInput, Animated, KeyboardAvoidingView }
    import from ..ui.icon { Icon }
    import from ..ui.theme { S }
    import from ..hooks.useStudio { useStudio }
    import from ..components.Spinner { Spinner }
    import from ..components.Logo { Logo }

    def:pub SplashScreen -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"]; intro = s["intro"];
        return
            <View style={styles.splash}>
                <Animated.View
                    style={{
                        opacity: intro,
                        transform: [{scale: intro.interpolate({inputRange: [0, 1], outputRange: [0.85, 1]})}],
                        alignItems: "center"
                    }}
                >
                    <Logo size={96}/>
                    <View style={{height: S.lg}}/>
                    <Text style={styles.splashTitle}>jachammer</Text>
                    <Text style={styles.splashTag}>forge · deploy · ship</Text>
                </Animated.View>
            </View>;
    }

    def:pub AuthScreen -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"];
        authMode = s["authMode"]; authError = s["authError"];
        authUser = s["authUser"]; authPass = s["authPass"]; authPass2 = s["authPass2"];
        isSignup = authMode == "signup";
        return
            <KeyboardAvoidingView style={styles.kav} behavior={s["kbBehavior"]()}>
                <View style={styles.authWrap}>
                    <View style={{alignSelf: "center"}}><Logo size={60}/></View>
                    <Text style={styles.authTitle}>{("Create your account" if isSignup else "Welcome back")}</Text>
                    <Text style={styles.authSub}>Build, deploy and monitor Jac apps from your pocket.</Text>
                    <Pressable style={styles.oauthBtn} onPress={lambda { s["oauth"]("google"); }}>
                        <Icon name="spark" size={16} color={C.text} fill={False} width={2}/>
                        <Text style={styles.oauthText}>Continue with Google</Text>
                    </Pressable>
                    <Pressable style={styles.oauthBtn} onPress={lambda { s["oauth"]("github"); }}>
                        <Icon name="branch" size={16} color={C.text} fill={False} width={2}/>
                        <Text style={styles.oauthText}>Continue with GitHub</Text>
                    </Pressable>
                    <View style={styles.orRow}>
                        <View style={styles.orLine}/>
                        <Text style={styles.orText}>or</Text>
                        <View style={styles.orLine}/>
                    </View>
                    <View style={styles.fieldRow}>
                        <Icon name="at" size={18} color={C.muted} fill={False} width={2}/>
                        <TextInput
                            style={styles.fieldInput}
                            value={authUser}
                            placeholder="username"
                            placeholderTextColor={C.muted}
                            autoCapitalize="none"
                            onChangeText={lambda v: str { s["setAuthUser"](v); }}
                        />
                    </View>
                    <View style={styles.fieldRow}>
                        <Icon name="lock" size={18} color={C.muted} fill={False} width={2}/>
                        <TextInput
                            style={styles.fieldInput}
                            value={authPass}
                            placeholder="password"
                            placeholderTextColor={C.muted}
                            secureTextEntry={True}
                            onChangeText={lambda v: str { s["setAuthPass"](v); }}
                        />
                    </View>
                    {(
                        <View style={styles.fieldRow}>
                            <Icon name="lock" size={18} color={C.muted} fill={False} width={2}/>
                            <TextInput
                                style={styles.fieldInput}
                                value={authPass2}
                                placeholder="confirm password"
                                placeholderTextColor={C.muted}
                                secureTextEntry={True}
                                onChangeText={lambda v: str { s["setAuthPass2"](v); }}
                            />
                        </View>
                    )
                        if isSignup
                        else <View/>}
                    {(<Text style={styles.errorText}>{authError}</Text>) if (authError != "") else <View/>}
                    <Pressable style={styles.primaryBtn} onPress={s["submitAuth"]} disabled={s["isBusy"]("auth")}>
                        {(<Spinner color={C.accentText}/>)
                            if s["isBusy"]("auth")
                            else (<Text style={styles.primaryLabel}>{("Sign up" if isSignup else "Log in")}</Text>)}
                    </Pressable>
                    <View style={styles.switchRow}>
                        <Text style={styles.switchText}>
                            {("Already have an account?" if isSignup else "New to jachammer?")}
                        </Text>
                        <Pressable onPress={lambda { s["setAuthMode"]("login" if isSignup else "signup"); s["setAuthError"](""); }}>
                            <Text style={styles.switchLink}>{("Log in" if isSignup else "Sign up")}</Text>
                        </Pressable>
                    </View>
                </View>
            </KeyboardAvoidingView>;
    }
}
