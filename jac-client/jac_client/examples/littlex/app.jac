
import datetime;
import numpy;
import from sklearn.feature_extraction.text { TfidfVectorizer }
import from sklearn.metrics.pairwise { cosine_similarity }

glob vectorizer = TfidfVectorizer();


def search_tweets(query: str, tweet:str) -> int;

node Profile {
    has username: str = "";

    can update with update_profile entry;

    can get with get_profile entry;

    can follow with follow_request entry;

    can un_follow with un_follow_request entry;
}
obj CommentInfo {
    has id: str;
    has content: str;
    has username: str;
}
obj TweetInfo {
    has username: str;
    has id: str;
    has content: str;
    has embedding: list;
    has likes: list;
    has comments: list;
    has created_at: str;
}

node Tweet {
    has content: str;
    has embedding: list;
    has created_at: str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S");

    can update with update_tweet exit;

    can delete with remove_tweet exit;

    can like_tweet with like_tweet entry;

    can remove_like with remove_like entry;

    can comment with comment_tweet entry;

    def get_info()-> TweetInfo;

    can get with load_feed entry;
}

node Comment {
    has content: str;

    can update with update_comment entry;

    can delete with remove_comment entry;
}

edge Follow {}

edge Like {}

edge Post {}

walker visit_profile {
    can visit_profile with `root entry;
}

walker update_profile(visit_profile) {
    has new_username: str;
}

walker get_profile(visit_profile) {}

walker load_user_profiles {

    can load_profiles with `root entry;

    can report_profiles with exit;
}

walker follow_request {}

walker un_follow_request {}

walker create_tweet(visit_profile) {
    has content: str;

    can tweet with Profile entry;
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
    has search_query: str = "";
    has results: list = [];

    can load with Profile entry;

    can report_feed with exit;

}

# Pages
cl import from "@jac-client/utils" {Router, Routes, Route, Link, useNavigate, useLocation, useParams}
cl import from .customhooks {useAuth, useFeed, useProfile}
cl import from .components {Header, TweetCard, TweetComposer, CommentInput, CommentList, CommentItem, FormInput, AuthButton, ProfileHeader, MessageAlert, LoadingSpinner, UserCard, UsersList, FollowersList, SearchBar}


