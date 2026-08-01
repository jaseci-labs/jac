"""Server fixture exposing walkers that exercise cross-user graph queries.

These walkers cooperate to build a two-user graph and run queries that
the system-root topology-index optimizer needs to handle correctly:

  * `query_follow_chain` runs a 2-hop forward chain from the caller's
    profile into another user's graph.
  * `query_channel_members` runs a 1-hop reverse query whose incoming
    edges were created by other users.

The fixture is exercised end-to-end via `JacTestClient`, which keeps a
single long-lived runtime context across requests.
"""

node Profile {
    has username: str = "";
}

node Tweet {
    has content: str = "";
}

node Channel {
    has name: str = "";
}

edge Follow {}
edge Post {}
edge Member {}


walker:priv setup_profile_only {
    has username: str = "",
        reports: list = [];

    can run with Root entry {
        existing = [-->[?:Profile]];
        if existing {
            visit existing;
        } else {
            fresh = here ++> Profile(username=self.username);
            grant(fresh, level=ConnectPerm);
            visit fresh;
        }
    }

    can apply with Profile entry {
        if self.username {
            here.username = self.username;
        }
        report jid(here);
    }
}

walker:priv post_tweet {
    has content: str = "",
        reports: list = [];

    can run with Root entry {
        visit [-->[?:Profile]];
    }

    can make with Profile entry {
        tweet = Tweet(content=self.content);
        here +>:Post():+> tweet;
        grant(tweet, level=ConnectPerm);
        report jid(tweet);
    }
}

walker:priv create_channel {
    has name: str = "",
        reports: list = [];

    can run with Root entry {
        visit [-->[?:Profile]];
    }

    can make with Profile entry {
        chan = Channel(name=self.name);
        here +>:Member():+> chan;
        grant(chan, level=ConnectPerm);
        report jid(chan);
    }
}

walker:priv follow_target {
    has target_id: str = "",
        reports: list = [];

    can run with Root entry {
        visit [-->[?:Profile]];
    }

    can act with Profile entry {
        target_profile = &(self.target_id);
        here +>:Follow():+> target_profile;
        report "ok";
    }
}

walker:priv join_channel {
    has channel_id: str = "",
        reports: list = [];

    can run with Root entry {
        visit [-->[?:Profile]];
    }

    can act with Profile entry {
        chan = &(self.channel_id);
        here +>:Member():+> chan;
        report "ok";
    }
}

walker:priv query_follow_chain {
    """Forward chain: my Follow edges -> their Profile -> their Tweets."""
    has reports: list = [];

    can run with Root entry {
        prof_list = [-->[?:Profile]];
        if not prof_list {
            report 0;
            return;
        }
        me = prof_list[0];
        tweets = [me->:Follow:->[?:Profile]-->[?:Tweet]];
        report len(tweets);
    }
}

walker:priv query_channel_members {
    has channel_id: str = "",
        reports: list = [];

    can run with Root entry {
        chan = &(self.channel_id);
        members = [chan<-:Member:<-[?:Profile]];
        report len(members);
    }
}
