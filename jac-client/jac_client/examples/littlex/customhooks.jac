cl import from .service {createTweet, updateTweet, deleteTweet, likeTweet, removeLike, loadFeed, getProfile, updateProfile,loadAllUserProfiles,addComment, updateComment,deleteComment,followUser,unFollowUser, login,signup, isAuthenticated, logout}
cl import from react {useState, useEffect}
cl import from "@jac-client/utils" {useNavigate}


cl{

       def useAuth() -> dict {
        let [isLogin, setIsLogin] = useState(True);
        let [username, setUsername] = useState("");
        let [password, setPassword] = useState("");
        let [confirmPassword, setConfirmPassword] = useState("");
        let [message, setMessage] = useState("");
        navigate = useNavigate();

        def handleFieldChange(field: str, value: str) -> None {
            if field == "username" {
                setUsername(value);
            } elif field == "password" {
                setPassword(value);
            } elif field == "confirmPassword" {
                setConfirmPassword(value);
            }
        }

        async def handleAuth() {
            setMessage("");
            if not username or not password {
                setMessage("Please fill in all fields");
                return;
            }

            if not isLogin and password != confirmPassword {
                setMessage("Passwords do not match");
                return;
            }

            if isLogin {
                result = await login(username, password);
                if result and result["success"] {
                    setMessage("Login successful!");
                    navigate("/feed");
                } else {
                    setMessage("Login failed. Please try again.");
                }
            } else {
                result = await signup(username, password, confirmPassword);
                if result and result["success"] {
                    setMessage("Signup successful! You can now login.");
                    setIsLogin(True);
                } else {
                    setMessage("Signup failed. Please try again.");
                }
            }
        }

        def toggleMode() -> None {
            setIsLogin(not isLogin);
            setMessage("");
        }

        return {
            "isLogin": isLogin,
            "username": username,
            "password": password,
            "confirmPassword": confirmPassword,
            "message": message,
            "handleFieldChange": handleFieldChange,
            "handleAuth": handleAuth,
            "toggleMode": toggleMode
        };
    }

       def useFeed() -> dict {
        let [tweets, setTweets] = useState([]);
        let [profile, setProfile] = useState(None);
        let [users, setUsers] = useState([]);
        let [newTweetContent, setNewTweetContent] = useState("");
        let [commentContent, setCommentContent] = useState("");
        let [activeCommentTweet, setActiveCommentTweet] = useState("");
        let [editingTweet, setEditingTweet] = useState(None);
        let [editingComment, setEditingComment] = useState(None);
        let [editContent, setEditContent] = useState("");
        let [loading, setLoading] = useState(False);
        let [searchQuery, setSearchQuery] = useState("");
        let [isSearching, setIsSearching] = useState(False);
        navigate = useNavigate();

        # Initialize data on mount
        useEffect(lambda -> None {
            async def loadData() {
                setLoading(True);
                try {
                    userProfile = await getProfile();
                    if userProfile and userProfile.user {
                        setProfile({
                            "id": userProfile.user.id,
                            "username": userProfile.user.username,
                            "followers": userProfile.followers if userProfile.followers else []
                        });
                    }

                    feedTweets = await loadFeed();
                    setTweets(feedTweets or []);

                    allUsers = await loadAllUserProfiles();
                    setUsers(allUsers or []);
                } except Exception as e {
                    console.log("Error loading data:", e);
                    navigate("/auth");
                }
                setLoading(False);
            }

            loadData();
        }, []);

        # Field change handlers
        def handleFieldChange(field: str, value: str) -> None {
            if field == "newTweetContent" {
                setNewTweetContent(value);
            } elif field == "commentContent" {
                setCommentContent(value);
            } elif field == "editContent" {
                setEditContent(value);
            } elif field == "searchQuery" {
                setSearchQuery(value);
            }
        }

        def handleUIAction(action: str, payload: any) -> None {
            if action == "setActiveCommentTweet" {
                setActiveCommentTweet(payload);
            } elif action == "setEditingTweet" {
                setEditingTweet(payload);
            } elif action == "setEditingComment" {
                setEditingComment(payload);
            } elif action == "clearCommentInput" {
                setCommentContent("");
                setActiveCommentTweet("");
            }
        }

        # Business logic functions
        async def handleLogout() {
            await logout();
            navigate("/auth");
        }

        async def handleCreateTweet() {
            if not newTweetContent.trim() {
                return;
            }

            newTweet = await createTweet(newTweetContent);
            if newTweet {
                let updatedTweets = tweets.concat([newTweet]);
                setTweets(updatedTweets);
                setNewTweetContent("");
            }
        }

        async def handleUpdateTweet(tweetId: str, updatedContent: str) {
            updatedTweet = await updateTweet(tweetId, updatedContent);
            if updatedTweet {
                let updateTweets = tweets.map(lambda tweet: any -> any {
                    if tweet.id == tweetId {
                        return {
                            **tweet,
                            embedding: updatedTweet.embedding,
                            content: updatedTweet.content,
                            created_at: updatedTweet.created_at
                        };
                    }
                    return {**tweet};
                });
                setTweets(updateTweets);
                setEditingTweet(None);
            }
        }

        async def handleDeleteTweet(tweetId: str) {
            success = await deleteTweet(tweetId);
            if success {
                let updatedTweets = tweets.filter(lambda t: any -> bool { return t.id != tweetId; });
                setTweets(updatedTweets);
            }
        }

        async def handleToggleLike(tweetId: str) {
            if not profile {
                return;
            }

            tweet = tweets.find(lambda t: any -> bool { return t.id == tweetId; });
            if not tweet { return; }

            isLiked = tweet.likes and tweet.likes.some(lambda u: any -> bool {
                return u == profile.username;
            });

            if isLiked {
                await removeLike(tweetId, profile.username);
                tweet.likes = tweet.likes.filter(lambda u: any -> bool {
                    return u != profile.username;
                });
            } else {
                await likeTweet(tweetId, profile.username);
                if not tweet.likes {
                    tweet.likes = [profile.username];
                } else {
                    tweet.likes = tweet.likes.concat([profile.username]);
                }
            }

            let updatedTweets = tweets.map(lambda t: any -> any {
                if t.id == tweetId {
                    return tweet;
                }
                return {**t};
            });

            setTweets(updatedTweets);
        }

        async def handleAddComment(tweetId: str, content: str) {
            if not content.trim() {
                return;
            }

            newComment = await addComment(tweetId, content);
            if newComment {
                let updateTweets = tweets.map(lambda tweet: any -> any {
                    if tweet.id == tweetId {
                        let updatedComments = tweet.comments.concat([{
                            "id": newComment.id,
                            "username": profile.username,
                            "content": newComment.content
                        }]);
                        return {
                            **tweet,
                            comments: updatedComments,

                        };
                    }
                    return {**tweet};
                });
                setTweets(updateTweets);
                setCommentContent("");
                setActiveCommentTweet("");
            }
        }

        async def handleUpdateComment(commentId: str, updatedContent: str) {
            updatedComment = await updateComment(commentId, updatedContent);
            if updatedComment {
                let updateTweets = tweets.map(lambda tweet: any -> any {
                    let updatedComments = tweet.comments.map(lambda comment: any -> any {
                        if comment.id == commentId {
                            return {
                                id: comment.id,
                                username: comment.username,
                                content: updatedComment.content
                            };
                        }
                        return {**comment};
                    });
                    return {
                        **tweet,
                        comments: updatedComments

                    };
                });
                setTweets(updateTweets);
                setEditingComment(None);
            }
        }

        async def handleDeleteComment(commentId: str, tweetId: str) {
            success = await deleteComment(commentId);
            if success {
                let updateTweets = tweets.map(lambda tweet: any -> any {
                    if tweet.id == tweetId {
                        let updatedComments = tweet.comments.filter(lambda comment: any -> bool {
                            return comment.id != commentId;
                        });
                        return {
                            **tweet,
                            comments: updatedComments,
                            similarity: tweet.similarity

                        };
                    }
                    return {**tweet};
                });
                setTweets(updateTweets);
            }
        }

        async def handleFollowUser(userId: str) {
            await followUser(userId);
            allUsers = await loadAllUserProfiles();
            setUsers(allUsers or []);

            userProfile = await getProfile();
            if userProfile and userProfile.user {
                setProfile({
                    "id": userProfile.user.id,
                    "username": userProfile.user.username,
                    "followers": userProfile.followers if userProfile.followers else []
                });
            }
        }

        async def handleUnfollowUser(userId: str) {
            await unFollowUser(userId);
            allUsers = await loadAllUserProfiles();
            setUsers(allUsers or []);

            userProfile = await getProfile();
            if userProfile and userProfile.user {
                setProfile({
                    "id": userProfile.user.id,
                    "username": userProfile.user.username,
                    "followers": userProfile.followers if userProfile.followers else []
                });
            }
        }

        async def handleSearch() {
            if not searchQuery.trim() {
                # If search is empty, reload all tweets
                await handleClearSearch();
                return;
            }

            setIsSearching(True);
            setLoading(True);

            try {
                searchResults = await loadFeed(searchQuery);
                setTweets(searchResults or []);
            } except Exception as e {
                console.log("Error searching tweets:", e);
            }

            setLoading(False);
        }

        async def handleClearSearch() {
            setSearchQuery("");
            setIsSearching(False);
            setLoading(True);

            try {
                feedTweets = await loadFeed("");
                setTweets(feedTweets or []);
            } except Exception as e {
                console.log("Error loading feed:", e);
            }

            setLoading(False);
        }

        return {
            # State
            "tweets": tweets,
            "profile": profile,
            "users": users,
            "newTweetContent": newTweetContent,
            "commentContent": commentContent,
            "activeCommentTweet": activeCommentTweet,
            "editingTweet": editingTweet,
            "editingComment": editingComment,
            "editContent": editContent,
            "loading": loading,
            "searchQuery": searchQuery,
            "isSearching": isSearching,

            # Handlers
            "handleFieldChange": handleFieldChange,
            "handleUIAction": handleUIAction,
            "handleLogout": handleLogout,
            "handleCreateTweet": handleCreateTweet,
            "handleUpdateTweet": handleUpdateTweet,
            "handleDeleteTweet": handleDeleteTweet,
            "handleToggleLike": handleToggleLike,
            "handleAddComment": handleAddComment,
            "handleUpdateComment": handleUpdateComment,
            "handleDeleteComment": handleDeleteComment,
            "handleFollowUser": handleFollowUser,
            "handleUnfollowUser": handleUnfollowUser,
            "handleSearch": handleSearch,
            "handleClearSearch": handleClearSearch
        };
    }

    # Custom Profile Hook
    def useProfile() -> dict {
        let [profile, setProfile] = useState(None);
        let [users, setUsers] = useState([]);
        let [newUsername, setNewUsername] = useState("");
        let [message, setMessage] = useState("");
        navigate = useNavigate();

        # Initialize profile data on mount
        useEffect(lambda -> None {
            async def loadProfile() {
                try {
                    userProfile = await getProfile();
                    if userProfile and userProfile.user {
                        setProfile({
                            "id": userProfile.user.id,
                            "username": userProfile.user.username,
                            "followers": userProfile.followers if userProfile.followers else []
                        });
                        setNewUsername(userProfile.user.username);
                    }

                    allUsers = await loadAllUserProfiles();
                    setUsers(allUsers or []);
                } except Exception as e {
                    console.log("Error loading profile:", e);
                    navigate("/auth");
                }
            }

            loadProfile();
        }, []);

        # Field change handler
        def handleFieldChange(field: str, value: str) -> None {
            if field == "newUsername" {
                setNewUsername(value);
            }
        }

        # Business logic functions
        async def handleLogout() {
            await logout();
            navigate("/auth");
        }

        async def handleProfileUpdate() {
            if not newUsername.trim() {
                setMessage("Username cannot be empty");
                return;
            }

            if newUsername == profile.username {
                setMessage("Please enter a different username");
                return;
            }

            try {
                await updateProfile(newUsername);
                setProfile({
                    "id": profile.id,
                    "username": newUsername,
                    "followers": profile.followers
                });
                setMessage("Profile updated successfully!");
            } except Exception as e {
                setMessage("Failed to update profile");
            }
        }

        async def handleFollowUser(userId: str) {
            await followUser(userId);
            # Reload users and profile to update follow status
            allUsers = await loadAllUserProfiles();
            setUsers(allUsers or []);

            userProfile = await getProfile();
            if userProfile and userProfile.user {
                setProfile({
                    "id": userProfile.user.id,
                    "username": userProfile.user.username,
                    "followers": userProfile.followers if userProfile.followers else []
                });
            }
        }

        async def handleUnfollowUser(userId: str) {
            await unFollowUser(userId);
            # Reload users and profile to update follow status
            allUsers = await loadAllUserProfiles();
            setUsers(allUsers or []);

            userProfile = await getProfile();
            if userProfile and userProfile.user {
                setProfile({
                    "id": userProfile.user.id,
                    "username": userProfile.user.username,
                    "followers": userProfile.followers if userProfile.followers else []
                });
            }
        }

        return {
            # State
            "profile": profile,
            "users": users,
            "newUsername": newUsername,
            "message": message,

            # Handlers
            "handleFieldChange": handleFieldChange,
            "handleLogout": handleLogout,
            "handleProfileUpdate": handleProfileUpdate,
            "handleFollowUser": handleFollowUser,
            "handleUnfollowUser": handleUnfollowUser
        };
    }
}
