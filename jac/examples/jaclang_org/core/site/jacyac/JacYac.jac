import from "lucide-react" { Feather, ArrowLeft }
import from "@jac/runtime" { useLocation }

glob AVATAR_SIDE: int = 256,
     PUBLIC_TABS: list[str] = ["user", "tutorials", "ninjaclaw"],
     TAB_TITLES: dict[str, str] = {
         "feed": "Home",
         "explore": "Explore",
         "channels": "Channels",
         "profile": "Profile",
         "tutorials": "Tutorials",
         "ninjaclaw": "ninjaclaw"
     };

async def shrink_avatar(file: any) -> str;

def:pub JacYac(initialTab: str = "feed") -> JsxElement;
