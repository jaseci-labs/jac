"""Channels tab for Little X: browse, create, and post in channels."""

sv import from ..server { ChannelView, TweetView }
import from "lucide-react" { Hash, Users, Plus, ArrowLeft }
import from .TweetCard { TweetCard }
import from .Composer { Composer }

def:pub ChannelsTab(
    channels: list[ChannelView],
    channelsLoading: bool,
    selectedChannel: ChannelView | None,
    channelPosts: list[TweetView],
    profileAvatar: str,
    profileUsername: str,
    onCreateChannel: any,
    onJoinChannel: any,
    onLeaveChannel: any,
    onSelectChannel: any,
    onChannelPost: any,
    onBackToChannels: any,
    onLike: any,
    onComment: any,
    onDelete: any,
    onRepost: any,
) -> JsxElement {
    has showCreateChannel: bool = False,
        newChannelName: str = "",
        newChannelDescription: str = "",
        channelComposerText: str = "";

    createFn = onCreateChannel;
    joinFn = onJoinChannel;
    leaveFn = onLeaveChannel;
    selectFn = onSelectChannel;
    postFn = onChannelPost;
    backFn = onBackToChannels;

    return
        <div>
            {if selectedChannel is None {
                <div className="lx-channel-actions">
                    <button
                        className="lx-post-btn"
                        onClick={lambda { showCreateChannel = not showCreateChannel; }}
                    >
                        <Plus size={16}/>
                        {"Create Channel"}
                    </button>
                </div>
                if showCreateChannel {
                    <div className="lx-channel-create-form">
                        <input
                            className="lx-input"
                            placeholder="Channel name"
                            value={newChannelName}
                            onChange={lambda e: ChangeEvent { newChannelName = e.target.value; }}
                        />
                        <input
                            className="lx-input"
                            placeholder="Description (optional)"
                            value={newChannelDescription}
                            onChange={lambda e: ChangeEvent { newChannelDescription = e.target.value; }}
                        />
                        <div style={{"display": "flex", "gap": "0.5rem"}}>
                            <button
                                className="lx-post-btn"
                                disabled={not newChannelName.strip()}
                                onClick={lambda {
                                    createFn.call(
                                        None,
                                        newChannelName.strip(),
                                        newChannelDescription.strip()
                                    );
                                    newChannelName = "";
                                    newChannelDescription = "";
                                    showCreateChannel = False;
                                }}
                            >
                                Create
                            </button>
                            <button
                                className="lx-edit-profile-btn"
                                onClick={lambda {
                                    showCreateChannel = False;
                                    newChannelName = "";
                                    newChannelDescription = "";
                                }}
                            >
                                Cancel
                            </button>
                        </div>
                    </div>
                }
                if channelsLoading {
                    <div className="lx-loading">Loading channels...</div>
                    skip;
                }
                if len(channels) == 0 {
                    <div className="lx-empty">
                        <div className="lx-empty-title">No channels yet</div>
                        <span>Create one to get started!</span>
                    </div>
                    skip;
                }
                for ch in channels {
                    <div
                        className="lx-channel-item"
                        key={ch.id}
                        onClick={lambda { selectFn.call(None, ch.id); }}
                    >
                        <div className="lx-channel-icon">
                            <Hash size={20}/>
                        </div>
                        <div className="lx-channel-item-info">
                            <div className="lx-channel-item-name">{ch.name}</div>
                            {if ch.description {
                                <div className="lx-channel-item-desc">
                                    {ch.description}
                                </div>
                            }}
                            <div className="lx-channel-item-meta">
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
                            <span className="lx-channel-joined-badge">Joined</span>
                        }}
                    </div>
                }
            } else {
                <div className="lx-channel-header">
                    <button
                        className="lx-edit-profile-btn"
                        onClick={lambda { backFn.call(None); }}
                        style={{
                            "display": "flex",
                            "alignItems": "center",
                            "gap": "0.3rem"
                        }}
                    >
                        <ArrowLeft size={16}/>
                        Back
                    </button>
                    <div className="lx-channel-name">
                        <Hash size={20}/>
                        {selectedChannel.name}
                    </div>
                    {if selectedChannel.description {
                        <div className="lx-channel-desc">
                            {selectedChannel.description}
                        </div>
                    }}
                    <div className="lx-channel-meta">
                        <Users size={14}/>
                        <span>
                            {str(selectedChannel.member_count) + (
                                " member"
                                    if selectedChannel.member_count == 1
                                    else " members"
                            )}
                        </span>
                        {if selectedChannel.is_member {
                            <button
                                className="lx-edit-profile-btn"
                                onClick={lambda { if selectedChannel {
                                    leaveFn.call(None, selectedChannel.id);
                                }}}
                            >
                                Leave
                            </button>
                        } else {
                            <button
                                className="lx-follow-btn"
                                onClick={lambda { if selectedChannel {
                                    joinFn.call(None, selectedChannel.id);
                                }}}
                            >
                                Join
                            </button>
                        } }
                    </div>
                </div>
                if selectedChannel.is_member {
                    <Composer
                        avatar={profileAvatar}
                        avatarAlt={profileUsername}
                        placeholder={"Post in #" + selectedChannel.name}
                        value={channelComposerText}
                        onChange={lambda v: str { channelComposerText = v; }}
                        onPost={lambda {
                            postFn.call(None, channelComposerText);
                            channelComposerText = "";
                        }}
                        rows={2}
                        buttonLabel="Post"
                        showCharRing={False}
                    />
                }
                if len(channelPosts) == 0 {
                    <div className="lx-empty">
                        <div className="lx-empty-title">No posts yet</div>
                        <span>
                            {(
                                "Be the first to post!"
                                    if selectedChannel.is_member
                                    else "Join this channel to post!"
                            )}
                        </span>
                    </div>
                    skip;
                }
                for tweet in channelPosts {
                    <TweetCard
                        key={tweet.id}
                        tweet={tweet}
                        myUsername={profileUsername}
                        onLike={onLike}
                        onComment={onComment}
                        onDelete={onDelete}
                        onRepost={onRepost}
                    />
                }
            } }
        </div>;
}
