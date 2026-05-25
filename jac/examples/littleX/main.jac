"""Little X - Entry point combining backend and frontend."""

to cl:

import from .frontend { app as ClientApp }

def:pub app -> JsxElement {
    return
        <ClientApp/>;
}

to sv:

import from server {
    setup_profile,
    get_profile,
    get_all_profiles,
    follow_user,
    unfollow_user,
    create_tweet,
    delete_tweet,
    like_tweet,
    add_comment,
    load_feed,
    get_trending,
    create_channel,
    join_channel,
    leave_channel,
    get_channels,
    get_channel_detail,
    create_channel_tweet
}
