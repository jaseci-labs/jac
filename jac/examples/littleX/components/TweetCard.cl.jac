"""Tweet card component for Little X."""

import from "lucide-react" { Heart, MessageCircle, Trash2, Repeat2, Send }
import from .ui.avatar { Avatar, AvatarImage, AvatarFallback }
import from .ui.button { Button }
import from .ui.input { Input }
import from .ui.tooltip { TooltipProvider, Tooltip, TooltipTrigger, TooltipContent }
import from .ui.alert_dialog {
    AlertDialog,
    AlertDialogTrigger,
    AlertDialogContent,
    AlertDialogHeader,
    AlertDialogFooter,
    AlertDialogTitle,
    AlertDialogDescription,
    AlertDialogAction,
    AlertDialogCancel
}
import from ..lib.utils { cn }
sv import from ..social_graph { TweetView }

def:pub TweetCard(
    tweet: TweetView,
    myUsername: str,
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], None],
    onDelete: Callable[[str], None],
    onRepost: Callable[[str, str, str], None],
) -> JsxElement {
    has showComments: bool = False,
        commentText: str = "";

    is_liked = myUsername in tweet.likes;
    like_count = len(tweet.likes);
    comment_count = len(tweet.comments);
    author_avatar = "https://i.pravatar.cc/150?u=fake@" + tweet.author_username;

    raw_name = tweet.author_username or "unknown";
    display_name = raw_name.split("@")[0] if "@" in raw_name else raw_name;
    initial = display_name[0].upper() if display_name else "?";

    diff_ms = Date.now() - new(Date, tweet.created_at).getTime()
        if tweet.created_at
        else 0;
    diff_min = int(diff_ms / 60000);
    diff_hr = int(diff_min / 60);
    diff_day = int(diff_hr / 24);
    date_str = (
        "now"
            if diff_min < 1
            else (
                str(diff_min) + "m"
                    if diff_hr < 1
                    else (
                        str(diff_hr) + "h"
                            if diff_day < 1
                            else (
                                str(diff_day) + "d"
                                    if diff_day < 30
                                    else tweet.created_at[0:10]
                            )
                    )
            )
    )
        if tweet.created_at
        else "";

    return
        <article
            className="lx-fade-up flex gap-3 border-b border-border px-4 py-3 transition-colors hover:bg-muted/30"
        >
            <Avatar className="size-10 shrink-0">
                <AvatarImage src={author_avatar} alt={tweet.author_username}/>
                <AvatarFallback>{initial}</AvatarFallback>
            </Avatar>
            <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1.5 text-sm">
                    <span className="font-display font-bold text-foreground truncate">
                        {display_name}
                    </span>
                    <span className="text-muted-foreground truncate">
                        {"@" + display_name}
                    </span>
                    <span className="text-muted-foreground">·</span>
                    <span className="text-muted-foreground">{date_str}</span>
                    {if tweet.is_mine {
                        <div className="ml-auto">
                            <AlertDialog>
                                <AlertDialogTrigger asChild={True}>
                                    <Button
                                        variant="ghost"
                                        size="icon"
                                        className="size-7 text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
                                    >
                                        <Trash2 size={15}/>
                                    </Button>
                                </AlertDialogTrigger>
                                <AlertDialogContent>
                                    <AlertDialogHeader>
                                        <AlertDialogTitle>
                                            Delete post?
                                        </AlertDialogTitle>
                                        <AlertDialogDescription>
                                            This can't be undone and it will be removed from your profile and the feed.
                                        </AlertDialogDescription>
                                    </AlertDialogHeader>
                                    <AlertDialogFooter>
                                        <AlertDialogCancel>Cancel</AlertDialogCancel>
                                        <AlertDialogAction
                                            className="bg-destructive text-white hover:bg-destructive/90"
                                            onClick={lambda { onDelete(tweet.id); }}
                                        >
                                            Delete
                                        </AlertDialogAction>
                                    </AlertDialogFooter>
                                </AlertDialogContent>
                            </AlertDialog>
                        </div>
                    }}
                </div>
                <p
                    className="mt-0.5 whitespace-pre-wrap break-words text-[0.95rem] leading-relaxed text-foreground"
                >
                    {tweet.content}
                </p>
                <TooltipProvider>
                    <div className="mt-2 flex items-center gap-1 text-muted-foreground">
                        <Tooltip>
                            <TooltipTrigger asChild={True}>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="h-8 gap-1.5 rounded-full px-2 text-muted-foreground hover:bg-reply/10 hover:text-reply"
                                    onClick={lambda { showComments = not showComments; }}
                                >
                                    <MessageCircle size={16}/>
                                    {if comment_count > 0 {
                                        <span className="text-xs">
                                            {str(comment_count)}
                                        </span>
                                    }}
                                </Button>
                            </TooltipTrigger>
                            <TooltipContent>Reply</TooltipContent>
                        </Tooltip>
                        <Tooltip>
                            <TooltipTrigger asChild={True}>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="h-8 gap-1.5 rounded-full px-2 text-muted-foreground hover:bg-repost/10 hover:text-repost"
                                    onClick={lambda { onRepost(
                                        tweet.id, tweet.content, tweet.author_username
                                    ); }}
                                >
                                    <Repeat2 size={16}/>
                                </Button>
                            </TooltipTrigger>
                            <TooltipContent>Repost</TooltipContent>
                        </Tooltip>
                        <Tooltip>
                            <TooltipTrigger asChild={True}>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className={cn(
                                        "h-8 gap-1.5 rounded-full px-2 hover:bg-like/10 hover:text-like",
                                        "text-like"
                                            if is_liked
                                            else "text-muted-foreground"
                                    )}
                                    onClick={lambda { onLike(tweet.id); }}
                                >
                                    <Heart
                                        size={16}
                                        fill={"currentColor" if is_liked else "none"}
                                    />
                                    {if like_count > 0 {
                                        <span className="text-xs">
                                            {str(like_count)}
                                        </span>
                                    }}
                                </Button>
                            </TooltipTrigger>
                            <TooltipContent>
                                {"Unlike" if is_liked else "Like"}
                            </TooltipContent>
                        </Tooltip>
                    </div>
                </TooltipProvider>
                {if showComments {
                    <div
                        className="mt-3 flex flex-col gap-3 border-t border-border pt-3"
                    >
                        {for c in tweet.comments {
                            <div className="flex gap-2" key={c["created_at"]}>
                                <Avatar className="size-7 shrink-0">
                                    <AvatarImage
                                        src={"https://i.pravatar.cc/150?u=fake@" + c[
                                            "username"
                                        ]}
                                        alt={c["username"]}
                                    />
                                    <AvatarFallback className="text-[0.6rem]">
                                        {c["username"][0].upper()}
                                    </AvatarFallback>
                                </Avatar>
                                <div
                                    className="rounded-2xl rounded-tl-sm bg-muted px-3 py-1.5"
                                >
                                    <div
                                        className="text-xs font-semibold text-foreground"
                                    >
                                        {c["username"]}
                                    </div>
                                    <div className="text-sm text-foreground/90">
                                        {c["content"]}
                                    </div>
                                </div>
                            </div>
                        }}
                        <div className="flex items-center gap-2">
                            <Input
                                placeholder="Post your reply..."
                                value={commentText}
                                onChange={lambda e: ChangeEvent { commentText = e.target.value; }}
                                onKeyDown={lambda e: KeyboardEvent { if e.key == "Enter"
                                and commentText.strip() {
                                    onComment(tweet.id, commentText);
                                    commentText = "";
                                }}}
                            />
                            <Button
                                size="icon"
                                disabled={not commentText.strip()}
                                onClick={lambda { if commentText.strip() {
                                    onComment(tweet.id, commentText);
                                    commentText = "";
                                }}}
                            >
                                <Send size={16}/>
                            </Button>
                        </div>
                    </div>
                }}
            </div>
        </article>;
}
