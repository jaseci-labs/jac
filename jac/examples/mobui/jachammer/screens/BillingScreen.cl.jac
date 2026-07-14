"""jachammer billing screen — the real `me → billing` summary (tier, balance,
this-cycle usage) plus the static plan-comparison catalogue (jacBuilder hardcodes
this too; checkout is on the web). Rendered as a full-screen overlay.
"""

cl {
    import from "@jac/mobui" { View, Text, Pressable, ScrollView }
    import from "react-native" { Linking }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }
    import from ..kit.constants { PLANS, JB_API }

    def:pub BillingScreen -> JsxElement {
        s = useStudio();
        C = s["C"];
        styles = s["styles"];
        plan = s["plan"];
        usd = s["usd"];
        return
            <View
                style={[
                    styles.root,
                    {position: "absolute", top: 0, left: 0, right: 0, bottom: 0}
                ]}
            >
                <View style={styles.page}>
                    <View style={styles.header}>
                        <View style={styles.headerBrand}>
                            <Pressable
                                style={styles.iconBtn}
                                onPress={lambda { s["setBillingOpen"](False); }}
                            >
                                <Icon
                                    name="back"
                                    size={24}
                                    color={C.text}
                                    fill={False}
                                    width={2}
                                />
                            </Pressable>
                            <Text style={styles.headerTitle}>Billing</Text>
                        </View>
                    </View>
                    <ScrollView
                        style={styles.scroll}
                        contentContainerStyle={styles.scrollBody}
                    >
                        <View style={styles.planCard}>
                            <View style={styles.cardMetaRow}>
                                <Icon
                                    name="spark"
                                    size={16}
                                    color={C.accent}
                                    fill={True}
                                    width={2}
                                />
                                <Text style={styles.cardName}>{plan} plan</Text>
                            </View>
                            <Text style={styles.priceBig}>
                                {s["billingRemaining"]()}
                            </Text>
                            <Text style={styles.cardMeta}>{s["billingSub"]()}</Text>
                            <View style={styles.actionRow}>
                                <Pressable
                                    style={[styles.primaryBtn, {flex: 1}]}
                                    onPress={lambda { s["jbLoadAccount"](""); }}
                                >
                                    <Text style={styles.primaryLabel}>Refresh</Text>
                                </Pressable>
                            </View>
                            <Text style={styles.emptyText}>
                                Plans &amp; top-ups are managed on jacbuilder.app — sign in there to change your tier.
                            </Text>
                        </View>
                        <Text style={styles.sectionLabel}>Plans</Text>
                        <View style={styles.metricRow}>
                            {[
                                <Pressable
                                    style={(
                                        [
                                            styles.compareCol,
                                            {borderColor: C.accent, borderWidth: 1}
                                        ]
                                            if pl["name"] == plan
                                            else styles.compareCol
                                    )}
                                    key={pl["name"]}
                                    onPress={lambda { Linking.openURL(JB_API); }}
                                >
                                    <Text style={styles.rowTitle}>{pl["name"]}</Text>
                                    <Text style={styles.priceBig}>{pl["price"]}</Text>
                                    <Text style={styles.cardMeta}>{pl["note"]}</Text>
                                    {(
                                        <Text
                                            style={[styles.cardMeta, {color: C.accent}]}
                                        >
                                            Current
                                        </Text>
                                    )
                                        if (pl["name"] == plan)
                                        else (
                                            <Text
                                                style={[
                                                    styles.cardMeta,
                                                    {color: C.accent}
                                                ]}
                                            >
                                                Choose →
                                            </Text>
                                        )}
                                </Pressable> for pl in PLANS
                            ]}
                        </View>
                        <Text style={styles.sectionLabel}>This cycle</Text>
                        <View style={styles.panel}>
                            <View style={styles.row}>
                                <Icon
                                    name="spark"
                                    size={16}
                                    color={C.accent}
                                    fill={True}
                                    width={2}
                                />
                                <Text style={[styles.rowTitle, {flex: 1}]}>
                                    Monthly limit
                                </Text>
                                <Text style={styles.rowMeta}>
                                    {usd("monthly_limit_usd")}
                                </Text>
                            </View>
                            <View style={styles.row}>
                                <Icon
                                    name="spark"
                                    size={16}
                                    color={C.muted}
                                    fill={False}
                                    width={2}
                                />
                                <Text style={[styles.rowTitle, {flex: 1}]}>
                                    Used this cycle
                                </Text>
                                <Text style={styles.rowMeta}>
                                    {usd("cycle_cost_usd")}
                                </Text>
                            </View>
                            <View style={styles.rowLast}>
                                <Icon
                                    name="spark"
                                    size={16}
                                    color={C.muted}
                                    fill={False}
                                    width={2}
                                />
                                <Text style={[styles.rowTitle, {flex: 1}]}>
                                    Top-up balance
                                </Text>
                                <Text style={styles.rowMeta}>
                                    {usd("topup_balance_usd")}
                                </Text>
                            </View>
                        </View>
                    </ScrollView>
                </View>
            </View>;
    }
}
