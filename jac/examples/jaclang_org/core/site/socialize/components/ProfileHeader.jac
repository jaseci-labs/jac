import from "lucide-react" {
    MapPin,
    Link2,
    Github,
    CalendarDays,
    Camera,
    Trash2,
    Pencil
}
import from core.site.ui.avatar { Avatar, AvatarImage, AvatarFallback }
import from core.site.ui.button { Button }
import from core.social_graph { ProfileBundle }
import from ..identity { handle_of, initial_of, name_of, avatar_of }

def:pub ProfileHeader(
    bundle: ProfileBundle,
    isMine: bool,
    avatars: dict[str, str],
    isFollowing: bool,
    onFollow: Callable[[str], None],
    onUnfollow: Callable[[str], None],
    onStartEdit: Callable[[], None],
    avatarBusy: bool,
    onAvatarFile: Callable[[any], None],
    onClearAvatar: Callable[[], None],
) -> JsxElement {
    has fileRef: Ref[HTMLInputElement] = Ref();

    profile = bundle.profile;
    handle = handle_of(profile.username);
    shown_name = name_of(profile);
    avatar = avatar_of(avatars, profile.username);
    followingCount = len(bundle.following) if bundle.following else 0;
    followerCount = len(bundle.followers) if bundle.followers else 0;
    postCount = len(bundle.tweets) if bundle.tweets else 0;
    projectCount = len(bundle.projects) if bundle.projects else 0;
    joined = new(Date, profile.created_at).toLocaleDateString(
        "en-US", {"month": "short", "year": "numeric"}
    )
        if profile.created_at
        else "";
    site_label = profile.website.replace("https://", "").replace("http://", "").rstrip(
        "/"
    );

    def pick_file(e: ChangeEvent) {
        files: any = e.target.files;
        if files and len(files) > 0 {
            onAvatarFile(files[0]);
        }
        e.target.value = "";
    }

    <div>
        <div
            className="h-36 w-full bg-gradient-to-br from-primary/50 via-primary/20 to-background"
        />
        <div className="px-4 pb-3">
            <div className="-mt-12 flex items-end justify-between gap-3">
                <div className="group relative">
                    <Avatar className="size-24 border-4 border-background shadow-lg">
                        <AvatarImage src={avatar} alt={handle}/>
                        <AvatarFallback className="text-2xl">
                            {initial_of(shown_name)}
                        </AvatarFallback>
                    </Avatar>
                    {if isMine {
                        <button
                            type="button"
                            id="lx-avatar-button"
                            title="Change photo"
                            disabled={avatarBusy}
                            className="absolute inset-1 flex items-center justify-center rounded-full bg-black/55 text-white opacity-0 transition-opacity group-hover:opacity-100 focus:opacity-100 disabled:opacity-100"
                            onClick={lambda { if fileRef.current {
                                fileRef.current.click();
                            }}}
                        >
                            <Camera
                                size={22}
                                className={"animate-pulse" if avatarBusy else ""}
                            />
                        </button>
                    }}
                </div>
                <div className="flex items-center gap-2 pb-1">
                    {if isMine {
                        <input
                            id="lx-avatar-input"
                            ref={fileRef}
                            type="file"
                            accept="image/png,image/jpeg,image/webp"
                            className="hidden"
                            onChange={pick_file}
                        />
                        if profile.avatar_v {
                            <Button
                                variant="outline"
                                size="sm"
                                className="rounded-full"
                                disabled={avatarBusy}
                                onClick={lambda { onClearAvatar(); }}
                            >
                                <Trash2 size={14}/>
                                Remove photo
                            </Button>
                        }
                        <Button
                            variant="outline"
                            size="sm"
                            className="rounded-full"
                            id="lx-edit-profile"
                            onClick={lambda { onStartEdit(); }}
                        >
                            <Pencil size={14}/>
                            Edit profile
                        </Button>
                    } elif isFollowing {
                        <Button
                            variant="outline"
                            size="sm"
                            className="group rounded-full hover:border-destructive/40 hover:bg-destructive/10 hover:text-destructive"
                            onClick={lambda { onUnfollow(jid(profile)); }}
                        >
                            <span className="group-hover:hidden">Following</span>
                            <span className="hidden group-hover:inline">Unfollow</span>
                        </Button>
                    } else {
                        <Button
                            size="sm"
                            className="rounded-full font-semibold"
                            onClick={lambda { onFollow(jid(profile)); }}
                        >
                            Follow
                        </Button>
                    }  }
                </div>
            </div>
            <div
                className="mt-3 font-display text-xl font-extrabold text-foreground"
                id="lx-profile-name"
            >
                {shown_name}
            </div>
            <div className="text-sm text-muted-foreground">{"@" + handle}</div>
            {if profile.bio {
                <p className="mt-3 whitespace-pre-wrap text-sm text-foreground/90">
                    {profile.bio}
                </p>
            } elif isMine {
                <p className="mt-3 text-sm text-muted-foreground">
                    No bio yet. Tell people what you build.
                </p>
            } }
            <div
                className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-muted-foreground"
            >
                {if profile.location {
                    <span className="inline-flex items-center gap-1">
                        <MapPin size={14}/>
                        {profile.location}
                    </span>
                }}
                {if profile.website {
                    <a
                        href={profile.website}
                        target="_blank"
                        rel="noreferrer"
                        className="inline-flex items-center gap-1 text-primary hover:underline"
                    >
                        <Link2 size={14}/>
                        {site_label}
                    </a>
                }}
                {if profile.github {
                    <a
                        href={"https://github.com/" + profile.github}
                        target="_blank"
                        rel="noreferrer"
                        className="inline-flex items-center gap-1 text-primary hover:underline"
                    >
                        <Github size={14}/>
                        {profile.github}
                    </a>
                }}
                {if joined {
                    <span className="inline-flex items-center gap-1">
                        <CalendarDays size={14}/>
                        {"Joined " + joined}
                    </span>
                }}
            </div>
            <div className="mt-4 flex flex-wrap gap-5 text-sm">
                <div className="flex items-center gap-1">
                    <span className="font-display font-bold text-foreground">
                        {str(followingCount)}
                    </span>
                    <span className="text-muted-foreground">Following</span>
                </div>
                <div className="flex items-center gap-1">
                    <span className="font-display font-bold text-foreground">
                        {str(followerCount)}
                    </span>
                    <span className="text-muted-foreground">
                        {("Follower" if followerCount == 1 else "Followers")}
                    </span>
                </div>
                <div className="flex items-center gap-1">
                    <span className="font-display font-bold text-foreground">
                        {str(postCount)}
                    </span>
                    <span className="text-muted-foreground">
                        {("Post" if postCount == 1 else "Posts")}
                    </span>
                </div>
                <div className="flex items-center gap-1">
                    <span className="font-display font-bold text-foreground">
                        {str(projectCount)}
                    </span>
                    <span className="text-muted-foreground">
                        {("Project" if projectCount == 1 else "Projects")}
                    </span>
                </div>
            </div>
        </div>
    </div>
}
