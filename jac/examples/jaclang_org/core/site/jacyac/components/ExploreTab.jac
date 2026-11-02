import from "lucide-react" { Users }

def:pub ExploreTab(
    allProfiles: list[Profile],
    followingIds: list[str],
    myProfileId: str,
    avatars: dict[str, str],
    onFollow: Callable[[str], None],
    onUnfollow: Callable[[str], None],
    onViewProfile: Callable[[str], None],
) -> JsxElement;
