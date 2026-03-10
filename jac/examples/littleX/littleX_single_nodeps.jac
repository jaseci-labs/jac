import datetime;
cl import from .littlex_fe { App }

node Profile {
    has username: str = "";

    can update with update_profile entry {
        self.username = visitor.new_username;
        report self;
    }

    can get with get_profile entry {
        follwers = [
            {"id": jid(i), "username": i.username} for i in [self-->(?:Profile)]
        ];
        report {"user": self, "followers": follwers};
    }

    can follow with follow_request entry {
        current_profile = [root-->(?:Profile)];
        current_profile[0] +>: Follow() :+> self;
        report self;
    }

    can un_follow with un_follow_request entry {
        current_profile = [root-->(?:Profile)];
        follow_edge = [edge current_profile[0]->:Follow:->self];
        del follow_edge[0];
        report self;
    }
}

obj TweetInfo {
    has username: str,
        id: str,
        content: str,
        embedding: list,
        likes: list,
        comments: list;
}

node Tweet {
    has content: str,
        embedding: list,
        created_at: str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S");

    can update with update_tweet exit {
        self.content = visitor.updated_content;
        report self;
    }

    can delete with remove_tweet exit {
        del self;
        disengage;
    }

    can like_tweet with like_tweet entry {
        current_profile = [root-->(?:Profile)];
        self +>: Like() :+> current_profile[0];
        report self;
    }

    can remove_like with remove_like entry {
        current_profile = [root-->(?:Profile)];
        like_edge = [edge self->:Like:->current_profile[0]];
        del like_edge[0];
        report self;
    }

    can comment with comment_tweet entry {
        current_profile = [root-->(?:Profile)];
        comment_node = current_profile[0] +>: Post() :+> Comment(
            content=visitor.content
        );
        grant(comment_node[0], level=ConnectPerm);
        self ++> comment_node[0];
        report comment_node[0];
    }

    def get_info -> TweetInfo {
        return TweetInfo(
            username=[self<-:Post:<-][0].username,
            id=jid(self),
            content=self.content,
            embedding=self.embedding,
            likes=[i.username for i in [self->:Like:->]],
            comments=[
                {
                    "username": [i<--(?:Profile)][0].username,
                    "id": jid(i),
                    "content": i.content
                } for i in [self-->(?:Comment)]
            ]
        );
    }

    can get with load_feed entry {
        tweet_info = self.get_info();
        visitor.results.append({"Tweet_Info": tweet_info});
    }
}

node Comment {
    has content: str;

    can update with update_comment entry {
        self.content = visitor.updated_content;
        report self;
    }

    can delete with remove_comment entry {
        del self;
        disengage;
    }
}

edge Follow {}
edge Like {}
edge Post {}

walker visit_profile {
    can visit_profile with Root entry {
        visit [-->(?:Profile)] else {
            new_profile = here ++> Profile();
            grant(new_profile[0], level=ConnectPerm);
            visit new_profile;
        }
    }
}

walker update_profile(visit_profile) {
    has new_username: str;
}

walker get_profile(visit_profile) {}

walker load_user_profiles {
    can load_profiles with Root entry {
        self.profiles: list = [];
        for each_root in allroots() {
            profile = [each_root-->(?:Profile)][0];
            self.profiles.append({"name": profile.username, "id": jid(profile)});
        }
    }

    can report_profiles with exit {
        report self.profiles;
    }
}

walker follow_request {}
walker un_follow_request {}

walker create_tweet(visit_profile) {
    has content: str;

    can tweet with Profile entry {
        tweet_node = here +>: Post() :+> Tweet(content=self.content, embedding=[]);
        grant(tweet_node[0], level=ConnectPerm);
        report tweet_node;
    }
}

walker update_tweet {
    has updated_content: str;
}

walker remove_tweet {}
walker like_tweet {}
walker remove_like {}

walker comment_tweet {
    has content: str;
}

walker update_comment {
    has updated_content: str;
}

walker remove_comment {}

walker load_feed(visit_profile) {
    has search_query: str = "",
        results: list = [];

    can load with Profile entry {
        visit [-->(?:Tweet)];
        for user_node in [->:Follow:->(?:Profile)] {
            visit [user_node-->(?:Tweet)];
        }
    }

    can report_feed with exit {
        report self.results;
    }
}

# Client-side UI Components (marked with 'cl' for browser execution)
# ===================================================================

# Main SPA entry point - simplified with reactive routing
cl def littlex_app -> JsxElement {
    return App();
}
