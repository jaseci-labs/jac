

cl import from "@jac-client/utils" {jacIsLoggedIn, jacLogin, jacSignup, jacLogout}

cl{

    async def login(username: str, password: str) -> dict {
            try {
                result = await jacLogin(username, password);
                console.log("Login Result:", result);
                if result {
                    # localStorage.setItem("username", username);
                    return {"success": True, "data": result, "error": None};
                }
                return {"success": False, "error": "Invalid credentials"};
            } except Exception {
                return {"success": False, "error": "Invalid credentials"};
            }
        }

    async def signup(username: str, password: str, confirmPassword: str) -> dict {
        if password != confirmPassword {
            return {"success": False, "error": "Passwords do not match"};
        }
        try {
            result = await jacSignup(username, password);
            console.log("Signup Result:", result);

            success = False;
            message = "";
            if result && not Array.isArray(result) {
                if result["success"] {
                    # localStorage.setItem("username", username);
                    await updateProfile(username);
                    success = True;
                } elif result["token"] {
                    success = True;
                }
                if result["error"] {
                    message = result["error"];
                }
            } else {
                if result {
                    success = True;
                }
            }
            if success {
                return {"success": True, "data": result, "error": None};
            }
            fallback = message if message != "" else "Unable to create account";
            return {"success": False, "error": fallback};
        } except Exception as err {
            return {"success": False, "error": err.toString()};
        }
    }

    def logout() -> None {
        # localStorage.removeItem("username");
        jacLogout();
    }

    def isAuthenticated() -> bool {
        return jacIsLoggedIn();
    }
    def flattenReports(raw: any) -> list {
            if not raw {
                return [];
            }
            if Array.isArray(raw) {
                accumulator = [];
                raw.forEach(lambda entry: any -> None {
                    if Array.isArray(entry) {
                        entry.forEach(lambda nested: any -> None {
                            if nested {
                                accumulator.push(nested);
                            }
                        });
                    } elif entry {
                        accumulator.push(entry);
                    }
                });
                return accumulator;
            }
            return [raw];
        }


    async def loadFeed(searchQuery: str = "") -> any {
        results = [];
        payload = {};
        if searchQuery {
            payload = {"search_query": searchQuery};
        }

        try {
            response = await __jacSpawn("load_feed", "",payload);

            data = response.reports[0] if response.reports else [];
            results = data.map(lambda tweet:any -> any { return {
                content: tweet.Tweet_Info.content,
                similarity: tweet.similarity,
                comments: tweet.Tweet_Info.comments,
                embedding: tweet.Tweet_Info.embedding,
                id: tweet.Tweet_Info.id,
                likes: tweet.Tweet_Info.likes,
                username: tweet.Tweet_Info.username,
                created_at: tweet.Tweet_Info.created_at
            };});
            return results;

        }except Exception as e {
            console.log("Error loading feed:", e);
            return results;
        }
    }
    async  def createTweet(content: str) -> any {
        try {
            response = await __jacSpawn("create_tweet", "",{"content": content});
            data = response.reports[0] if response.reports else {};
            let profile = await getProfile();
            console.log("Create Tweet Data:", profile.user.username);
            tweetData = {
                "content": data.content || "",
                "embedding": data.embedding || [],
                "id": data.id || "",
                "created_at": data.created_at || "",
                "similarity": [0.1],
                "comments": data.comments || [],
                "likes": data.likes || [],
                "username": data.username || ""
            };

            return tweetData;

        }except Exception as e {
            console.log("Error creating tweet:", e);
            return {};
        }
    }

    async def updateTweet(tweet_id: str, updated_content: str) -> any {
        try {
            response = await __jacSpawn("update_tweet", tweet_id,{"updated_content": updated_content});
            console.log("Update Tweet Response:", response);
            data = response.reports[0] if response.reports else {};

            tweetData = {
                "content": data.content || "",
                "embedding": data.embedding || [],
                "created_at": data.created_at || "",
                "id": tweet_id || "",

            };
            return tweetData;
        }except Exception as e {
            console.log("Error updating tweet:", e);
            return None;
        }
    }

    async def deleteTweet(tweet_id: str, username:str) -> bool {
        try {
            response = await __jacSpawn("remove_tweet", tweet_id,{});
            data = response.reports[0] if response.reports else {};
            result = {
                "id": tweet_id || "",
                "username": username || ""
            };
            return result;
        }except Exception as e {
            console.log("Error deleting tweet:", e);
            return False;
        }
    }

    async def likeTweet(tweet_id: str, username:str) -> any {
        try {
            response = await __jacSpawn("like_tweet", tweet_id,{});
            data = response.reports[0] if response.reports else {};
            result = {
                "id": tweet_id || "",
                "username": username || ""
            };
            return result;

        }except Exception as e {
            console.log("Error liking tweet:", e);
            return False;
        }
    }

    async def removeLike(tweet_id: str, username:str) -> any {
        try {
            response = await __jacSpawn("remove_like", tweet_id,{});
            data = response.reports[0] if response.reports else {};
            result = {
                "id": data.id || "",
                "username": username || ""
            };
            return result;

        }except Exception as e {
            console.log("Error removing like from tweet:", e);
            return {};
        }
    }







    async def getProfile() -> any {
        try {
            response = await __jacSpawn("get_profile", "",{});
            return response.reports[0];
        }except Exception as e {
            console.log("Error getting profile:", e);
            return None;
        }
    }

    async def updateProfile(new_username: str) -> any {
        try {
            response = await __jacSpawn("update_profile", "",{"new_username": new_username});
            return response.reports[0];
        }except Exception as e {
            console.log("Error updating profile:", e);
            return None;
        }
    }

    async def loadAllUserProfiles() -> any {
        profiles = [];
        try {
            response = await __jacSpawn("load_user_profiles", "",{});
            profiles = flattenReports(response.reports) if response.reports else [];
            return profiles;
        }except Exception as e {
            console.log("Error loading user profiles:", e);
            return profiles;
        }
    }

    async def followUser(user_id: str) -> any {
        try {
            response = await __jacSpawn("follow_request", user_id,{});
            data = response.reports[0] if response.reports else {};
            console.log("Follow User Data:", data);
           return data;

        }except Exception as e {
            console.log("Error following user:", e);
            return {};
        }
    }

    async def unFollowUser(user_id: str) -> any {
        try {
            response = await __jacSpawn("un_follow_request", user_id,{});
            data = response.reports[0] if response.reports else {};
            console.log("Unfollow User Data:", data);
           return data;

        }except Exception as e {
            console.log("Error unfollowing user:", e);
            return {};
        }
    }

    async def addComment(tweet_id: str, content: str) -> any {
        try {
            response = await __jacSpawn("comment_tweet", tweet_id,{"content": content});
            data = response.reports[0] if response.reports else {};
            console.log("Add Comment Data:", data);
           return data;

        }except Exception as e {
            console.log("Error adding comment:", e);
            return {};
        }
    }

    async def updateComment(comment_id: str, updated_content: str) -> any {
        try {
            response = await __jacSpawn("update_comment", comment_id,{"updated_content": updated_content});
            data = response.reports[0] if response.reports else {};
            console.log("Update Comment Data:", data);
           return data;

        }except Exception as e {
            console.log("Error updating comment:", e);
            return {};
        }
    }

    async def deleteComment(comment_id: str) -> bool {
        try {
            response = await __jacSpawn("remove_comment", comment_id,{});
            console.log("Delete Comment Response:", response);
            return True;

        }except Exception as e {
            console.log("Error deleting comment:", e);
            return False;
        }
    }

}
