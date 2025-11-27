


impl search_tweets {
    transformed = vectorizer.fit_transform([query, tweet]);
    similarity = cosine_similarity(transformed[0], transformed[1])[0];
    return similarity;
}

impl Profile.update {
    self.username = visitor.new_username;
    report self;
}

impl Profile.get {
        follwers=[{"id": jid(i), "username": i.username} for i in [self-->(`?Profile)]];
        report {"user": self, "followers": follwers};
    }

impl Profile.follow{
        current_profile = [root-->(`?Profile)];
        current_profile[0] +>:Follow():+> self;
        report self;
    }

impl Profile.un_follow {
        current_profile = [root-->(`?Profile)];
        follow_edge = [edge current_profile[0] ->:Follow:-> self];
        del follow_edge[0];
        report self;
    }

impl Tweet.update {
        self.content = visitor.updated_content;
        report self;
    }

impl Tweet.delete {
        del self;
        disengage;
    }

impl Tweet.like_tweet {
        current_profile = [root-->(`?Profile)];
        self +>:Like():+> current_profile[0];
        report self;
    }

impl Tweet.remove_like {
        current_profile = [root-->(`?Profile)];
        like_edge = [edge self ->:Like:-> current_profile[0]];
        del like_edge[0];
        report self;
    }

impl Tweet.comment {
        current_profile = [root-->(`?Profile)];
        comment_node = current_profile[0] +>:Post():+> Comment(content=visitor.content);
        grant(comment_node[0], level=ConnectPerm);
        self ++> comment_node[0];
        comment_info = CommentInfo(
            id=jid(comment_node[0]),
            content=comment_node[0].content,
            username=current_profile[0].username
        );
        print("Comment Info:", comment_info);
        report comment_info;
    }

impl Tweet.get_info {
        return TweetInfo(
            username=[self<-:Post:<-][0].username,
            id=jid(self),
            content=self.content,
            embedding=self.embedding,
            likes=[i.username for i in [self->:Like:->]],
            comments=[{"username": [i<--(`?Profile)][0].username, "id": jid(i), "content": i.content} for i in [self-->(`?Comment)]],
            created_at=self.created_at
        );
    }

impl Tweet.get {
        tweet_info = self.get_info();
        similarity = search_tweets(visitor.search_query, tweet_info.content);
        visitor.results.append({"Tweet_Info": tweet_info, "similarity": similarity});
    }

impl Comment.update {
        self.content = visitor.updated_content;
        report self;
    }

impl Comment.delete {
        del self;
        disengage;
    }

impl visit_profile.visit_profile {
        print(jid(here));
        existing_profiles = [-->(`?Profile)];

        visit [-->(`?Profile)] else {
            new_profile = here ++> Profile();
            grant(new_profile[0], level=ConnectPerm);
            visit new_profile;
        }
    }

impl load_user_profiles.load_profiles {
        self.profiles: list = [];

        for each_root in allroots() {
            profile = [each_root --> (`?Profile)][0];
            self.profiles.append(
                {"name": profile.username, "id": jid(profile)}
            );
        }
    }


impl load_user_profiles.report_profiles {
    report self.profiles;
}

impl create_tweet.tweet {
    embedding = vectorizer.fit_transform([self.content]).toarray().tolist();
    tweet_node = here +>:Post():+> Tweet(content=self.content, embedding=embedding);
    grant(tweet_node[0], level=ConnectPerm);

    tweet_info = TweetInfo(
        id=jid(tweet_node[0]),
        content=tweet_node[0].content,
        created_at=tweet_node[0].created_at,
        embedding=tweet_node[0].embedding,
        username=here.username,
        likes=[],
        comments=[]
    );

    report tweet_info;
    }

impl load_feed.load {
        visit [-->(`?Tweet)];
        for user_node in [->:Follow:->(`?Profile)] {
            visit [user_node-->(`?Tweet)];
        }
    }

impl load_feed.report_feed {
        self.results.sort(key=lambda x:dict:x['similarity'][0], reverse=True);
        report self.results;
}
