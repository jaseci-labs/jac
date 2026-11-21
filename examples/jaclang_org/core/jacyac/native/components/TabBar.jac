import from "@jac/mobui" { View, Text, Pressable }

obj Tab {
    has key: str,
        icon: str,
        label: str;
}

glob TABS: list[Tab] = [
    Tab(key="feed", icon="home", label="Home"),
    Tab(key="explore", icon="explore", label="Explore"),
    Tab(key="channels", icon="hash", label="Channels"),
    Tab(key="ninjaclaw", icon="bot", label="ninjaclaw"),
    Tab(key="profile", icon="user", label="Profile"),
];

def TabBar(activeTab: str, onNavigate: Callable[[str], Coroutine[any, any, None]]) -> JsxElement;
