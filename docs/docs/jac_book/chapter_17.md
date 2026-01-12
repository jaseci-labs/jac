# Chapter 17: Testing and Debugging

!!! tip "Quick Reference"
    For a condensed testing and debugging guide, see the [Testing & Debugging Reference](../testing-debugging/index.md) which covers all `jac test`, `jac debug`, and `jac dot` options.

In this chapter, we'll explore Jac's built-in testing framework and debugging strategies for spatial applications. We'll build a comprehensive test suite for a social media system that demonstrates testing nodes, edges, walkers, and complex graph operations.

!!! info "What You'll Learn"
    - Jac's built-in testing framework with `.test.jac` files
    - Testing spatial applications with nodes, edges, and walkers
    - Debugging techniques for graph traversal and walker behavior
    - Performance testing and optimization strategies
    - Test-driven development patterns for OSP

---

## Jac's Built-in Testing Framework

Jac provides a powerful testing framework that automatically discovers and runs tests. When you run `jac test myfile.jac`, it automatically looks for `myfile.test.jac` and executes all test blocks within it.

!!! success "Testing Framework Benefits"
    - **Automatic Discovery**: `.test.jac` files are automatically found and executed
    - **Graph-Aware Testing**: Native support for testing spatial relationships
    - **Walker Testing**: Test mobile computation patterns naturally
    - **Type-Safe Assertions**: Leverage Jac's type system in test validation
    - **Zero Configuration**: No external testing frameworks required

### Traditional vs Jac Testing

!!! example "Testing Comparison"
    === "Traditional Approach"
        ```python
        # test_social_media.py - External framework required
        import unittest
        from social_media import Profile, Tweet, Comment

        class TestSocialMedia(unittest.TestCase):
            def setUp(self):
                self.profile = Profile("test_user")
                self.tweet = Tweet("Hello world!")

            def test_create_profile(self):
                self.assertEqual(self.profile.username, "test_user")
                self.assertIsInstance(self.profile, Profile)

            def test_create_tweet(self):
                self.profile.add_tweet(self.tweet)
                self.assertEqual(len(self.profile.tweets), 1)
                self.assertEqual(self.profile.tweets[0].content, "Hello world!")

            def test_follow_user(self):
                other_user = Profile("other_user")
                self.profile.follow(other_user)
                self.assertIn(other_user, self.profile.following)

        if __name__ == '__main__':
            unittest.main()
        ```

    === "Jac Testing"
        ```jac
        # social_media.test.jac - Built-in testing

        test create_profile {
            root spawn visit_profile();
            profile = [root --> Profile][0];
            check isinstance(profile, Profile);
            check profile.username == "";  # Default value
        }

        test update_profile {
            root spawn update_profile(new_username="test_user");
            profile = [root --> Profile][0];
            check profile.username == "test_user";
        }

        test create_tweet {
            root spawn create_tweet(content="Hello world!");
            tweet = [root --> Profile --> Tweet][0];
            check tweet.content == "Hello world!";
            check isinstance(tweet, Tweet);
        }

        test follow_user {
            # Create another profile to follow
            other_profile = Profile(username="other_user");
            other_profile spawn follow_request();

            # Check follow relationship exists
            followed = [root --> Profile ->:Follow:-> Profile][0];
            check followed.username == "other_user";
        }
        ```

---

## Testing Graph Structures

Testing spatial applications requires verifying both node properties and relationship integrity. Let's build a comprehensive social media system and test it thoroughly.

### Basic Social Media System

