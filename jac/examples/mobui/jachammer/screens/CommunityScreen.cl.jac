"""Community tab — searchable starter gallery."""

cl {
    import from "@jac/mobui" { View, TextInput, ScrollView, KeyboardAvoidingView }
    import from ..ui.icon { Icon }
    import from ..ui.theme { S }
    import from ..hooks.useStudio { useStudio }
    import from ..components.CommunityCard { CommunityCard }

    def:pub CommunityScreen -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"];
        query = s["query"];
        items = [c for c in s["communityItems"] if query == "" or (query in c["name"] or query in c["author"])];
        return
            <KeyboardAvoidingView style={styles.body} behavior={s["kbBehavior"]()}>
                <View style={[styles.fieldRow, {margin: S.lg}]}>
                    <Icon name="search" size={18} color={C.muted} fill={False} width={2}/>
                    <TextInput
                        style={styles.fieldInput}
                        value={query}
                        placeholder="Search community"
                        placeholderTextColor={C.muted}
                        autoCapitalize="none"
                        onChangeText={lambda v: str { s["setQuery"](v); }}
                    />
                </View>
                <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollBody} keyboardShouldPersistTaps="handled">
                    {[<CommunityCard key={c["id"]} c={c}/> for c in items]}
                </ScrollView>
            </KeyboardAvoidingView>;
    }
}
