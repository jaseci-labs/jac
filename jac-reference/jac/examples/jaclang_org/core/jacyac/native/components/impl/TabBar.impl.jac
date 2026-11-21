impl TabBar(activeTab: str, onNavigate: Callable[[str], None]) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    <View style={styles.tabBar}>
        {for t in TABS {
            <Pressable
                accessibilityRole="button"
                accessibilityLabel={t.label}
                accessibilityState={{"selected": activeTab == t.key}}
                style={styles.tabItem}
                key={t.key}
                onPress={lambda { onNavigate(t.key); }}
            >
                <Icon
                    name={t.icon}
                    size={22}
                    color={C.accent if activeTab == t.key else C.muted}
                />
                <Text
                    style={styles.tabLabelActive
                        if activeTab == t.key
                        else styles.tabLabel}
                >
                    {t.label}
                </Text>
            </Pressable>
        }}
    </View>
}
