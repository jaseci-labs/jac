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

impl shrink_avatar(file: any) -> str {
    win: any = window;
    bmp: any = await win.createImageBitmap(file);
    side = bmp.width if bmp.width < bmp.height else bmp.height;
    canvas: any = document.createElement("canvas");
    canvas.width = AVATAR_SIDE;
    canvas.height = AVATAR_SIDE;
    ctx: any = canvas.getContext("2d");
    ctx.drawImage(
        bmp,
        (bmp.width - side) / 2,
        (bmp.height - side) / 2,
        side,
        side,
        0,
        0,
        AVATAR_SIDE,
        AVATAR_SIDE
    );
    bmp.close();
    return canvas.toDataURL("image/jpeg", 0.86);
}
