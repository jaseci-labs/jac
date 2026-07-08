"""Projects tab — searchable, sortable list of the user's projects."""

cl {
    import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView, KeyboardAvoidingView }
    import from ..ui.icon { Icon }
    import from ..ui.theme { S }
    import from ..hooks.useStudio { useStudio }
    import from ..components.ProjectCard { ProjectCard }

    def:pub ProjectsScreen -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"];
        sort = s["sort"];
        shown = s["sortedProjects"]();
        return
            <KeyboardAvoidingView style={styles.kav} behavior={s["kbBehavior"]()}>
            <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollBody} keyboardShouldPersistTaps="handled">
                <View style={styles.sectionRow}>
                    <Text style={styles.sectionLabel}>Your projects</Text>
                    <Pressable style={styles.sectionAction} onPress={lambda { s["openNew"]("template"); }}>
                        <Icon name="plus" size={16} color={C.accent} fill={False} width={2}/>
                        <Text style={styles.sectionActionText}>New</Text>
                    </Pressable>
                </View>
                <View style={styles.fieldRow}>
                    <Icon name="search" size={18} color={C.muted} fill={False} width={2}/>
                    <TextInput
                        style={styles.fieldInput}
                        value={s["projQuery"]}
                        placeholder="Search your projects"
                        placeholderTextColor={C.muted}
                        autoCapitalize="none"
                        onChangeText={lambda v: str { s["setProjQuery"](v); }}
                    />
                </View>
                <View style={styles.chipRow}>
                    <Pressable
                        style={styles.sortPill}
                        onPress={lambda { s["setSort"]("name" if sort == "updated" else "updated"); }}
                    >
                        <Icon name="sort" size={14} color={C.muted} fill={False} width={2}/>
                        <Text style={styles.chipText}>
                            {("Sorted by name" if sort == "name" else "Recently updated")}
                        </Text>
                    </Pressable>
                </View>
                {(
                    <View style={styles.empty}>
                        <Icon name="box" size={32} color={C.muted} fill={False} width={1.6}/>
                        <Text style={styles.emptyTitle}>No projects found</Text>
                        <Text style={styles.emptyText}>Tap New, or start one from a prompt on Home.</Text>
                    </View>
                )
                    if (len(shown) == 0)
                    else (<View style={{gap: S.md}}>{[<ProjectCard key={p["id"]} p={p}/> for p in shown]}</View>)}
            </ScrollView>
            </KeyboardAvoidingView>;
    }
}