!!! example "Social Media Implementation"
    === "social_media.jac"
        ```jac
        # social_media.jac
        import from datetime { datetime }

        node Profile {
            has username: str = "";
            has bio: str = "";
            has follower_count: int = 0;

            can update with update_profile entry;
            can follow with follow_request entry;
            can unfollow with unfollow_request entry;
        }

        node Tweet {
            has content: str;
            has created_at: str = datetime.now().strftime("%Y-%m-%d %H:%M:%S");
            has like_count: int = 0;

            can update with update_tweet exit;
            can delete with remove_tweet exit;
            can like with like_tweet entry;
            can unlike with unlike_tweet entry;
        }

        node Comment {
            has content: str;
            has created_at: str = datetime.now().strftime("%Y-%m-%d %H:%M:%S");

            can update with update_comment entry;
            can delete with remove_comment entry;
        }

        edge Follow {
            has followed_at: str = datetime.now().strftime("%Y-%m-%d %H:%M:%S");
        }

        edge Post {
            has posted_at: str = datetime.now().strftime("%Y-%m-%d %H:%M:%S");
        }

        edge Like {
            has liked_at: str = datetime.now().strftime("%Y-%m-%d %H:%M:%S");
        }

        edge CommentOn {}

        walker visit_profile {
            can visit_profile with `root entry {
                visit [-->Profile] else {
                    new_profile = here ++> Profile();
                    visit new_profile;
                }
            }
        }

        walker update_profile(visit_profile) {
            has new_username: str;
            has new_bio: str = "";
        }

        walker follow_request {
            can follow_user with Profile entry {
                current_profile = [root --> Profile][0];
                if current_profile != here {
                    current_profile +>:Follow:+> here;
                    here.follower_count += 1;
                    report {"message": f"Now following {here.username}"};
                } else {
                    report {"error": "Cannot follow yourself"};
                }
            }
        }

        walker unfollow_request {
            can unfollow_user with Profile entry {
                current_profile = [root --> Profile][0];
                follow_edges = [edge current_profile ->:Follow:-> here];
                if follow_edges {
                    del follow_edges[0];
                    here.follower_count -= 1;
                    report {"message": f"Unfollowed {here.username}"};
                } else {
                    report {"error": "Not following this user"};
                }
            }
        }

        walker create_tweet(visit_profile) {
            has content: str;

            can post_tweet with Profile entry {
                tweet = here +>:Post:+> Tweet(content=self.content);
                report {"message": "Tweet created", "tweet_id": tweet[0].id};
            }
        }

        walker update_tweet {
            has updated_content: str;
        }

        walker remove_tweet {}

        walker like_tweet {
            can like_post with Tweet entry {
                current_profile = [root --> Profile][0];
                existing_likes = [edge current_profile ->:Like:-> here];

                if not existing_likes {
                    current_profile +>:Like:+> here;
                    here.like_count += 1;
                    report {"message": "Tweet liked"};
                } else {
                    report {"error": "Already liked this tweet"};
                }
            }
        }

        walker unlike_tweet {
            can unlike_post with Tweet entry {
                current_profile = [root --> Profile][0];
                like_edges = [edge current_profile ->:Like:-> here];

                if like_edges {
                    del like_edges[0];
                    here.like_count -= 1;
                    report {"message": "Tweet unliked"};
                } else {
                    report {"error": "Haven't liked this tweet"};
                }
            }
        }

        walker comment_on_tweet {
            has content: str;

            can add_comment with Tweet entry {
                current_profile = [root --> Profile][0];
                comment = current_profile ++> Comment(content=self.content);
                here +>:CommentOn:+> comment[0];
                report {"message": "Comment added", "comment_id": comment[0].id};
            }
        }
        ```

    === "Python Equivalent"
        ```python
        # social_media.py - Manual implementation
        from datetime import datetime
        from typing import List, Optional

        class Profile:
            def __init__(self, username: str = "", bio: str = ""):
                self.username = username
                self.bio = bio
                self.follower_count = 0
                self.following = []
                self.followers = []
                self.tweets = []

            def follow(self, other_profile):
                if other_profile not in self.following and other_profile != self:
                    self.following.append(other_profile)
                    other_profile.followers.append(self)
                    other_profile.follower_count += 1
                    return True
                return False

            def unfollow(self, other_profile):
                if other_profile in self.following:
                    self.following.remove(other_profile)
                    other_profile.followers.remove(self)
                    other_profile.follower_count -= 1
                    return True
                return False

        class Tweet:
            def __init__(self, content: str, author: Profile):
                self.content = content
                self.author = author
                self.created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                self.like_count = 0
                self.liked_by = []
                self.comments = []

            def like(self, user: Profile):
                if user not in self.liked_by:
                    self.liked_by.append(user)
                    self.like_count += 1
                    return True
                return False

            def unlike(self, user: Profile):
                if user in self.liked_by:
                    self.liked_by.remove(user)
                    self.like_count -= 1
                    return True
                return False

        class Comment:
            def __init__(self, content: str, author: Profile, tweet: Tweet):
                self.content = content
                self.author = author
                self.tweet = tweet
                self.created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        ```

### Comprehensive Test Suite

!!! example "Complete Test Coverage"
    === "social_media.test.jac"
        ```jac
        # social_media.test.jac

        # Test basic profile creation and updates
        test create_and_update_profile {
            # Test profile creation
            root spawn visit_profile();
            profile = [root --> Profile][0];
            check isinstance(profile, Profile);
            check profile.username == "";
            check profile.follower_count == 0;

            # Test profile update
            root spawn update_profile(
                new_username="alice",
                new_bio="Software developer"
            );
            updated_profile = [root --> Profile][0];
            check updated_profile.username == "alice";
            check updated_profile.bio == "Software developer";
        }

        # Test following functionality
        test follow_and_unfollow_users {
            # Create main user profile
            root spawn visit_profile();
            root spawn update_profile(new_username="alice");

            # Create another user to follow
            bob_profile = Profile(username="bob");

            # Test following
            bob_profile spawn follow_request();
            follow_edge = [root --> Profile ->:Follow:-> Profile][0];
            check follow_edge.username == "bob";
            check bob_profile.follower_count == 1;

            # Test follow edge properties
            follow_edges = [edge [root --> Profile] ->:Follow:-> bob_profile];
            check len(follow_edges) == 1;
            check hasattr(follow_edges[0], "followed_at");

            # Test unfollowing
            bob_profile spawn unfollow_request();
            remaining_follows = [root --> Profile ->:Follow:-> Profile];
            check len(remaining_follows) == 0;
            check bob_profile.follower_count == 0;
        }

        # Test tweet creation and management
        test tweet_lifecycle {
            # Ensure we have a profile
            root spawn visit_profile();
            root spawn update_profile(new_username="alice");

            # Test tweet creation
            root spawn create_tweet(content="Hello world!");
            tweet = [root --> Profile ->:Post:-> Tweet][0];
            check tweet.content == "Hello world!";
            check isinstance(tweet, Tweet);
            check hasattr(tweet, "created_at");

            # Test tweet update
            tweet spawn update_tweet(updated_content="Hello updated world!");
            check tweet.content == "Hello updated world!";

            # Test multiple tweets
            root spawn create_tweet(content="Second tweet");
            all_tweets = [root --> Profile ->:Post:-> Tweet];
            check len(all_tweets) == 2;

            # Test tweet deletion
            tweet spawn remove_tweet();
            remaining_tweets = [root --> Profile ->:Post:-> Tweet];
            check len(remaining_tweets) == 1;
            check remaining_tweets[0].content == "Second tweet";
        }

        # Test liking functionality
        test like_and_unlike_tweets {
            # Setup: Create profile and tweet
            root spawn visit_profile();
            root spawn update_profile(new_username="alice");
            root spawn create_tweet(content="Likeable tweet");

            tweet = [root --> Profile ->:Post:-> Tweet][0];
            check tweet.like_count == 0;

            # Test liking
            tweet spawn like_tweet();
            check tweet.like_count == 1;

            # Verify like relationship exists
            like_edges = [edge [root --> Profile] ->:Like:-> tweet];
            check len(like_edges) == 1;

            # Test double-liking (should fail)
            result = tweet spawn like_tweet();
            check tweet.like_count == 1;  # Should remain 1

            # Test unliking
            tweet spawn unlike_tweet();
            check tweet.like_count == 0;

            # Verify like relationship removed
            remaining_likes = [edge [root --> Profile] ->:Like:-> tweet];
            check len(remaining_likes) == 0;
        }

        # Test commenting functionality
        test comment_system {
            # Setup: Create profile and tweet
            root spawn visit_profile();
            root spawn update_profile(new_username="alice");
            root spawn create_tweet(content="Tweet for comments");

            tweet = [root --> Profile ->:Post:-> Tweet][0];

            # Test commenting
            tweet spawn comment_on_tweet(content="Great tweet!");
            comments = [tweet ->:CommentOn:-> Comment];
            check len(comments) == 1;
            check comments[0].content == "Great tweet!";

            # Test multiple comments
            tweet spawn comment_on_tweet(content="I agree!");
            all_comments = [tweet ->:CommentOn:-> Comment];
            check len(all_comments) == 2;

            # Test comment update
            first_comment = all_comments[0];
            first_comment spawn update_comment(updated_content="Updated comment");
            check first_comment.content == "Updated comment";

            # Test comment deletion
            first_comment spawn remove_comment();
            remaining_comments = [tweet ->:CommentOn:-> Comment];
            check len(remaining_comments) == 1;
        }

        # Test complex graph relationships
        test complex_social_graph {
            # Create multiple users
            root spawn visit_profile();
            root spawn update_profile(new_username="alice");

            bob = Profile(username="bob");
            charlie = Profile(username="charlie");

            # Create follow relationships: alice -> bob -> charlie
            bob spawn follow_request();
            charlie spawn follow_request();  # alice follows charlie too

            # Alice creates a tweet
            root spawn create_tweet(content="Alice's tweet");
            alice_tweet = [root --> Profile ->:Post:-> Tweet][0];

            # Bob likes Alice's tweet
            # (Note: In a real system, you'd switch user context)
            alice_tweet spawn like_tweet();

            # Verify complex relationships
            alice_profile = [root --> Profile][0];
            alice_following = [alice_profile ->:Follow:-> Profile];
            check len(alice_following) == 2;  # follows bob and charlie

            alice_tweets = [alice_profile ->:Post:-> Tweet];
            check len(alice_tweets) == 1;

            tweet_likes = [alice_tweets[0] <-:Like:<- Profile];
            check len(tweet_likes) == 1;  # liked by alice (herself)
        }

        # Test error conditions and edge cases
        test error_conditions {
            # Test operations without profile
            try {
                root spawn create_tweet(content="No profile tweet");
                check False;  # Should not reach here
            } except Exception {
                check True;  # Expected behavior
            }

            # Create profile for other tests
            root spawn visit_profile();
            root spawn update_profile(new_username="test_user");

            # Test self-follow prevention
            alice_profile = [root --> Profile][0];
            result = alice_profile spawn follow_request();

            # Should not create self-follow
            self_follows = [alice_profile ->:Follow:-> alice_profile];
            check len(self_follows) == 0;
        }

        # Performance and stress testing
        test performance_operations {
            # Setup
            root spawn visit_profile();
            root spawn update_profile(new_username="performance_user");

            # Create multiple tweets quickly
            for i in range(10) {
                root spawn create_tweet(content=f"Tweet number {i}");
            }

            all_tweets = [root --> Profile ->:Post:-> Tweet];
            check len(all_tweets) == 10;

            # Like all tweets
            for tweet in all_tweets {
                tweet spawn like_tweet();
            }

            # Verify all likes
            for tweet in all_tweets {
                check tweet.like_count == 1;
            }

            # Test batch operations work correctly
            total_likes = sum([tweet.like_count for tweet in all_tweets]);
            check total_likes == 10;
        }
        ```

    === "Python Test Equivalent"
        ```python
        # test_social_media.py
        import unittest
        from social_media import Profile, Tweet, Comment

        class TestSocialMedia(unittest.TestCase):
            def setUp(self):
                self.alice = Profile("alice", "Software developer")
                self.bob = Profile("bob", "Designer")

            def test_create_and_update_profile(self):
                profile = Profile()
                self.assertEqual(profile.username, "")
                self.assertEqual(profile.follower_count, 0)

                profile.username = "alice"
                profile.bio = "Software developer"
                self.assertEqual(profile.username, "alice")

            def test_follow_and_unfollow_users(self):
                # Test following
                success = self.alice.follow(self.bob)
                self.assertTrue(success)
                self.assertIn(self.bob, self.alice.following)
                self.assertEqual(self.bob.follower_count, 1)

                # Test unfollowing
                success = self.alice.unfollow(self.bob)
                self.assertTrue(success)
                self.assertNotIn(self.bob, self.alice.following)
                self.assertEqual(self.bob.follower_count, 0)

            def test_tweet_lifecycle(self):
                tweet = Tweet("Hello world!", self.alice)
                self.alice.tweets.append(tweet)

                self.assertEqual(tweet.content, "Hello world!")
                self.assertEqual(len(self.alice.tweets), 1)

                # Update tweet
                tweet.content = "Hello updated world!"
                self.assertEqual(tweet.content, "Hello updated world!")

            def test_like_and_unlike_tweets(self):
                tweet = Tweet("Likeable tweet", self.alice)

                # Test liking
                success = tweet.like(self.bob)
                self.assertTrue(success)
                self.assertEqual(tweet.like_count, 1)

                # Test double-liking
                success = tweet.like(self.bob)
                self.assertFalse(success)
                self.assertEqual(tweet.like_count, 1)

                # Test unliking
                success = tweet.unlike(self.bob)
                self.assertTrue(success)
                self.assertEqual(tweet.like_count, 0)

        if __name__ == '__main__':
            unittest.main()
        ```

---

## Debugging Spatial Applications

Debugging spatial applications requires understanding graph state and walker movement patterns.

### Debug Output and Tracing

!!! example "Debug Walker for Graph Inspection"
    ```jac
    # debug_walker.jac
    walker debug_graph {
        has visited_nodes: list[str] = [];
        has visited_edges: list[str] = [];
        has max_depth: int = 3;
        has current_depth: int = 0;

        can debug_node with Profile entry {
            if self.current_depth >= self.max_depth {
                print(f"Max depth {self.max_depth} reached at {here.username}");
                return;
            }

            node_info = f"Profile: {here.username} (followers: {here.follower_count})";
            self.visited_nodes.append(node_info);
            print(f"Depth {self.current_depth}: {node_info}");

            # Debug outgoing relationships
            following = [->:Follow:->];
            tweets = [->:Post:->];

            print(f"  Following: {len(following)} users");
            print(f"  Posted: {len(tweets)} tweets");

            # Visit connected nodes
            self.current_depth += 1;
            visit following;
            visit tweets;
            self.current_depth -= 1;
        }

        can debug_tweet with Tweet entry {
            tweet_info = f"Tweet: '{here.content[:30]}...' (likes: {here.like_count})";
            self.visited_nodes.append(tweet_info);
            print(f"Depth {self.current_depth}: {tweet_info}");

            # Debug tweet relationships
            likes = [<-:Like:<-];
            comments = [->:CommentOn:->];

            print(f"  Liked by: {len(likes)} users");
            print(f"  Comments: {len(comments)}");
        }

        can debug_comment with Comment entry {
            comment_info = f"Comment: '{here.content[:20]}...'";
            self.visited_nodes.append(comment_info);
            print(f"Depth {self.current_depth}: {comment_info}");
        }
    }

    # Usage in tests
    test debug_graph_structure {
        # Setup complex graph
        root spawn visit_profile();
        root spawn update_profile(new_username="alice");
        root spawn create_tweet(content="Alice's first tweet");

        bob = Profile(username="bob");
        bob spawn follow_request();

        # Debug the graph
        debugger = debug_graph(max_depth=2);
        root spawn debugger;

        print("=== Debug Summary ===");
        print(f"Visited {len(debugger.visited_nodes)} nodes");
        for node in debugger.visited_nodes {
            print(f"  {node}");
        }
    }
    ```

### Walker State Inspection

!!! example "Walker State Testing"
    ```jac
    # walker_testing.jac
    walker feed_loader {
        has user_id: str;
        has loaded_tweets: list[dict] = [];
        has users_visited: set[str] = set();
        has errors: list[str] = [];

        can load_user_feed with Profile entry {
            if here.username in self.users_visited {
                self.errors.append(f"Duplicate visit to {here.username}");
                return;
            }

            self.users_visited.add(here.username);

            # Load user's tweets
            user_tweets = [->:Post:-> Tweet];
            for tweet in user_tweets {
                tweet_data = {
                    "author": here.username,
                    "content": tweet.content,
                    "likes": tweet.like_count,
                    "created_at": tweet.created_at
                };
                self.loaded_tweets.append(tweet_data);
            }

            # Visit followed users
            following = [->:Follow:-> Profile];
            visit following;
        }
    }

    test walker_state_management {
        # Setup test data
        root spawn visit_profile();
        root spawn update_profile(new_username="alice");
        root spawn create_tweet(content="Alice tweet 1");
        root spawn create_tweet(content="Alice tweet 2");

        bob = Profile(username="bob");
        bob spawn follow_request();
        bob spawn create_tweet(content="Bob's tweet");

        # Test walker state
        loader = feed_loader(user_id="alice");
        root spawn loader;

        # Verify walker state
        check len(loader.loaded_tweets) >= 2;  # At least Alice's tweets
        check "alice" in loader.users_visited;
        check "bob" in loader.users_visited;
        check len(loader.errors) == 0;

        # Verify tweet data structure
        alice_tweets = [t for t in loader.loaded_tweets if t["author"] == "alice"];
        check len(alice_tweets) == 2;

        for tweet in alice_tweets {
            check "content" in tweet;
            check "likes" in tweet;
            check "created_at" in tweet;
        }
    }
    ```

---

## Performance Testing and Optimization

Performance testing ensures your spatial applications scale effectively.

### Benchmark Testing

!!! example "Performance Benchmarks"
    ```jac
    # performance_tests.jac
    import time;

    test large_graph_performance {
        start_time = time.time();

        # Create large social network
        root spawn visit_profile();
        root spawn update_profile(new_username="central_user");

        # Create many users and connections
        num_users = 100;
        users = [];

        for i in range(num_users) {
            user = Profile(username=f"user_{i}");
            users.append(user);

            # Every 10th user follows central user
            if i % 10 == 0 {
                user spawn follow_request();
            }
        }

        creation_time = time.time() - start_time;
        print(f"Created {num_users} users in {creation_time:.2f} seconds");

        # Test graph traversal performance
        start_time = time.time();

        # Count all followers
        central_user = [root --> Profile][0];
        followers = [central_user <-:Follow:<- Profile];

        traversal_time = time.time() - start_time;
        print(f"Traversed {len(followers)} followers in {traversal_time:.4f} seconds");

        # Performance assertions
        check creation_time < 5.0;  # Should create 100 users in under 5 seconds
        check traversal_time < 0.1;  # Should traverse quickly
        check len(followers) == 10;  # Every 10th user = 10 followers
    }

    test memory_efficiency {
        # Test memory usage with large datasets
        initial_profiles = len([root --> Profile]);

        # Create and delete many objects
        for batch in range(5) {
            # Create batch of tweets
            for i in range(20) {
                root spawn create_tweet(content=f"Batch {batch} tweet {i}");
            }

            # Delete half of them
            tweets = [root --> Profile ->:Post:-> Tweet];
            for i in range(10) {
                if len(tweets) > i {
                    tweets[i] spawn remove_tweet();
                }
            }
        }

        # Check memory cleanup
        final_tweets = [root --> Profile ->:Post:-> Tweet];
        check len(final_tweets) <= 50;  # Should not accumulate indefinitely

        final_profiles = len([root --> Profile]);
        check final_profiles == initial_profiles + 1;  # Only the test profile added
    }

    test concurrent_operations {
        # Simulate concurrent-like operations
        root spawn visit_profile();
        root spawn update_profile(new_username="concurrent_user");

        # Create multiple walkers that operate simultaneously
        walkers = [];
        for i in range(10) {
            walker = create_tweet(content=f"Concurrent tweet {i}");
            walkers.append(walker);
        }

        # Execute all walkers
        start_time = time.time();
        for walker in walkers {
            root spawn walker;
        }
        execution_time = time.time() - start_time;

        # Verify all operations completed
        all_tweets = [root --> Profile ->:Post:-> Tweet];
        check len(all_tweets) == 10;

        # Performance check
        check execution_time < 1.0;  # Should complete quickly

        print(f"Executed {len(walkers)} operations in {execution_time:.4f} seconds");
    }
    ```

### Memory and Resource Testing

!!! example "Resource Usage Tests"
    ```jac
    # resource_tests.jac
    import gc;
    import psutil;
    import os;

    test memory_usage_monitoring {
        # Get initial memory usage
        process = psutil.Process(os.getpid());
        initial_memory = process.memory_info().rss;

        # Create large graph structure
        root spawn visit_profile();
        root spawn update_profile(new_username="memory_test_user");

        # Create many interconnected objects
        for i in range(1000) {
            root spawn create_tweet(content=f"Memory test tweet {i}");
        }

        # Force garbage collection
        gc.collect();

        # Check memory after creation
        after_creation_memory = process.memory_info().rss;
        memory_increase = after_creation_memory - initial_memory;

        print(f"Memory increase: {memory_increase / 1024 / 1024:.2f} MB");

        # Clean up
        tweets = [root --> Profile ->:Post:-> Tweet];
        for tweet in tweets {
            tweet spawn remove_tweet();
        }

        # Force garbage collection again
        gc.collect();

        # Check memory after cleanup
        final_memory = process.memory_info().rss;
        memory_recovered = after_creation_memory - final_memory;

        print(f"Memory recovered: {memory_recovered / 1024 / 1024:.2f} MB");

        # Memory should not grow indefinitely
        check memory_increase < 100 * 1024 * 1024;  # Less than 100MB increase
        check memory_recovered > memory_increase * 0.5;  # At least 50% recovered
    }
    ```

---

## Test-Driven Development with OSP

TDD works naturally with Jac's spatial programming model.

### TDD Example: Building a Recommendation System

!!! example "TDD Recommendation System"
    ```jac
    # recommendation_system.test.jac

    # Test 1: Basic recommendation structure
    test recommendation_system_structure {
        # Red: This will fail initially
        root spawn visit_profile();
        root spawn update_profile(new_username="test_user");

        # Should be able to get recommendations
        recommendations = root spawn get_recommendations(limit=5);
        check isinstance(recommendations, list);
        check len(recommendations) <= 5;
    }

    # Test 2: Friend-based recommendations
    test friend_based_recommendations {
        # Setup: Create network
        root spawn visit_profile();
        root spawn update_profile(new_username="alice");

        bob = Profile(username="bob");
        charlie = Profile(username="charlie");

        # Alice follows Bob, Bob follows Charlie
        bob spawn follow_request();
        # Switch context to Bob and follow Charlie
        # (In real system, would handle user context switching)

        # Alice should get Charlie recommended (friend of friend)
        recommendations = root spawn get_recommendations(limit=5);
        recommended_usernames = [rec["username"] for rec in recommendations];

        # Charlie should be recommended as friend of friend
        check "charlie" in recommended_usernames;
    }

    # Test 3: Interest-based recommendations
    test interest_based_recommendations {
        # Setup users with similar interests (tweets)
        root spawn visit_profile();
        root spawn update_profile(new_username="alice");
        root spawn create_tweet(content="I love programming");

        bob = Profile(username="bob");
        bob spawn create_tweet(content="Programming is awesome");

        charlie = Profile(username="charlie");
        charlie spawn create_tweet(content="I hate programming");

        # Get recommendations
        recommendations = root spawn get_recommendations(
            limit=5,
            algorithm="interest_based"
        );

        # Bob should rank higher than Charlie due to similar interests
        bob_score = 0;
        charlie_score = 0;

        for rec in recommendations {
            if rec["username"] == "bob" {
                bob_score = rec["score"];
            }
            if rec["username"] == "charlie" {
                charlie_score = rec["score"];
            }
        }

        check bob_score > charlie_score;
    }

    # Test 4: Recommendation filtering
    test recommendation_filtering {
        # Setup
        root spawn visit_profile();
        root spawn update_profile(new_username="alice");

        # Create users alice already follows
        bob = Profile(username="bob");
        bob spawn follow_request();

        # Create users alice doesn't follow
        charlie = Profile(username="charlie");
        diana = Profile(username="diana");

        # Get recommendations
        recommendations = root spawn get_recommendations(limit=10);
        recommended_usernames = [rec["username"] for rec in recommendations];

        # Should not recommend users already followed
        check "bob" not in recommended_usernames;

        # Should recommend unfollowed users
        check "charlie" in recommended_usernames or "diana" in recommended_usernames;
    }
    ```

    Now implement the actual recommendation system to make tests pass:

    ```jac
    # recommendation_system.jac
    walker get_recommendations(visit_profile) {
        has limit: int = 5;
        has algorithm: str = "hybrid";
        has recommendations: list[dict] = [];

        can generate_recommendations with Profile entry {
            current_user = here;
            followed_users = [->:Follow:-> Profile];
            followed_usernames = set([user.username for user in followed_users]);

            # Get all users except current and already followed
            all_users = [root --> Profile](?username != current_user.username);
            candidate_users = [user for user in all_users
                             if user.username not in followed_usernames];

            # Score each candidate
            for candidate in candidate_users {
                score = self.calculate_recommendation_score(
                    current_user, candidate, followed_users
                );

                if score > 0 {
                    self.recommendations.append({
                        "username": candidate.username,
                        "score": score,
                        "reason": self.get_recommendation_reason(
                            current_user, candidate, followed_users
                        )
                    });
                }
            }

            # Sort by score and limit results
            self.recommendations.sort(key=lambda x: x["score"], reverse=True);
            self.recommendations = self.recommendations[:self.limit];

            report self.recommendations;
        }

        def calculate_recommendation_score(
            current_user: Profile,
            candidate: Profile,
            followed_users: list[Profile]
        ) -> float {
            score = 0.0;

            if self.algorithm in ["friend_based", "hybrid"] {
                # Friend of friend scoring
                candidate_followers = [candidate <-:Follow:<- Profile];
                mutual_connections = set([u.username for u in followed_users]) &
                                   set([u.username for u in candidate_followers]);
                score += len(mutual_connections) * 2.0;
            }

            if self.algorithm in ["interest_based", "hybrid"] {
                # Interest-based scoring using tweet content
                current_tweets = [current_user ->:Post:-> Tweet];
                candidate_tweets = [candidate ->:Post:-> Tweet];

                # Simple keyword matching (in real system, use embeddings)
                current_words = set();
                for tweet in current_tweets {
                    current_words.update(tweet.content.lower().split());
                }

                candidate_words = set();
                for tweet in candidate_tweets {
                    candidate_words.update(tweet.content.lower().split());
                }

                common_words = current_words & candidate_words;
                score += len(common_words) * 0.5;
            }

            return score;
        }

        def get_recommendation_reason(
            current_user: Profile,
            candidate: Profile,
            followed_users: list[Profile]
        ) -> str {
            # Determine primary reason for recommendation
            candidate_followers = [candidate <-:Follow:<- Profile];
            mutual_connections = set([u.username for u in followed_users]) &
                               set([u.username for u in candidate_followers]);

            if mutual_connections {
                return f"Friends with {list(mutual_connections)[0]}";
            }

            return "Similar interests";
        }
    }
    ```

---

## Best Practices

!!! summary "Testing Best Practices"
    - **Write tests first**: Use test-driven development for complex walker logic
    - **Test graph structures**: Verify node and edge relationships are correct
    - **Use descriptive names**: Make test intentions clear from the test name
    - **Test edge cases**: Include boundary conditions and error scenarios
    - **Isolate test data**: Ensure tests don't interfere with each other
    - **Mock external dependencies**: Test walker logic independently of external services

## Key Takeaways

!!! summary "What We've Learned"
    **Testing Framework:**

    - **Built-in testing**: Native test blocks eliminate external framework dependencies
    - **Graph testing**: Specialized patterns for testing spatial relationships
    - **Walker testing**: Comprehensive testing of mobile computation patterns
    - **Type-safe assertions**: Leverage Jac's type system in test validation

    **Debugging Techniques:**

    - **Debug output**: Strategic print statements and debug flags
    - **Walker tracing**: Track walker movement through graph structures
    - **State inspection**: Examine node and edge states during execution
    - **Error handling**: Graceful handling of edge cases and failures

    **Test Organization:**

    - **Modular testing**: Organize tests by functionality and complexity
    - **Helper functions**: Reusable setup code for consistent test environments
    - **Performance testing**: Monitor execution time and resource usage
    - **Integration testing**: Test interactions between multiple walkers

    **Quality Assurance:**

    - **Comprehensive coverage**: Test all code paths and error conditions
    - **Regression prevention**: Automated tests prevent breaking changes
    - **Documentation value**: Tests serve as executable specifications
    - **Continuous validation**: Automated testing in CI/CD pipelines

!!! tip "Try It Yourself"
    Enhance your testing skills by:
    - Writing comprehensive test suites for existing walker logic
    - Implementing performance benchmarks for graph operations
    - Creating integration tests for multi-walker scenarios
    - Adding debug instrumentation to complex graph traversals

    Remember: Good tests make development faster and more reliable!

---

*Ready to learn about deployment strategies? Continue to [Chapter 19: Deployment Strategies](chapter_18.md)!*
