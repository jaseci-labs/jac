impl import {
    edge ScoreBehindFeed: core.scoring --> core.feed { Score, reputation }
    edge ScoreBehindUi: core.scoring --> core.ui { Score }
    edge FeedBehindUi: core.feed --> core.ui {
        Feed,
        join,
        publish,
        toggle_like,
        remove_post,
        load_feed
    }
    edge FeedBehindCli: core.feed --> cli {
        join,
        publish,
        toggle_like,
        remove_post,
        load_feed
    }
    edge ThemeBehindUi: core.theme --> core.ui { S, C }
    edge UiBehindWeb: core.ui --> web { FeedApp }
    edge UiBehindMobile: core.ui --> mobile { FeedApp }
    edge UiBehindDesktop: core.ui --> desktop { FeedApp }
}

impl import core {
    feed --> cli { join, load_feed, publish, remove_post, toggle_like }
    feed --> core.ui { Feed, join, load_feed, publish, remove_post, toggle_like }
    scoring --> core.feed { Score, reputation }
    scoring --> core.ui { Score }
    theme --> core.ui { C, S }
    ui --> desktop | mobile | web { FeedApp }
}
