cl import from "@jac-client/utils" {Link}

cl {
    def Header(props:dict) -> any {
        profile = props.profile;
        handleLogout= props.handleLogout;
        backButton = props.button;

        return <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "borderBottom": "2px solid #1da1f2", "paddingBottom": "15px", "marginBottom": "20px"}}>
                <div>
                    <h1 style={{"color": "#1da1f2", "margin": "0"}}>LittleX</h1>
                    <p style={{"margin": "5px 0", "color": "#657786"}}>Welcome back, @{profile.username}!</p>
                </div>
                <div>
                    <Link to={backButton.url} style={{"margin": "0 10px", "padding": "8px 15px", "backgroundColor": "#17a2b8", "color": "white", "border": "none", "borderRadius": "5px", "textDecoration": "none"}}>{backButton.name}</Link>
                    <button onClick={lambda -> None { handleLogout(); }} style={{"padding": "8px 15px", "backgroundColor": "#dc3545", "color": "white", "border": "none", "borderRadius": "5px"}}>Logout</button>
                </div>
            </div>;
    }

    def TweetCard(props:dict) -> any {
        tweet = props.tweet;
        profile = props.profile;
        commentContent = props.commentContent;
        activeCommentTweet = props.activeCommentTweet;
        editingTweet = props.editingTweet;
        editingComment = props.editingComment;
        editContent = props.editContent;

        handleFieldChange = props.handleFieldChange;
        handleUIAction = props.handleUIAction;
        handleUpdateTweet = props.handleUpdateTweet;
        handleDeleteTweet = props.handleDeleteTweet;
        handleToggleLike = props.handleToggleLike;
        handleAddComment = props.handleAddComment;
        handleUpdateComment = props.handleUpdateComment;
        handleDeleteComment = props.handleDeleteComment;

        let isLiked = tweet.likes and tweet.likes.includes(profile.username);
        let showCommentInput = activeCommentTweet == tweet.id;

        return <div key={tweet.id} style={{"border": "1px solid #e1e8ed", "borderRadius": "10px", "margin": "15px 0", "padding": "15px", "backgroundColor": "white"}}>
            <div style={{"borderBottom": "1px solid #f1f1f1", "paddingBottom": "10px", "marginBottom": "10px"}}>
                <strong style={{"color": "#1da1f2"}}>@{tweet.username}</strong>
                <small style={{"color": "#657786", "marginLeft": "10px"}}>{tweet.created_at}</small>
            </div>

            {editingTweet == tweet.id and
                <div style={{"marginBottom": "10px"}}>
                    <textarea
                        value={editContent}
                        onChange={lambda e: any -> None { handleFieldChange("editContent", e.target.value); }}
                        style={{"box-sizing": "border-box","width": "100%", "padding": "8px", "border": "1px solid #e1e8ed", "borderRadius": "5px"}}
                    />
                    <div style={{"marginTop": "5px"}}>
                        <button onClick={lambda -> None { handleUpdateTweet(tweet.id, editContent); }} style={{"marginRight": "10px", "padding": "5px 10px", "backgroundColor": "#1da1f2", "color": "white", "border": "none", "borderRadius": "5px"}}>Save</button>
                        <button onClick={lambda -> None { handleUIAction("setEditingTweet", None); }} style={{"padding": "5px 10px", "backgroundColor": "#f8f9fa", "border": "1px solid #e1e8ed", "borderRadius": "5px"}}>Cancel</button>
                    </div>
                </div>
            or
                <p style={{"margin": "10px 0", "fontSize": "16px", "lineHeight": "1.4"}}>{tweet.content}</p>
            }

            <div style={{"display": "flex", "alignItems": "center", "gap": "15px", "marginTop": "10px", "flexWrap": "wrap"}}>
                <button onClick={lambda -> None { handleToggleLike(tweet.id); }}
                    style={{"padding": "5px 15px", "border": "none", "borderRadius": "20px", "backgroundColor": isLiked and "#ff3040" or "#f8f9fa", "color": isLiked and "white" or "#657786"}}>
                    {isLiked and "♥" or "♡"} {tweet.likes and tweet.likes.length or 0}
                </button>

                <button onClick={lambda -> None {
                    if showCommentInput {
                        handleUIAction("setActiveCommentTweet", "");
                    } else {
                        handleUIAction("setActiveCommentTweet", tweet.id);
                        handleFieldChange("commentContent", "");
                    }
                }} style={{"padding": "5px 15px", "border": "none", "borderRadius": "20px", "backgroundColor": showCommentInput and "#1da1f2" or "#f8f9fa", "color": showCommentInput and "white" or "#657786"}}>
                    💬 {tweet.comments and tweet.comments.length or 0}
                </button>

                {tweet.username == profile.username and
                    <div style={{"marginLeft": "auto", "display": "flex", "gap": "5px"}}>
                        <button onClick={lambda -> None {
                            handleUIAction("setEditingTweet", tweet.id);
                            handleFieldChange("editContent", tweet.content);
                        }} style={{"padding": "5px 10px", "backgroundColor": "#17a2b8", "color": "white", "border": "none", "borderRadius": "5px"}}>
                            Edit
                        </button>
                        <button onClick={lambda -> None { handleDeleteTweet(tweet.id); }}
                            style={{"padding": "5px 10px", "backgroundColor": "#dc3545", "color": "white", "border": "none", "borderRadius": "5px"}}>
                            Delete
                        </button>
                    </div>
                }
            </div>

            {showCommentInput and
                <CommentInput
                    commentContent={commentContent}
                    tweetId={tweet.id}
                    handleFieldChange={handleFieldChange}
                    handleAddComment={handleAddComment}
                />
            }

            {tweet.comments and tweet.comments.length > 0 and
                <CommentList
                    comments={tweet.comments}
                    profile={profile}
                    editingComment={editingComment}
                    editContent={editContent}
                    handleFieldChange={handleFieldChange}
                    handleUIAction={handleUIAction}
                    handleUpdateComment={handleUpdateComment}
                    handleDeleteComment={handleDeleteComment}
                    tweetId={tweet.id}
                />
            }
        </div>;
    }

    def CommentInput(props:dict) -> any {
        commentContent = props.commentContent;
        tweetId = props.tweetId;
        handleFieldChange = props.handleFieldChange;
        handleAddComment = props.handleAddComment;

        return <div style={{"marginTop": "15px", "paddingTop": "15px", "borderTop": "1px solid #f1f1f1"}}>
            <div style={{"display": "flex", "gap": "10px", "marginBottom": "15px"}}>
                <input
                    type="text"
                    placeholder="Add a comment..."
                    value={commentContent}
                    onChange={lambda e: any -> None { handleFieldChange("commentContent", e.target.value); }}
                    style={{ "box-sizing": "border-box","flex": "1", "padding": "8px", "border": "1px solid #e1e8ed", "borderRadius": "20px"}}
                />
                <button onClick={lambda -> None {
                    handleAddComment(tweetId, commentContent);
                }} style={{"padding": "8px 15px", "backgroundColor": "#1da1f2", "color": "white", "border": "none", "borderRadius": "20px"}}>
                    Post
                </button>
            </div>
        </div>;
    }

    def CommentList(props:dict) -> any {
        comments = props.comments;
        profile = props.profile;
        editingComment = props.editingComment;
        editContent = props.editContent;
        handleFieldChange = props.handleFieldChange;
        handleUIAction = props.handleUIAction;
        handleUpdateComment = props.handleUpdateComment;
        handleDeleteComment = props.handleDeleteComment;
        tweetId = props.tweetId;

        return <div style={{"marginTop": "15px", "paddingTop": "15px", "borderTop": "1px solid #f1f1f1"}}>
            <h4 style={{"margin": "0 0 10px 0", "color": "#14171a", "fontSize": "16px"}}>Comments ({comments.length})</h4>

            {comments.map(lambda comment: any -> any {
                return <CommentItem
                    key={comment.id}
                    comment={comment}
                    profile={profile}
                    editingComment={editingComment}
                    editContent={editContent}
                    handleFieldChange={handleFieldChange}
                    handleUIAction={handleUIAction}
                    handleUpdateComment={handleUpdateComment}
                    handleDeleteComment={handleDeleteComment}
                    tweetId={tweetId}
                />;
            })}
        </div>;
    }

    def CommentItem(props:dict) -> any {
        comment = props.comment;
        profile = props.profile;
        editingComment = props.editingComment;
        editContent = props.editContent;
        handleFieldChange = props.handleFieldChange;
        handleUIAction = props.handleUIAction;
        handleUpdateComment = props.handleUpdateComment;
        handleDeleteComment = props.handleDeleteComment;
        tweetId = props.tweetId;

        return <div key={comment.id} style={{"border": "1px solid #f1f1f1", "borderRadius": "8px", "padding": "10px", "margin": "8px 0", "backgroundColor": "#fafafa"}}>
            <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "flex-start"}}>
                <div style={{"flex": "1"}}>
                    <strong style={{"color": "#1da1f2", "fontSize": "14px"}}>@{comment.username}</strong>

                    {editingComment == comment.id and
                        <div style={{"marginTop": "5px"}}>
                            <input
                                type="text"
                                value={editContent}
                                onChange={lambda e: any -> None { handleFieldChange("editContent", e.target.value); }}
                                style={{"box-sizing": "border-box","width": "100%", "padding": "5px", "border": "1px solid #e1e8ed", "borderRadius": "5px"}}
                            />
                            <div style={{"marginTop": "5px"}}>
                                <button onClick={lambda -> None { handleUpdateComment(comment.id, editContent); }} style={{"marginRight": "5px", "padding": "3px 8px", "backgroundColor": "#1da1f2", "color": "white", "border": "none", "borderRadius": "3px", "fontSize": "12px"}}>Save</button>
                                <button onClick={lambda -> None { handleUIAction("setEditingComment", None); }} style={{"padding": "3px 8px", "backgroundColor": "#f8f9fa", "border": "1px solid #e1e8ed", "borderRadius": "3px", "fontSize": "12px"}}>Cancel</button>
                            </div>
                        </div>
                    or
                        <p style={{"margin": "5px 0 0 0", "color": "#14171a", "fontSize": "14px"}}>{comment.content}</p>
                    }
                </div>

                {comment.username == profile.username and
                    <div style={{"display": "flex", "gap": "5px"}}>
                        <button onClick={lambda -> None {
                            handleUIAction("setEditingComment", comment.id);
                            handleFieldChange("editContent", comment.content);
                        }} style={{"padding": "2px 6px", "backgroundColor": "#17a2b8", "color": "white", "border": "none", "borderRadius": "3px", "fontSize": "11px"}}>
                            Edit
                        </button>
                        <button onClick={lambda -> None { handleDeleteComment(comment.id, tweetId); }}
                            style={{"padding": "2px 6px", "backgroundColor": "#dc3545", "color": "white", "border": "none", "borderRadius": "3px", "fontSize": "11px"}}>
                            Delete
                        </button>
                    </div>
                }
            </div>
        </div>;
    }

    def TweetComposer(props:dict) -> any {
        newTweetContent = props.newTweetContent;
        handleFieldChange = props.handleFieldChange;
        handleCreateTweet = props.handleCreateTweet;

        return <div style={{"backgroundColor": "white", "border": "1px solid #e1e8ed", "borderRadius": "10px", "padding": "20px", "marginBottom": "20px"}}>
            <h3 style={{"margin": "0 0 15px 0", "color": "#14171a"}}>What's happening?</h3>
            <textarea
                placeholder="Share your thoughts..."
                value={newTweetContent}
                onChange={lambda e: any -> None { handleFieldChange("newTweetContent", e.target.value); }}
                style={{"box-sizing": "border-box","width": "100%", "height": "80px", "padding": "12px", "border": "1px solid #e1e8ed", "borderRadius": "5px", "resize": "vertical"}}
            />
            <div style={{"textAlign": "right", "marginTop": "10px"}}>
                <button onClick={lambda -> None { handleCreateTweet(); }}
                    style={{"padding": "10px 25px", "backgroundColor": "#1da1f2", "color": "white", "border": "none", "borderRadius": "25px", "fontSize": "16px", "fontWeight": "bold"}}>
                    Tweet
                </button>
            </div>
        </div>;
    }

    def FormInput(props:dict) -> any {
        type = props.type;
        placeholder = props.placeholder;
        value = props.value;
        onChange = props.onChange;

        let inputStyle = {"box-sizing": "border-box","width": "100%", "padding": "10px", "margin": "5px 0", "border": "1px solid #ccc", "borderRadius": "5px"};
        return <input
            type={"password" if props.type == "password" else "text" }
            placeholder={placeholder}
            value={value}
            onChange={onChange}
            style={inputStyle}
        />;
    }

    def AuthButton(props:dict) -> any {
        text = props.text;
        onClick = props.onClick;
        variant = props.variant or "primary";

        let buttonStyle = {};

        if variant == "primary" {
            buttonStyle = {"width": "100%", "padding": "10px", "margin": "10px 0", "border": "none", "borderRadius": "5px", "fontSize": "16px", "cursor": "pointer", "backgroundColor": "#007bff", "color": "white"};
        } else {
            buttonStyle = {"width": "100%", "padding": "10px", "margin": "10px 0", "border": "1px solid #ccc", "borderRadius": "5px", "fontSize": "16px", "cursor": "pointer", "backgroundColor": "#f8f9fa", "color": "#333"};
        }

        return <button onClick={onClick} style={buttonStyle}>
            {text}
        </button>;
    }

    def ProfileHeader(props:dict) -> any {
        profile = props.profile;

        return <div style={{"textAlign": "center", "marginBottom": "25px"}}>
            <div style={{"width": "80px", "height": "80px", "borderRadius": "50%", "backgroundColor": "#1da1f2", "color": "white", "display": "inline-flex", "alignItems": "center", "justifyContent": "center", "fontSize": "36px", "marginBottom": "15px"}}>
                {profile.username and profile.username[0].upper() or "?"}
            </div>
            <h2 style={{"margin": "0", "color": "#14171a"}}>@{profile.username}</h2>
            <p style={{"margin": "5px 0", "color": "#657786"}}>Followers: {profile.followers and profile.followers.length or 0}</p>
        </div>;
    }

    def MessageAlert(props:dict) -> any {
        message = props.message;

        if not message {
            return <div></div>;
        }

        let isSuccess = message.includes("success");

        return <div style={{"marginTop": "15px", "padding": "10px", "borderRadius": "5px", "backgroundColor": isSuccess and "#d4edda" or "#f8d7da", "color": isSuccess and "#155724" or "#721c24", "textAlign": "center"}}>
            {message}
        </div>;
    }

    def LoadingSpinner(props:dict) -> any {
        text = props.text or "Loading...";

        return <div style={{"textAlign": "center", "padding": "50px"}}>
            <h2>{text}</h2>
        </div>;
    }

    def UserCard(props:dict) -> any {
        user = props.user;
        currentProfile = props.currentProfile;
        handleFollowUser = props.handleFollowUser;
        handleUnfollowUser = props.handleUnfollowUser;

        # Check if current user is following this user
        let isFollowing = currentProfile.followers and currentProfile.followers.includes(user.username);
        let isCurrentUser = user.username == currentProfile.username;

        return <div style={{"border": "1px solid #e1e8ed", "borderRadius": "10px", "padding": "15px", "margin": "10px 0", "backgroundColor": "white", "display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
            <div style={{"display": "flex", "alignItems": "center", "gap": "15px"}}>
                <div style={{"width": "50px", "height": "50px", "borderRadius": "50%", "backgroundColor": "#1da1f2", "color": "white", "display": "flex", "alignItems": "center", "justifyContent": "center", "fontSize": "24px", "fontWeight": "bold"}}>
                    {user.username and user.username[0].upper() or "?"}
                </div>
                <div>
                    <h3 style={{"margin": "0", "color": "#14171a", "fontSize": "18px"}}>@{user.username}</h3>
                    <p style={{"margin": "5px 0 0 0", "color": "#657786", "fontSize": "14px"}}>
                        Followers: {user.followers and user.followers.length or 0}
                    </p>
                </div>
            </div>

            {not isCurrentUser and
                <div>
                    {isFollowing and
                        <button
                            onClick={lambda -> None { handleUnfollowUser(user.id); }}
                            style={{"padding": "8px 20px", "backgroundColor": "#f8f9fa", "color": "#1da1f2", "border": "2px solid #1da1f2", "borderRadius": "20px", "fontSize": "14px", "fontWeight": "bold", "cursor": "pointer"}}>
                            Following
                        </button>
                    or
                        <button
                            onClick={lambda -> None { handleFollowUser(user.id); }}
                            style={{"padding": "8px 20px", "backgroundColor": "#1da1f2", "color": "white", "border": "none", "borderRadius": "20px", "fontSize": "14px", "fontWeight": "bold", "cursor": "pointer"}}>
                            Follow
                        </button>
                    }
                </div>
            }
        </div>;
    }

    def UsersList(props:dict) -> any {
        users = props.users;
        currentProfile = props.currentProfile;
        handleFollowUser = props.handleFollowUser;
        handleUnfollowUser = props.handleUnfollowUser;

        if not users or users.length == 0 {
            return <div style={{"textAlign": "center", "padding": "30px", "color": "#657786"}}>
                <p>No users found</p>
            </div>;
        }

        return <div style={{"marginTop": "20px"}}>
            <h3 style={{"color": "#14171a", "marginBottom": "15px"}}>All Users ({users.length})</h3>
            {users.map(lambda user: any -> any {
                return <UserCard
                    key={user.id}
                    user={user}
                    currentProfile={currentProfile}
                    handleFollowUser={handleFollowUser}
                    handleUnfollowUser={handleUnfollowUser}
                />;
            })}
        </div>;
    }

    def FollowersList(props:dict) -> any {
        followers = props.followers;
        users = props.users;
        currentProfile = props.currentProfile;
        handleFollowUser = props.handleFollowUser;
        handleUnfollowUser = props.handleUnfollowUser;

        if not followers or followers.length == 0 {
            return <div style={{"textAlign": "center", "padding": "30px", "color": "#657786", "backgroundColor": "white", "border": "1px solid #e1e8ed", "borderRadius": "10px"}}>
                <p>No followers yet</p>
            </div>;
        }

        # Filter users to only show followers
        let followerUsers = users.filter(lambda user: any -> bool {
            return followers.includes(user.username);
        });

        return <div style={{"marginTop": "20px"}}>
            <h3 style={{"color": "#14171a", "marginBottom": "15px"}}>Your Followers ({followerUsers.length})</h3>
            {followerUsers.map(lambda user: any -> any {
                return <UserCard
                    key={user.id}
                    user={user}
                    currentProfile={currentProfile}
                    handleFollowUser={handleFollowUser}
                    handleUnfollowUser={handleUnfollowUser}
                />;
            })}
        </div>;
    }

    def SearchBar(props:dict) -> any {
        searchQuery = props.searchQuery;
        isSearching = props.isSearching;
        handleFieldChange = props.handleFieldChange;
        handleSearch = props.handleSearch;
        handleClearSearch = props.handleClearSearch;

        return <div style={{"backgroundColor": "white", "border": "1px solid #e1e8ed", "borderRadius": "10px", "padding": "15px", "marginBottom": "20px"}}>
            <div style={{"display": "flex", "gap": "10px", "alignItems": "center"}}>
                <div style={{"flex": "1", "position": "relative"}}>
                    <input
                        type="text"
                        placeholder="Search tweets using TF-IDF similarity..."
                        value={searchQuery}
                        onChange={lambda e: any -> None { handleFieldChange("searchQuery", e.target.value); }}
                        onKeyPress={lambda e: any -> None {
                            if e.key == "Enter" {
                                handleSearch();
                            }
                        }}
                        style={{
                            "box-sizing": "border-box", "width": "100%", "padding": "12px 15px", "paddingLeft": "40px", "border": "1px solid #e1e8ed", "borderRadius": "25px", "fontSize": "14px", "outline": "none", "transition": "border-color 0.2s"
                        }}
                    />
                    <span style={{
                        "position": "absolute", "left": "15px", "top": "50%", "transform": "translateY(-50%)", "color": "#657786", "fontSize": "16px"
                    }}>🔍</span>
                </div>

                <button
                    onClick={lambda -> None { handleSearch(); }}
                    style={{
                        "padding": "12px 24px", "backgroundColor": "#1da1f2", "color": "white", "border": "none", "borderRadius": "25px", "fontSize": "14px", "fontWeight": "bold", "cursor": "pointer", "transition": "background-color 0.2s", "whiteSpace": "nowrap"
                    }}
                >
                    Search
                </button>

                {isSearching and
                    <button
                        onClick={lambda -> None { handleClearSearch(); }}
                        style={{
                            "padding": "12px 24px", "backgroundColor": "#657786", "color": "white", "border": "none", "borderRadius": "25px", "fontSize": "14px", "fontWeight": "bold", "cursor": "pointer", "transition": "background-color 0.2s", "whiteSpace": "nowrap"
                        }}
                    >
                        Clear
                    </button>
                }
            </div>

            {isSearching and
                <div style={{"marginTop": "10px", "padding": "8px 15px", "backgroundColor": "#e8f5fe", "borderRadius": "5px", "fontSize": "13px", "color": "#1da1f2"}}>
                    🔎 Showing search results of: <strong>{searchQuery}</strong>
                </div>
            }
        </div>;
    }
}
