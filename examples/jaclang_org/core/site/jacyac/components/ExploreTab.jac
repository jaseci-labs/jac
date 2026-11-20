import from "lucide-react" { Users }

def:pub ExploreTab(
    allProfiles: list[Profile],
    followingIds: list[str],
    myProfileId: str,
    avatars: dict[str, str],
    onFollow: Callable[[str], Coroutine[any, any, None]],
    onUnfollow: Callable[[str], Coroutine[any, any, None]],
    onViewProfile: Callable[[str], Coroutine[any, any, None]],
) -> JsxElement;
