import from "@jac/mobui" { View, Text, Pressable }
import from core.jacyac.native.theme { makeStyles }
import from core.brand.theme { useTheme }
import from core.jacyac.native.icon { Icon }

obj Tab {
    has key: str,
        icon: str,
        label: str;
}

glob TABS: list[Tab] = [
         Tab(key="feed", icon="home", label="Home"),
         Tab(key="scores", icon="explore", label="Scores"),
         Tab(key="explore", icon="explore", label="Explore"),
         Tab(key="channels", icon="hash", label="Channels"),
         Tab(key="profile", icon="user", label="Profile")
     ];

def:pub TabBar(activeTab: str, onNavigate: Callable[[str], None]) -> JsxElement {
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
