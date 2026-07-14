"""Home / Build tab — prompt composer, suggestion chips, recent projects."""

cl {
    import from "@jac/mobui" {
        View,
        Text,
        Pressable,
        TextInput,
        ScrollView,
        KeyboardAvoidingView
    }
    import from ..ui.icon { Icon }
    import from ..ui.theme { S }
    import from ..hooks.useStudio { useStudio }
    import from ..kit.constants { SUGGESTIONS }
    import from ..components.ProjectCard { ProjectCard }
    import from ..components.SuggChip { SuggChip }
    import from ..components.ModelChip { ModelChip }
    import from ..components.Spinner { Spinner }

    def:pub HomeScreen -> JsxElement {
        s = useStudio();
        C = s["C"];
        styles = s["styles"];
        projects = s["projects"];
        recents = [];
        n = 0;
        for p in projects {
            if n < 3 {
                recents = recents + [p];
                n = n + 1;
            }
        }
        return
            <KeyboardAvoidingView style={styles.kav} behavior={s["kbBehavior"]()}>
                <ScrollView
                    style={styles.scroll}
                    contentContainerStyle={styles.scrollBody}
                    keyboardShouldPersistTaps="handled"
                >
                    <Text style={styles.greeting}>What will you build?</Text>
                    <Text style={styles.greetingSub}>
                        Describe an app and the assistant scaffolds it in Jac.
                    </Text>
                    <View style={styles.promptCard}>
                        <TextInput
                            style={styles.promptInput}
                            value={s["prompt"]}
                            placeholder="Build me a social feed with likes and comments…"
                            placeholderTextColor={C.muted}
                            multiline={True}
                            onChangeText={lambda v: str { s["setPrompt"](v); }}
                        />
                        <View style={styles.promptBar}>
                            <View style={styles.promptTools}>
                                <ModelChip/>
                                <Pressable style={styles.composerBtn}>
                                    <Icon
                                        name="image"
                                        size={18}
                                        color={C.muted}
                                        fill={False}
                                        width={2}
                                    />
                                </Pressable>
                                <Pressable style={styles.composerBtn}>
                                    <Icon
                                        name="mic"
                                        size={18}
                                        color={C.muted}
                                        fill={False}
                                        width={2}
                                    />
                                </Pressable>
                            </View>
                            <Pressable
                                style={styles.sendFab}
                                onPress={s["sendPrompt"]}
                                disabled={s["isBusy"]("prompt")}
                            >
                                {(<Spinner color={C.accentText}/>)
                                    if s["isBusy"]("prompt")
                                    else (
                                        <Icon
                                            name="send"
                                            size={18}
                                            color={C.accentText}
                                            fill={False}
                                            width={2}
                                        />
                                    )}
                            </Pressable>
                        </View>
                    </View>
                    <View style={styles.chipRow}>
                        {[<SuggChip key={sg} text={sg}/> for sg in SUGGESTIONS]}
                    </View>
                    {(<View/>)
                        if (len(recents) == 0)
                        else (
                            <View style={{gap: S.sm}}>
                                <Text style={styles.sectionLabel}>
                                    Pick up where you left off
                                </Text>
                                {[<ProjectCard key={p["id"]} p={p}/> for p in recents]}
                            </View>
                        )}
                    <Text style={styles.sectionLabel}>Start from</Text>
                    <View style={styles.tileRow}>
                        <Pressable
                            style={styles.tile}
                            onPress={lambda { s["openNew"]("folder"); }}
                        >
                            <Icon
                                name="folder"
                                size={20}
                                color={C.accent}
                                fill={False}
                                width={2}
                            />
                            <Text style={styles.tileTitle}>Open folder</Text>
                            <Text style={styles.tileMeta}>Local project</Text>
                        </Pressable>
                        <Pressable
                            style={styles.tile}
                            onPress={lambda { s["openNew"]("jacpack"); }}
                        >
                            <Icon
                                name="box"
                                size={20}
                                color={C.accent}
                                fill={False}
                                width={2}
                            />
                            <Text style={styles.tileTitle}>JacPack</Text>
                            <Text style={styles.tileMeta}>Import bundle</Text>
                        </Pressable>
                        <Pressable
                            style={styles.tile}
                            onPress={lambda { s["openNew"]("github"); }}
                        >
                            <Icon
                                name="branch"
                                size={20}
                                color={C.accent}
                                fill={False}
                                width={2}
                            />
                            <Text style={styles.tileTitle}>GitHub</Text>
                            <Text style={styles.tileMeta}>Clone repo</Text>
                        </Pressable>
                    </View>
                </ScrollView>
            </KeyboardAvoidingView>;
    }
}
