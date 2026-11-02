import from "@jac/mobui" {
    View,
    Text,
    StatusBar,
    ActivityIndicator,
    Pressable,
    useWindowDimensions
}

glob TAB_TITLES: dict[str, str] = {
         "feed": "Home",
         "explore": "Explore",
         "channels": "Channels",
         "ninjaclaw": "ninjaclaw",
         "profile": "Profile"
     };

def:pub JacYacMobile(embedded: bool = False) -> JsxElement;
