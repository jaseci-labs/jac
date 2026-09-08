import from "@jac/mobui" {
    View,
    Text,
    TextInput,
    Pressable,
    ScrollView,
    ActivityIndicator,
    Linking
}
import from core.jacyac.state { JacYacState }
import from core.jacyac.scores { useScores }
import from core.brand.theme { useTheme }
import from core.jacyac.native.theme { makeStyles }

def:pub ScoresScreen(model: JacYacState) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    scores = useScores(model);
    has url: str = "",
        showRepos: bool = False,
        expandedProject: str = "",
        confirmProject: str = "";
    async def submit {
        if await model.handleAddProject(url) {
            url = "";
        }
    }
    return
        <ScrollView
            style={styles.body}
            contentContainerStyle={{"padding": 16, "gap": 16, "paddingBottom": 32}}
            keyboardShouldPersistTaps="handled"
        >
            <Text style={styles.footnote}>
                Public projects from the JacYac community, scored from their code.
            </Text>
            {if model.session.loggedIn {
                <View style={{"gap": 12}}>
                    <TextInput
                        style={[
                            styles.fieldInput,
                            {"backgroundColor": C.field, "paddingHorizontal": 12}
                        ]}
                        placeholder="github.com/owner/repo"
                        placeholderTextColor={C.muted}
                        value={url}
                        autoCapitalize="none"
                        onChangeText={lambda (v: str) { url = v; }}
                    />
                    <Pressable
                        accessibilityRole="button"
                        style={styles.primaryBtn}
                        disabled={model.projectBusy or not url.strip()}
                        onPress={submit}
                    >
                        <Text style={styles.primaryLabel}>
                            {"Scoring…" if model.projectBusy else "Add project"}
                        </Text>
                    </Pressable>
                    {if model.session.githubEnabled and not scores.githubLinked {
                        <Pressable
                            accessibilityRole="button"
                            style={styles.outlineBtn}
                            disabled={model.session.busy}
                            onPress={model.session.githubLogin}
                        >
                            <Text style={styles.outlineLabel}>Connect GitHub</Text>
                        </Pressable>
                    }}
                    {if scores.githubLinked {
                        <Pressable
                            accessibilityRole="button"
                            style={styles.outlineBtn}
                            onPress={lambda { showRepos = not showRepos; }}
                        >
                            <Text style={styles.outlineLabel}>
                                Choose a public repository
                            </Text>
                        </Pressable>
                    }}
                    {if showRepos {
                        <View style={{"gap": 8}}>
                            {for repo in scores.repos {
                                <Pressable
                                    key={repo.full}
                                    accessibilityRole="button"
                                    style={styles.outlineBtn}
                                    disabled={model.projectBusy}
                                    onPress={lambda { model.handleAddProject(
                                        repo.url
                                    ); }}
                                >
                                    <Text style={styles.outlineLabel}>{repo.full}</Text>
                                </Pressable>
                            }}
                            {if scores.nextPage {
                                <Pressable
                                    accessibilityRole="button"
                                    disabled={scores.reposLoading}
                                    onPress={lambda { scores.loadRepos(
                                        scores.nextPage
                                    ); }}
                                >
                                    <Text style={styles.switchLink}>Load more</Text>
                                </Pressable>
                            }}
                        </View>
                    }}
                    {if scores.reposError {
                        <Text style={styles.errorText}>{scores.reposError}</Text>
                    }}
                    {if model.projectError or model.session.error {
                        <Text style={styles.errorText}>
                            {model.projectError or model.session.error}
                        </Text>
                    }}
                    {if model.projectNotice {
                        <Text style={styles.footnote}>{model.projectNotice}</Text>
                    }}
                </View>
            } else {
                <Pressable
                    accessibilityRole="button"
                    style={styles.primaryBtn}
                    onPress={lambda { model.navigate("feed"); }}
                >
                    <Text style={styles.primaryLabel}>Sign in to add your project</Text>
                </Pressable>
            } }
            <TextInput
                style={[
                    styles.fieldInput,
                    {"backgroundColor": C.field, "paddingHorizontal": 12}
                ]}
                placeholder="Search projects or people"
                placeholderTextColor={C.muted}
                value={scores.query}
                onChangeText={scores.setQuery}
            />
            <View style={styles.rowGap}>
                {for option in [
                    ["score", "Top"],
                    ["newest", "New"],
                    ["stars", "Stars"]
                ] {
                    <Pressable
                        key={option[0]}
                        accessibilityRole="button"
                        accessibilityState={{"selected": scores.sort == option[0]}}
                        style={styles.outlineBtn}
                        onPress={lambda { scores.setSort(option[0]); }}
                    >
                        <Text style={styles.outlineLabel}>{option[1]}</Text>
                    </Pressable>
                }}
            </View>
            {if model.projectsLoading {
                <ActivityIndicator color={C.accent}/>
            } elif not scores.projects {
                <Text style={styles.footnote}>No projects found.</Text>
            } }
            {for project in scores.projects {
                <View
                    key={jid(project)}
                    style={{
                        "gap": 8,
                        "borderBottomWidth": 1,
                        "borderColor": C.border,
                        "paddingBottom": 16
                    }}
                >
                    <Pressable
                        accessibilityRole="link"
                        onPress={lambda { Linking.openURL(project.permalink()); }}
                    >
                        <Text style={styles.outlineLabel}>{project.full}</Text>
                    </Pressable>
                    <Text style={styles.switchLink}>
                        {str(project.score)} points · {project.belt or project.status}
                    </Text>
                    <Text style={styles.footnote}>{project.description}</Text>
                    <Text style={styles.footnote}>
                        Submitted by @{project.owner_username}
                    </Text>
                    {if project.owner_verified {
                        <Text style={styles.switchLink}>
                            GitHub owner verified at submission
                        </Text>
                    }}
                    {if project.breakdown and project.breakdown.details {
                        <View>
                            <Pressable
                                accessibilityRole="button"
                                accessibilityState={{
                                    "expanded": expandedProject == jid(project)
                                }}
                                onPress={lambda { expandedProject = ""
                                    if expandedProject == jid(project)
                                    else jid(project); }}
                            >
                                <Text style={styles.switchLink}>Score breakdown</Text>
                            </Pressable>
                            {if expandedProject == jid(project) {
                                <View>
                                    {for part in project.breakdown.details {
                                        <Text key={part.label} style={styles.footnote}>
                                            {part.label}: {str(part.pts)} / {str(
                                                part.max
                                            )}
                                        </Text>
                                    }}
                                </View>
                            }}
                        </View>
                    }}
                    {if project.breakdown and project.breakdown.ai_review {
                        <View>
                            <Text style={styles.switchLink}>
                                AI code review · sampled files
                            </Text>
                            <Text style={styles.footnote}>
                                {project.breakdown.ai_review.summary}
                            </Text>
                            <Text style={styles.footnote}>
                                {project.breakdown.ai_review.strength.observation}
                            </Text>
                            <Text style={styles.footnote}>
                                {project.breakdown.ai_review.strength.evidence}
                            </Text>
                            <Text style={styles.footnote}>
                                {project.breakdown.ai_review.opportunity.action}
                            </Text>
                            <Text style={styles.footnote}>
                                {project.breakdown.ai_review.opportunity.reason}
                            </Text>
                        </View>
                    }}
                    {if model.myProfile
                        and project.owner_username
                            == model.myProfile.profile.username {
                        <View style={styles.rowGap}>
                            <Pressable
                                accessibilityRole="button"
                                disabled={model.projectBusy}
                                onPress={lambda { model.handleRescoreProject(
                                    jid(project)
                                ); }}
                            >
                                <Text style={styles.switchLink}>Rescore</Text>
                            </Pressable>
                            <Pressable
                                accessibilityRole="button"
                                disabled={model.projectBusy}
                                onPress={lambda { confirmProject = jid(project); }}
                            >
                                <Text style={styles.errorText}>Remove</Text>
                            </Pressable>
                        </View>
                    }}
                    {if confirmProject == jid(project) {
                        <View style={styles.confirmRow}>
                            <Text style={styles.confirmText}>Remove this project?</Text>
                            <Pressable
                                accessibilityRole="button"
                                style={styles.ghostBtn}
                                onPress={lambda { confirmProject = ""; }}
                            >
                                <Text style={styles.ghostLabel}>Keep</Text>
                            </Pressable>
                            <Pressable
                                accessibilityRole="button"
                                style={styles.dangerBtn}
                                onPress={lambda {
                                    confirmProject = "";
                                    model.handleRemoveProject(jid(project));
                                }}
                            >
                                <Text style={styles.dangerLabel}>Remove</Text>
                            </Pressable>
                        </View>
                    }}
                </View>
            }}
        </ScrollView>;
}
