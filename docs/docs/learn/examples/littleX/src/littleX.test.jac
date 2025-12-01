test visit_profile {
    root spawn visit_profile();
    profile = [root-->(`?Profile)][0];
    assert isinstance(profile, Profile);
}

test update_profile {
    root spawn update_profile(new_username="test_user",);
    profile = [root-->(`?Profile)][0];
    assert profile.username == "test_user";
}

test follow_request {
    followee = Profile("Sam");
    followee spawn follow_request();
    followee_profile = [root-->(`?Profile)->:Follow:->(`?Profile)][0];
    assert followee_profile.username == "Sam";
}

test un_follow_request {
    followee = [root-->(`?Profile)->:Follow:->(`?Profile)][0];
    followee spawn un_follow_request();
    assert len([root-->(`?Profile)->:Follow:->(`?Profile)]) == 0;
}

test create_tweet {
    root spawn create_tweet(content="test_tweet",);
    test1 = [root-->(`?Profile)-->(`?Tweet)][0];
    assert test1.content == "test_tweet";
}

test update_tweet {
    tweet1 = [root-->(`?Profile)-->(`?Tweet)][0];
    tweet1 spawn update_tweet(updated_content="new_tweet",);
    assert tweet1.content == "new_tweet";
}

test remove_tweet {
    tweet2 = [root-->(`?Profile)-->(`?Tweet)][0];
    tweet2 spawn remove_tweet();
    assert len([root-->(`?Profile)-->(`?Tweet)]) == 0;
}

test like_tweet {
    root spawn create_tweet(content="test_like",);
    tweet1 = [root-->(`?Profile)-->(`?Tweet)][0];
    tweet1 spawn like_tweet();
    test1 = [tweet1->:Like:->][0];
    assert test1.username == "test_user";
}

test remove_like {
    tweet1 = [root-->(`?Profile)-->(`?Tweet)][0];
    tweet1 spawn remove_like();
    assert len([tweet1->:Like:->]) == 0;
}

test comment_tweet {
    tweet = [root-->(`?Profile)-->(`?Tweet)](?content=="test_like")[0];
    tweet spawn comment_tweet(content="test_comment",);
    comment = [tweet-->(`?Comment)][0];
    assert comment.content == "test_comment";
}

test update_comment {
    tweet = [root-->(`?Profile)-->(`?Tweet)](?content=="test_like")[0];
    comment = [tweet-->(`?Comment)][0];
    comment spawn update_comment(updated_content="new_comment",);
    assert comment.content == "new_comment";
}

test remove_comment {
    comment = [root-->(`?Profile)-->(`?Tweet)-->(`?Comment)][0];
    comment spawn remove_comment();
    assert len([root-->(`?Profile)-->(`?Tweet)-->(`?Comment)]) == 0;
}
