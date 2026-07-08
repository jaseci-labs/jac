"""jachammer app shell — header + bottom tab bar + the active tab, or the project
detail screen when one is open. This is the authenticated home surface.
"""

cl {
    import from "@jac/mobui" { View, Text, Pressable }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }
    import from ..components.CreditsPill { CreditsPill }
    import from ..components.TabButton { TabButton }
    import from ..components.Logo { Logo }
    import from .HomeScreen { HomeScreen }
    import from .ProjectsScreen { ProjectsScreen }
    import from .CommunityScreen { CommunityScreen }
    import from .ActivityScreen { ActivityScreen }
    import from .ProfileScreen { ProfileScreen }
    import from .DetailScreen { DetailScreen }

    def:pub AppShell -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"];
        tab = s["tab"]; unreadCount = s["unreadCount"];
        if s["selId"] != "" {
            return <DetailScreen/>;
        }
        return
            <View style={styles.page}>
                <View style={styles.header}>
                    <View style={styles.headerBrand}>
                        <Logo size={34}/>
                        <View>
                            <Text style={styles.headerTitle}>jachammer</Text>
                            <Text style={styles.headerSub}>{s["tabTitle"]()}</Text>
                        </View>
                    </View>
                    <View style={styles.headerRight}>
                        <CreditsPill/>
                        <Pressable style={styles.iconBtn} onPress={s["openNotifs"]}>
                            <Icon name="bell" size={22} color={C.muted} fill={False} width={2}/>
                            {(<View style={styles.badge}><Text style={styles.badgeText}>{unreadCount()}</Text></View>)
                                if (unreadCount() > 0)
                                else <View/>}
                        </Pressable>
                    </View>
                </View>
                <View style={styles.body}>
                    {<HomeScreen/>
                        if (tab == "home")
                        else (
                            <ProjectsScreen/>
                                if (tab == "projects")
                                else (
                                    <CommunityScreen/>
                                        if (tab == "community")
                                        else (<ActivityScreen/> if (tab == "activity") else <ProfileScreen/>)
                                )
                        )}
                </View>
                <View style={styles.tabBar}>
                    <TabButton tabKey="home" icon="spark" label="Build"/>
                    <TabButton tabKey="projects" icon="projects" label="Projects"/>
                    <TabButton tabKey="community" icon="community" label="Community"/>
                    <TabButton tabKey="activity" icon="activity" label="Activity"/>
                    <TabButton tabKey="profile" icon="user" label="Profile"/>
                </View>
            </View>;
    }
}
