"""jachammer bottom-sheet modals — New project, Notifications, AI model, project
overflow menu, Rename, Share, Delete, and the read-only file viewer. Each is an
overlay the shell renders conditionally from store flags.
"""

cl {
    import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView, Keyboard, KeyboardAvoidingView }
    import from ..ui.icon { Icon }
    import from ..ui.theme { S }
    import from ..hooks.useStudio { useStudio }
    import from ..components.Backdrop { Backdrop }
    import from ..components.ActivityRow { ActivityRow }
    import from ..components.Spinner { Spinner }

    def:pub NewModal -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"];
        newMode = s["newMode"]; newTemplate = s["newTemplate"]; templates = s["templates"];
        return
            <View style={styles.modalOverlay}>
                <Backdrop close={lambda { Keyboard.dismiss(); s["setShowNew"](False); }}/>
                <KeyboardAvoidingView style={{width: "100%", alignItems: "center"}} behavior={s["kbBehavior"]()}>
                    <View style={styles.modalCard}>
                        <View style={styles.modalHead}>
                            <Text style={styles.modalTitle}>New project</Text>
                            <Pressable style={styles.iconBtn} onPress={lambda { Keyboard.dismiss(); s["setShowNew"](False); }}>
                                <Icon name="close" size={22} color={C.muted} fill={False} width={2}/>
                            </Pressable>
                        </View>
                        <View style={styles.segRow}>
                            {[
                                <Pressable
                                    style={([styles.segItem, styles.segItemActive] if newMode == mo["id"] else styles.segItem)}
                                    key={mo["id"]}
                                    onPress={lambda { s["setNewMode"](mo["id"]); }}
                                >
                                    <Text style={(styles.segTextActive if newMode == mo["id"] else styles.segText)}>{mo["label"]}</Text>
                                </Pressable>
                                for mo in [
                                    {"id": "template", "label": "Template"},
                                    {"id": "folder", "label": "Folder"},
                                    {"id": "jacpack", "label": "JacPack"},
                                    {"id": "github", "label": "GitHub"}
                                ]
                            ]}
                        </View>
                        {(
                            <View style={styles.fieldRow}>
                                <Icon name="branch" size={18} color={C.muted} fill={False} width={2}/>
                                <TextInput
                                    style={styles.fieldInput}
                                    value={s["newRepo"]}
                                    placeholder="github.com/you/repo"
                                    placeholderTextColor={C.muted}
                                    autoCapitalize="none"
                                    onChangeText={lambda v: str { s["setNewRepo"](v); }}
                                />
                            </View>
                        )
                            if (newMode == "github")
                            else <View/>}
                        <View style={styles.fieldRow}>
                            <Icon name="box" size={18} color={C.muted} fill={False} width={2}/>
                            <TextInput
                                style={styles.fieldInput}
                                value={s["newName"]}
                                placeholder="project-name"
                                placeholderTextColor={C.muted}
                                autoCapitalize="none"
                                onChangeText={lambda v: str { s["setNewName"](v); }}
                            />
                        </View>
                        {(
                            <View style={{gap: S.sm}}>
                                <Text style={styles.sectionLabel}>Template</Text>
                                <View style={styles.chipRow}>
                                    {[
                                        <Pressable
                                            style={(styles.chipActive if newTemplate == t["id"] else styles.chip)}
                                            key={t["id"]}
                                            onPress={lambda { s["setNewTemplate"](t["id"]); }}
                                        >
                                            <Icon
                                                name="box"
                                                size={14}
                                                color={(C.accentText if newTemplate == t["id"] else C.muted)}
                                                fill={False}
                                                width={2}
                                            />
                                            <Text style={(styles.chipActiveText if newTemplate == t["id"] else styles.chipText)}>{t["name"]}</Text>
                                        </Pressable>
                                        for t in templates
                                    ]}
                                </View>
                                {(<Text style={styles.emptyText}>Loading templates…</Text>) if len(templates) == 0 else <View/>}
                            </View>
                        )
                            if (newMode == "template")
                            else <View/>}
                        <Pressable style={styles.primaryBtn} onPress={s["createProject"]} disabled={s["isBusy"]("create")}>
                            {(<Spinner color={C.accentText}/>)
                                if s["isBusy"]("create")
                                else (<Icon name="hammer" size={16} color={C.accentText} fill={False} width={2}/>)}
                            <Text style={styles.primaryLabel}>{("Creating…" if s["isBusy"]("create") else "Create project")}</Text>
                        </Pressable>
                    </View>
                </KeyboardAvoidingView>
            </View>;
    }

    def:pub NotifsSheet -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"]; activity = s["activity"];
        return
            <View style={styles.modalOverlay}>
                <Backdrop close={lambda { s["setNotifOpen"](False); }}/>
                <View style={styles.modalCard}>
                    <View style={styles.modalHead}>
                        <Text style={styles.modalTitle}>Notifications</Text>
                        <Pressable style={styles.iconBtn} onPress={lambda { s["setNotifOpen"](False); }}>
                            <Icon name="close" size={22} color={C.muted} fill={False} width={2}/>
                        </Pressable>
                    </View>
                    {(
                        <View style={styles.empty}>
                            <Icon name="bell" size={28} color={C.muted} fill={False} width={1.6}/>
                            <Text style={styles.emptyText}>You're all caught up.</Text>
                        </View>
                    )
                        if (len(activity) == 0)
                        else (<ScrollView style={styles.sheetScroll}>{[<ActivityRow key={a["id"]} a={a}/> for a in activity]}</ScrollView>)}
                </View>
            </View>;
    }

    def:pub ModelSheet -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"]; model = s["model"]; models = s["models"];
        return
            <View style={styles.modalOverlay}>
                <Backdrop close={lambda { s["setModelSheet"](False); }}/>
                <View style={styles.modalCard}>
                    <View style={styles.modalHead}>
                        <Text style={styles.modalTitle}>AI model</Text>
                        <Pressable style={styles.iconBtn} onPress={lambda { s["setModelSheet"](False); }}>
                            <Icon name="close" size={22} color={C.muted} fill={False} width={2}/>
                        </Pressable>
                    </View>
                    {[
                        <Pressable
                            style={styles.row}
                            key={mm["id"]}
                            onPress={lambda { s["chooseModel"](mm["id"]); s["setModelSheet"](False); }}
                        >
                            <Icon name="spark" size={16} color={C.accent} fill={True} width={2}/>
                            <Text style={[styles.optionLabel, {flex: 1}]}>{mm["name"]}</Text>
                            {(<Icon name="check" size={18} color={C.accent} fill={False} width={2}/>) if (model == mm["id"]) else <View/>}
                        </Pressable>
                        for mm in models
                    ]}
                    {(<Text style={styles.emptyText}>Your plan's models load after sign-in.</Text>) if len(models) == 0 else <View/>}
                </View>
            </View>;
    }

    def:pub ProjMenu -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"]; projMenu = s["projMenu"];
        return
            <View style={styles.modalOverlay}>
                <Backdrop close={lambda { s["setProjMenu"](""); }}/>
                <View style={styles.modalCard}>
                    <Pressable style={styles.row} onPress={lambda { pid = projMenu; s["setProjMenu"](""); s["openProject"](pid); }}>
                        <Icon name="box" size={18} color={C.text} fill={False} width={2}/>
                        <Text style={styles.optionLabel}>Open</Text>
                    </Pressable>
                    <Pressable style={styles.row} onPress={lambda { s["startRename"](projMenu); }}>
                        <Icon name="edit" size={18} color={C.text} fill={False} width={2}/>
                        <Text style={styles.optionLabel}>Rename</Text>
                    </Pressable>
                    <Pressable style={styles.row} onPress={lambda { s["setShareId"](projMenu); s["setProjMenu"](""); }}>
                        <Icon name="clone" size={18} color={C.text} fill={False} width={2}/>
                        <Text style={styles.optionLabel}>Share to community</Text>
                    </Pressable>
                    <Pressable style={styles.rowLast} onPress={lambda { s["setDeleteId"](projMenu); s["setProjMenu"](""); }}>
                        <Icon name="close" size={18} color={C.danger} fill={False} width={2}/>
                        <Text style={[styles.optionLabel, {color: C.danger}]}>Delete</Text>
                    </Pressable>
                </View>
            </View>;
    }

    def:pub RenameSheet -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"];
        return
            <View style={styles.modalOverlay}>
                <Backdrop close={lambda { s["setRenameId"](""); }}/>
                <KeyboardAvoidingView style={{width: "100%", alignItems: "center"}} behavior={s["kbBehavior"]()}>
                    <View style={styles.modalCard}>
                        <View style={styles.modalHead}>
                            <Text style={styles.modalTitle}>Rename project</Text>
                            <Pressable style={styles.iconBtn} onPress={lambda { s["setRenameId"](""); }}>
                                <Icon name="close" size={22} color={C.muted} fill={False} width={2}/>
                            </Pressable>
                        </View>
                        <View style={styles.fieldRow}>
                            <Icon name="edit" size={18} color={C.muted} fill={False} width={2}/>
                            <TextInput
                                style={styles.fieldInput}
                                value={s["renameVal"]}
                                placeholder="new name"
                                placeholderTextColor={C.muted}
                                autoCapitalize="none"
                                onChangeText={lambda v: str { s["setRenameVal"](v); }}
                            />
                        </View>
                        <Pressable style={styles.primaryBtn} onPress={s["doRename"]} disabled={s["isBusy"]("rename")}>
                            {(<Spinner color={C.accentText}/>)
                                if s["isBusy"]("rename")
                                else (<Text style={styles.primaryLabel}>Save</Text>)}
                        </Pressable>
                    </View>
                </KeyboardAvoidingView>
            </View>;
    }

    def:pub ShareSheet -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"];
        return
            <View style={styles.modalOverlay}>
                <Backdrop close={lambda { s["setShareId"](""); }}/>
                <KeyboardAvoidingView style={{width: "100%", alignItems: "center"}} behavior={s["kbBehavior"]()}>
                    <View style={styles.modalCard}>
                        <View style={styles.modalHead}>
                            <Text style={styles.modalTitle}>Share to community</Text>
                            <Pressable style={styles.iconBtn} onPress={lambda { s["setShareId"](""); }}>
                                <Icon name="close" size={22} color={C.muted} fill={False} width={2}/>
                            </Pressable>
                        </View>
                        <View style={styles.fieldRow}>
                            <Icon name="spark" size={18} color={C.muted} fill={False} width={2}/>
                            <TextInput
                                style={styles.fieldInput}
                                value={s["shareDesc"]}
                                placeholder="Short description"
                                placeholderTextColor={C.muted}
                                onChangeText={lambda v: str { s["setShareDesc"](v); }}
                            />
                        </View>
                        <View style={styles.fieldRow}>
                            <Icon name="star" size={18} color={C.muted} fill={False} width={2}/>
                            <TextInput
                                style={styles.fieldInput}
                                value={s["shareTags"]}
                                placeholder="tags (comma separated)"
                                placeholderTextColor={C.muted}
                                autoCapitalize="none"
                                onChangeText={lambda v: str { s["setShareTags"](v); }}
                            />
                        </View>
                        <Pressable style={styles.primaryBtn} onPress={s["doPublish"]} disabled={s["isBusy"]("publish")}>
                            {(<Spinner color={C.accentText}/>)
                                if s["isBusy"]("publish")
                                else (<Icon name="clone" size={16} color={C.accentText} fill={False} width={2}/>)}
                            <Text style={styles.primaryLabel}>{("Publishing…" if s["isBusy"]("publish") else "Publish")}</Text>
                        </Pressable>
                    </View>
                </KeyboardAvoidingView>
            </View>;
    }

    def:pub DeleteSheet -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"];
        deleteId = s["deleteId"];
        name = "this project";
        for p in s["projects"] {
            if p["id"] == deleteId { name = p["name"]; }
        }
        return
            <View style={styles.modalOverlay}>
                <Backdrop close={lambda { s["setDeleteId"](""); }}/>
                <View style={styles.modalCard}>
                    <Text style={styles.modalTitle}>Delete {name}?</Text>
                    <Text style={styles.emptyText}>This can't be undone.</Text>
                    <Pressable style={styles.dangerBtn} onPress={s["doDelete"]} disabled={s["isBusy"]("delete")}>
                        {(<Spinner color={C.danger}/>)
                            if s["isBusy"]("delete")
                            else (<Icon name="close" size={16} color={C.danger} fill={False} width={2}/>)}
                        <Text style={styles.dangerLabel}>{("Deleting…" if s["isBusy"]("delete") else "Delete project")}</Text>
                    </Pressable>
                    <Pressable style={styles.outlineBtn} onPress={lambda { s["setDeleteId"](""); }}>
                        <Text style={styles.outlineLabel}>Cancel</Text>
                    </Pressable>
                </View>
            </View>;
    }

    def:pub FileSheet -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"];
        fileView = s["fileView"]; fileBody = s["fileBody"];
        lines = fileBody.split("\n") if fileBody != "" else ["// Loading… (or this file has no readable contents yet)"];
        return
            <View style={styles.modalOverlay}>
                <Backdrop close={lambda { s["setFileView"](""); s["setFileBody"](""); }}/>
                <View style={styles.modalCard}>
                    <View style={styles.modalHead}>
                        <View style={styles.cardMetaRow}>
                            <Icon name="file" size={16} color={C.accent} fill={False} width={2}/>
                            <Text style={styles.modalTitle}>{fileView}</Text>
                        </View>
                        <Pressable style={styles.iconBtn} onPress={lambda { s["setFileView"](""); s["setFileBody"](""); }}>
                            <Icon name="close" size={22} color={C.muted} fill={False} width={2}/>
                        </Pressable>
                    </View>
                    <ScrollView style={styles.sheetScroll}>
                        <View style={styles.codeBox}>
                            {[<Text style={styles.codeLine} key={f"{fileView}-{i}"}>{line}</Text> for (i, line) in enumerate(lines)]}
                        </View>
                    </ScrollView>
                    <Text style={styles.emptyText}>The real project file, read live from jacBuilder.</Text>
                </View>
            </View>;
    }
}
