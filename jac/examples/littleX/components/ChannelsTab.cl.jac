"""Channels tab for Little X: browse, create, and post in channels."""

import from "lucide-react" { Hash, Users, Plus, ArrowLeft }
import from .ui.button { Button }
import from .ui.input { Input }
import from .ui.textarea { Textarea }
import from .ui.badge { Badge }
import from .ui.field { Field, FieldLabel }
import from .ui.skeleton { Skeleton }
import from .ui.empty { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription }
import from .ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
    DialogFooter
}
import from .TweetCard { TweetCard }
import from .Composer { Composer }
sv import from ..social_graph { ChannelView, TweetView }

def:pub ChannelsTab(
    channels: list[ChannelView],
    channelsLoading: bool,
    selectedChannel: ChannelView | None,
    channelPosts: list[TweetView],
    profileAvatar: str,
    profileUsername: str,
    onCreateChannel: Callable[[str, str], None],
    onJoinChannel: Callable[[str], None],
    onLeaveChannel: Callable[[str], None],
    onSelectChannel: Callable[[str], None],
    onChannelPost: Callable[[str], None],
    onBackToChannels: Callable[[], None],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], None],
    onDelete: Callable[[str], None],
    onRepost: Callable[[str, str, str], None],
) -> JsxElement {
    has showCreateChannel: bool = False,
        newChannelName: str = "",
        newChannelDescription: str = "",
        channelComposerText: str = "";

    return
        <div>
            {if selectedChannel is None {
                <div className="p-4">
                    <Button
                        className="w-full font-semibold"
                        onClick={lambda { showCreateChannel = True; }}
                    >
                        <Plus size={16}/>
                        Create Channel
                    </Button>
                </div>
                <Dialog
                    open={showCreateChannel}
                    onOpenChange={lambda (v: bool) { showCreateChannel = v; }}
                >
                    <DialogContent>
                        <DialogHeader>
                            <DialogTitle>Create a channel</DialogTitle>
                            <DialogDescription>
                                Start a space for people to gather around a topic.
                            </DialogDescription>
                        </DialogHeader>
                        <div className="flex flex-col gap-4">
                            <Field>
                                <FieldLabel htmlFor="lx-ch-name">Name</FieldLabel>
                                <Input
                                    id="lx-ch-name"
                                    placeholder="e.g. jac-builders"
                                    value={newChannelName}
                                    onChange={lambda (e: ChangeEvent) { newChannelName = e.target.value; }}
                                />
                            </Field>
                            <Field>
                                <FieldLabel htmlFor="lx-ch-desc">
                                    Description
                                </FieldLabel>
                                <Textarea
                                    id="lx-ch-desc"
                                    rows={2}
                                    placeholder="What's this channel about? (optional)"
                                    value={newChannelDescription}
                                    onChange={lambda (e: ChangeEvent) { newChannelDescription = e.target.value; }}
                                />
                            </Field>
                        </div>
                        <DialogFooter>
                            <Button
                                variant="outline"
                                onClick={lambda { showCreateChannel = False; }}
                            >
                                Cancel
                            </Button>
                            <Button
                                className="font-semibold"
                                disabled={not newChannelName.strip()}
                                onClick={lambda {
                                    onCreateChannel(
                                        newChannelName.strip(),
                                        newChannelDescription.strip()
                                    );
                                    newChannelName = "";
                                    newChannelDescription = "";
                                    showCreateChannel = False;
                                }}
                            >
                                Create
                            </Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
                if channelsLoading {
                    <div className="flex flex-col gap-3 px-4">
                        {[
                            <Skeleton className="h-20 w-full rounded-xl" key={i}/>
                            for i in range(4)
                        ]}
                    </div>
                    skip;
                }
                if len(channels) == 0 {
                    <Empty className="py-16">
                        <EmptyHeader>
                            <EmptyMedia variant="icon">
                                <Hash/>
                            </EmptyMedia>
                            <EmptyTitle>No channels yet</EmptyTitle>
                            <EmptyDescription>
                                Create one to get the conversation started.
                            </EmptyDescription>
                        </EmptyHeader>
                    </Empty>
                    skip;
                }
                for ch in channels {
                    <div
                        className="lx-fade-up mx-4 mb-3 flex cursor-pointer items-center gap-3 rounded-xl border border-border bg-card p-4 transition-colors hover:bg-muted/40"
                        key={ch.id}
                        onClick={lambda { onSelectChannel(ch.id); }}
                    >
                        <div
                            className="flex size-11 shrink-0 items-center justify-center rounded-lg bg-primary/15 text-primary"
                        >
                            <Hash size={20}/>
                        </div>
                        <div className="min-w-0 flex-1">
                            <div
                                className="font-display font-bold text-foreground truncate"
                            >
                                {ch.name}
                            </div>
                            {if ch.description {
                                <div className="text-sm text-muted-foreground truncate">
                                    {ch.description}
                                </div>
                            }}
                            <div
                                className="mt-1 flex items-center gap-1 text-xs text-muted-foreground"
                            >
                                <Users size={12}/>
                                <span>
                                    {str(ch.member_count) + (
                                        " member"
                                            if ch.member_count == 1
                                            else " members"
                                    )}
                                </span>
                            </div>
                        </div>
                        {if ch.is_member {
                            <Badge variant="secondary" className="shrink-0">
                                Joined
                            </Badge>
                        }}
                    </div>
                }
            } else {
                <div className="border-b border-border p-4">
                    <Button
                        variant="ghost"
                        size="sm"
                        className="-ml-2 mb-2 gap-1 text-muted-foreground"
                        onClick={lambda { onBackToChannels(); }}
                    >
                        <ArrowLeft size={16}/>
                        Back
                    </Button>
                    <div className="flex items-center gap-2">
                        <div
                            className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary/15 text-primary"
                        >
                            <Hash size={20}/>
                        </div>
                        <div className="min-w-0 flex-1">
                            <div
                                className="font-display text-lg font-extrabold text-foreground truncate"
                            >
                                {selectedChannel.name}
                            </div>
                            <div
                                className="flex items-center gap-1 text-xs text-muted-foreground"
                            >
                                <Users size={12}/>
                                <span>
                                    {str(selectedChannel.member_count) + (
                                        " member"
                                            if selectedChannel.member_count == 1
                                            else " members"
                                    )}
                                </span>
                            </div>
                        </div>
                        {if selectedChannel.is_member {
                            <Button
                                variant="outline"
                                size="sm"
                                className="shrink-0"
                                onClick={lambda { if selectedChannel {
                                    onLeaveChannel(selectedChannel.id);
                                }}}
                            >
                                Leave
                            </Button>
                        } else {
                            <Button
                                size="sm"
                                className="shrink-0 font-semibold"
                                onClick={lambda { if selectedChannel {
                                    onJoinChannel(selectedChannel.id);
                                }}}
                            >
                                Join
                            </Button>
                        } }
                    </div>
                    {if selectedChannel.description {
                        <p className="mt-2 text-sm text-foreground/80">
                            {selectedChannel.description}
                        </p>
                    }}
                </div>
                if selectedChannel.is_member {
                    <Composer
                        avatar={profileAvatar}
                        avatarAlt={profileUsername}
                        placeholder={"Post in #" + selectedChannel.name}
                        value={channelComposerText}
                        onChange={lambda (v: str) { channelComposerText = v; }}
                        onPost={lambda {
                            onChannelPost(channelComposerText);
                            channelComposerText = "";
                        }}
                        rows={2}
                        buttonLabel="Post"
                        showCharRing={False}
                    />
                }
                if len(channelPosts) == 0 {
                    <Empty className="py-12">
                        <EmptyHeader>
                            <EmptyMedia variant="icon">
                                <Hash/>
                            </EmptyMedia>
                            <EmptyTitle>No posts yet</EmptyTitle>
                            <EmptyDescription>
                                {(
                                    "Be the first to post!"
                                        if selectedChannel.is_member
                                        else "Join this channel to post!"
                                )}
                            </EmptyDescription>
                        </EmptyHeader>
                    </Empty>
                    skip;
                }
                for tweet in channelPosts {
                    <TweetCard
                        key={tweet.id}
                        {tweet}
                        myUsername={profileUsername}
                        {onLike}
                        {onComment}
                        {onDelete}
                        {onRepost}
                    />
                }
            } }
        </div>;
}
