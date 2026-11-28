graph import {
    edge FeedBehindCli: core.feed --> cli {
        join,
        load_feed,
        publish,
        remove_post,
        toggle_like
    }
    edge FeedBehindUi: core.feed --> core.ui {
        Feed,
        join,
        load_feed,
        publish,
        remove_post,
        toggle_like
    }
    edge ScoreBehindFeed: core.scoring --> core.feed { Score, reputation }
    edge ScoreBehindUi: core.scoring --> core.ui { Score }
    edge ThemeBehindUi: core.theme --> core.ui { C, S }
    edge UiBehindShells: core.ui --> desktop | mobile | web { FeedApp }

    core.feed ++> cli { join, load_feed, publish, remove_post, toggle_like }
    core.ui ++> desktop | mobile | web { FeedApp }
}

graph import core {
    feed ++> ui { Feed, join, load_feed, publish, remove_post, toggle_like }
    scoring ++> [
        feed { Score, reputation },
        ui { Score },
    ]
    theme ++> ui { C, S }
}
