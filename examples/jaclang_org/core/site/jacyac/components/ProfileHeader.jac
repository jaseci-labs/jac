import from "@jac/runtime" { Link as RouterLink }
import from "lucide-react" { Bot, MapPin, Link2, Github, CalendarDays, Camera, Trash2, Pencil }

def:pub ProfileHeader(
    bundle: ProfileBundle,
    isMine: bool,
    avatars: dict[str, str],
    isFollowing: bool,
    onFollow: Callable[[str], Coroutine[any, any, None]],
    onUnfollow: Callable[[str], Coroutine[any, any, None]],
    onStartEdit: Callable[[], None] | None = None,
    avatarBusy: bool = False,
    onAvatarFile: Callable[[any], Coroutine[any, any, None]] | None = None,
    onClearAvatar: Callable[[], Coroutine[any, any, None]] | None = None,
) -> JsxElement;
