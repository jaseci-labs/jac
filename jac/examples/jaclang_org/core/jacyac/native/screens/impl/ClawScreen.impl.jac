impl body_parts(body: str) -> list[BodyPart] {
    parts: list[BodyPart] = [];
    para: list[str] = [];
    code: list[str] = [];
    in_code = False;

    def flush {
        text = " ".join([ln.strip() for ln in para]).strip();
        if text {
            parts.append(BodyPart(kind="text", text=text));
        }
        para.clear();
    }
    for line in body.split("\n") {
        if line.strip().startswith("```") {
            if in_code {
                parts.append(BodyPart(kind="code", text="\n".join(code)));
                code.clear();
            } else {
                flush();
            }
            in_code = not in_code;
        } elif in_code {
            code.append(line);
        } elif line.startswith("#") {
            flush();
            parts.append(BodyPart(kind="heading", text=line.lstrip("#").strip()));
        } elif not line.strip() {
            flush();
        } else {
            para.append(line);
        }
    }
    flush();
    if code {
        parts.append(BodyPart(kind="code", text="\n".join(code)));
    }
    return parts;
}

impl outcome_label(job: JobView) -> str {
    if job.status == "working" or job.status == "queued" {
        return job.status;
    }
    return CLAW_OUTCOMES.get(job.outcome, job.outcome or job.status);
}

impl TutorialBody(body: str) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    <View style={styles.clawBody}>
        {for (i, part) in enumerate(body_parts(body)) {
            if part.kind == "code" {
                <ScrollView horizontal={True} style={styles.codeBlock} key={str(i)}>
                    <Text style={styles.codeText}>{part.text}</Text>
                </ScrollView>
            } elif part.kind == "heading" {
                <Text style={styles.clawHeading} key={str(i)}>{part.text}</Text>
            } else {
                <Text style={styles.cardText} key={str(i)}>{part.text}</Text>
            }
        }}
    </View>
}

impl ClawScreen -> JsxElement {
    has section: str = "tutorials",
        focus: str = "";
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    model = useClaw(section, focus);
    a = model.activity;

    def pick(next: str) {
        section = next;
        focus = "";
    }