cl {

    # Authentication Page Component
    def AuthPage() -> any {
        auth = useAuth();
        isLogin = auth.isLogin;
        username = auth.username;
        password = auth.password;
        confirmPassword = auth.confirmPassword;
        message = auth.message;
        handleFieldChange = auth.handleFieldChange;
        handleAuth = auth.handleAuth;
        toggleMode = auth.toggleMode;

        let titleText = isLogin and "Login" or "Sign Up";
        let buttonText = isLogin and "Login" or "Sign Up";
        let toggleText = "Need an account? Sign up" if isLogin else "Have an account? Login";

        return <div style={{"textAlign": "center", "padding": "50px"}}>
            <h1>Welcome to LittleX</h1>
            <div style={{"maxWidth": "400px", "margin": "0 auto"}}>
                <h2>{titleText}</h2>

                <FormInput
                    type="text"
                    placeholder="Username"
                    value={username}
                    onChange={lambda e: any -> None { handleFieldChange("username", e.target.value); }}
                />

                <FormInput
                    type="password"
                    placeholder="Password"
                    value={password}
                    onChange={lambda e: any -> None { handleFieldChange("password", e.target.value); }}
                />

                {not isLogin and
                    <FormInput
                        type="password"
                        placeholder="Confirm Password"
                        value={confirmPassword}
                        onChange={lambda e: any -> None { handleFieldChange("confirmPassword", e.target.value); }}
                    />
                }

                <AuthButton
                    text={buttonText}
                    onClick={lambda -> None { handleAuth(); }}
                    variant="primary"
                />

                <AuthButton
                    text={toggleText}
                    onClick={lambda -> None { toggleMode(); }}
                    variant="secondary"
                />

                {message and <p style={{"marginTop": "10px", "color": message.includes("success") and "green" or "red"}}>{message}</p>}
            </div>
        </div>;
    }

    # Main Feed Page Component
    def FeedPage() -> any {
        feed = useFeed();
        tweets = feed.tweets;
        profile = feed.profile;
        users = feed.users;
        newTweetContent = feed.newTweetContent;
        commentContent = feed.commentContent;
        activeCommentTweet = feed.activeCommentTweet;
        editingTweet = feed.editingTweet;
        editingComment = feed.editingComment;
        editContent = feed.editContent;
        loading = feed.loading;
        searchQuery = feed.searchQuery;
        isSearching = feed.isSearching;

        handleFieldChange = feed.handleFieldChange;
        handleUIAction = feed.handleUIAction;
        handleLogout = feed.handleLogout;
        handleCreateTweet = feed.handleCreateTweet;
        handleUpdateTweet = feed.handleUpdateTweet;
        handleDeleteTweet = feed.handleDeleteTweet;
        handleToggleLike = feed.handleToggleLike;
        handleAddComment = feed.handleAddComment;
        handleUpdateComment = feed.handleUpdateComment;
        handleDeleteComment = feed.handleDeleteComment;
        handleFollowUser = feed.handleFollowUser;
        handleUnfollowUser = feed.handleUnfollowUser;
        handleSearch = feed.handleSearch;
        handleClearSearch = feed.handleClearSearch;

        if not profile {
            return <LoadingSpinner text="Loading..." />;
        }

        return <div style={{"maxWidth": "678px", "margin": "0 auto", "padding": "20px"}}>
            <Header profile={profile} handleLogout={handleLogout} button={{"name": "Profile", "url": "/profile"}} />

            <SearchBar
                searchQuery={searchQuery}
                isSearching={isSearching}
                handleFieldChange={handleFieldChange}
                handleSearch={handleSearch}
                handleClearSearch={handleClearSearch}
            />

            <TweetComposer
                newTweetContent={newTweetContent}
                handleFieldChange={handleFieldChange}
                handleCreateTweet={handleCreateTweet}
            />

            <div>
                <div>
                    <h3 style={{"color": "#14171a", "marginBottom": "15px"}}>Feed</h3>
                    {loading and <p style={{"textAlign": "center", "color": "#657786"}}>Loading...</p>}
                    {tweets.map(lambda tweet: any -> any {
                        return <TweetCard
                            key={tweet.id}
                            tweet={tweet}
                            profile={profile}
                            commentContent={commentContent}
                            activeCommentTweet={activeCommentTweet}
                            editingTweet={editingTweet}
                            editingComment={editingComment}
                            editContent={editContent}
                            handleFieldChange={handleFieldChange}
                            handleUIAction={handleUIAction}
                            handleUpdateTweet={handleUpdateTweet}
                            handleDeleteTweet={handleDeleteTweet}
                            handleToggleLike={handleToggleLike}
                            handleAddComment={handleAddComment}
                            handleUpdateComment={handleUpdateComment}
                            handleDeleteComment={handleDeleteComment}
                        />;
                    })}
                </div>

                <div style={{"position": "sticky", "top": "20px", "height": "fit-content"}}>
                    <UsersList
                        users={users}
                        currentProfile={profile}
                        handleFollowUser={handleFollowUser}
                        handleUnfollowUser={handleUnfollowUser}
                    />
                </div>
            </div>
        </div>;
    }



    # Profile Page Component
    def ProfilePage() -> any {
        profileState = useProfile();
        profile = profileState.profile;
        users = profileState.users;
        newUsername = profileState.newUsername;
        message = profileState.message;

        handleFieldChange = profileState.handleFieldChange;
        handleLogout = profileState.handleLogout;
        handleProfileUpdate = profileState.handleProfileUpdate;
        handleFollowUser = profileState.handleFollowUser;
        handleUnfollowUser = profileState.handleUnfollowUser;

        if not profile {
            return <LoadingSpinner text="Loading..." />;
        }

        return <div style={{"maxWidth": "678px", "margin": "0 auto", "padding": "20px"}}>
            <Header profile={profile} handleLogout={handleLogout} button={{"name": "Feed", "url": "/feed"}} />

            <div >
                <div style={{"backgroundColor": "white", "border": "1px solid #e1e8ed", "borderRadius": "10px", "padding": "30px"}}>
                    <div style={{"borderBottom": "1px solid #f1f1f1", "paddingBottom": "15px", "marginBottom": "25px"}}>
                        <h1 style={{"margin": "0", "color": "#14171a"}}>Profile Settings</h1>
                    </div>

                    <ProfileHeader profile={profile} />

                    <div>
                        <h3 style={{"color": "#14171a", "marginBottom": "15px"}}>Update Username</h3>
                        <div>
                        <FormInput
                            placeholder="Enter new username"
                            value={newUsername}
                            onChange={lambda e: any -> None { handleFieldChange("newUsername", e.target.value); }}
                        />
                        <AuthButton
                            text="Update Profile"
                            onClick={lambda -> None { handleProfileUpdate(); }}
                            variant="primary"
                        />
                        </div>
                    </div>

                    <MessageAlert message={message} />

                    # <div style={{"marginTop": "30px"}}>
                    #     <FollowersList
                    #         followers={profile.followers}
                    #         users={users}
                    #         currentProfile={profile}
                    #         handleFollowUser={handleFollowUser}
                    #         handleUnfollowUser={handleUnfollowUser}
                    #     />
                    # </div>
                </div>

                # <div>
                #     <UsersList
                #         users={users}
                #         currentProfile={profile}
                #         handleFollowUser={handleFollowUser}
                #         handleUnfollowUser={handleUnfollowUser}
                #     />
                # </div>
            </div>
        </div>;
    }

    def NotFoundPage() -> any {
        return <div style={{"textAlign": "center", "padding": "50px"}}>
            <h2>404 - Page Not Found</h2>
            <Link to="/feed" style={{"marginTop": "20px", "padding": "10px 20px", "backgroundColor": "#1da1f2", "color": "white", "border": "none", "borderRadius": "5px", "textDecoration": "none"}}>Go to Feed</Link>
        </div>;
    }




    # Main App Component with Router
    def app() -> any {
        return <Router>
            <div style={{"fontFamily": "system-ui, -apple-system, sans-serif"}}>
                <div style={{"maxWidth": "1200px", "margin": "0 auto", "padding": "0 1rem"}}>
                    <Routes>
                        <Route path="/auth" element={<AuthPage />} />
                        <Route path="/feed" element={<FeedPage />} />
                        <Route path="/profile" element={<ProfilePage />} />
                        <Route path="/" element={<AuthPage />} />
                        <Route path="*" element={<NotFoundPage />} />
                    </Routes>
                </div>
            </div>
        </Router>;
    }
}