    <ScrollView style={styles.body} contentContainerStyle={styles.scrollBody}>
        <View style={styles.chipRow}>
            {for (key, label) in [
                ("tutorials", "Tutorials"),
                ("ninjaclaw", "Activity")
            ] {
                <Pressable
                    accessibilityRole="button"
                    accessibilityState={{"selected": section == key}}
                    style={styles.chip if section == key else styles.badge}
                    key={key}
                    onPress={lambda { pick(key); }}
                >
                    <Text style={styles.chipText}>{label}</Text>
                </Pressable>
            }}
        </View>
        {if model.error {
            <Text style={styles.sectionHint}>{model.error}</Text>
        }}
        {if focus {
            <View>
                <Pressable
                    accessibilityRole="button"
                    style={styles.backBtn}
                    onPress={lambda { focus = ""; }}
                >
                    <Icon name="back" size={16} color={C.text}/>
                    <Text style={styles.backLabel}>
                        {"All tutorials" if section == "tutorials" else "All activity"}
                    </Text>
                </Pressable>
                {if section == "tutorials" and model.tutorial {
                    <View style={styles.detailHead}>
                        <Text style={styles.profileName}>
                            {model.tutorial.card.title}
                        </Text>
                        <Text style={styles.sectionHint}>
                            {model.tutorial.card.summary}
                        </Text>
                        <Text style={styles.channelMetaText}>
                            {(
                                "stale: failed on the current jac"
                                    if model.tutorial.card.status == "stale"
                                    else "verified on jac "
                                        + model.tutorial.card.verified_version
                            )}
                        </Text>
                        <TutorialBody body={model.tutorial.body}/>
                    </View>
                } elif section == "ninjaclaw" and model.job {
                    <View style={styles.detailHead}>
                        <View style={styles.badge}>
                            <Text style={styles.badgeText}>
                                {outcome_label(model.job)}
                            </Text>
                        </View>
                        <Text style={styles.cardText}>
                            {model.job.question
                                or "(" + (model.job.detail or "not shown") + ")"}
                        </Text>
                        {if model.job.reply {
                            <Text style={styles.sectionHint}>
                                {"ninjaclaw replied: " + model.job.reply}
                            </Text>
                        }}
                        {for (i, st) in enumerate(model.job.steps) {
                            <Text style={styles.channelMetaText} key={str(i)}>
                                {st.phase + " · " + st.text}
                            </Text>
                        }}
                    </View>
                } elif model.loading {
                    <LoadingRows count={3}/>
                }  }
            </View>
        } elif section == "tutorials" {
            <View>
                {if model.loading and len(model.tutorials) == 0 {
                    <LoadingRows count={4}/>
                } elif len(model.tutorials) == 0 {
                    <EmptyState
                        icon="book"
                        title="No tutorials yet"
                        hint="Mention @ninjaclaw with a Jac question. When nothing answers it, ninjaclaw writes a short tutorial, checks every example, and files it here."
                    />
                } else {
                    for t in model.tutorials {
                        <Pressable
                            accessibilityRole="button"
                            style={styles.channelRow}
                            key={t.slug}
                            onPress={lambda { focus = t.slug; }}
                        >
                            <View style={styles.channelBody}>
                                <Text style={styles.channelName}>{t.title}</Text>
                                <Text style={styles.channelDesc} numberOfLines={2}>
                                    {t.summary}
                                </Text>
                                <Text style={styles.channelMetaText}>
                                    {(
                                        "stale"
                                            if t.status == "stale"
                                            else "verified on jac " + t.verified_version
                                    )
                                        + " · "
                                        + count_label(t.answered, "asker", "askers")}
                                </Text>
                            </View>
                        </Pressable>
                    }
                }  }
            </View>
        } else {
            <View>
                {if a {
                    <View style={styles.detailHead}>
                        <View style={styles.rowGap}>
                            <Icon name="bot" size={20} color={C.accent}/>
                            <Text style={styles.channelName}>
                                {"ninjaclaw · " + a.state}
                            </Text>
                        </View>
                        <Text style={styles.sectionHint}>
                            {a.detail
                                or "Mention @ninjaclaw or post in #help with a Jac question."}
                        </Text>
                        {if a.current {
                            <Pressable
                                accessibilityRole="button"
                                onPress={lambda { focus = a.current.job_id; }}
                            >
                                <Text style={styles.cardText}>
                                    {"Now: " + a.current.question}
                                </Text>
                            </Pressable>
                        }}
                    </View>
                }}
                {if a and (a.queue or a.recent) {
                    for j in a.queue + a.recent {
                        <Pressable
                            accessibilityRole="button"
                            style={styles.channelRow}
                            key={j.job_id}
                            onPress={lambda { focus = j.job_id; }}
                        >
                            <View style={styles.channelBody}>
                                <View style={styles.badge}>
                                    <Text style={styles.badgeText}>
                                        {outcome_label(j)}
                                    </Text>
                                </View>
                                <Text style={styles.channelDesc} numberOfLines={2}>
                                    {j.question
                                        or "(" + (j.detail or "not shown") + ")"}
                                </Text>
                                <Text style={styles.channelMetaText}>
                                    {"@" + handle_of(j.asker) + " · " + j.source}
                                </Text>
                            </View>
                        </Pressable>
                    }
                } elif model.loading or not a {
                    <LoadingRows count={4}/>
                } else {
                    <EmptyState
                        icon="bot"
                        title="No questions yet"
                        hint="Mention @ninjaclaw in a post to ask one."
                    />
                }  }
            </View>
        }  }
    </ScrollView>
}
