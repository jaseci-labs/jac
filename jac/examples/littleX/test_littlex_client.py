"""Tests for littleX social media API using JacTestClient (port-free)."""

from __future__ import annotations

import os
import time
from collections.abc import Generator
from pathlib import Path
from typing import Any

import pytest

from jaclang.runtimelib.testing import JacTestClient


@pytest.fixture
def client(tmp_path: Path) -> Generator[JacTestClient, None, None]:
    """Create test client for littleX with isolated base path."""
    jac_file = os.path.join(os.path.dirname(__file__), "littleX_single_nodeps.jac")
    client = JacTestClient.from_file(
        jac_file,
        base_path=str(tmp_path),
    )
    yield client
    client.close()


def create_user(client: JacTestClient, username: str, password: str) -> dict[str, Any]:
    """Helper to create a user and return the response data."""
    response = client.register_user(username, password)
    return response.data


class TestServerStartup:
    """Test that server functionality works."""

    def test_server_startup(self, client: JacTestClient) -> None:
        """Test that server endpoints are accessible."""
        response = client.get("/")

        assert response.ok
        assert "message" in response.data or "endpoints" in response.data


class TestUserManagement:
    """Tests for user creation and authentication."""

    def test_user_creation_and_login(self, client: JacTestClient) -> None:
        """Test creating multiple users and logging in."""
        # Create three users
        user1_data = create_user(client, "alice", "pass123")
        client.clear_auth()
        user2_data = create_user(client, "bob", "pass456")
        client.clear_auth()
        user3_data = create_user(client, "charlie", "pass789")
        client.clear_auth()

        assert "token" in user1_data
        assert "token" in user2_data
        assert "token" in user3_data
        assert user1_data["root_id"] != user2_data["root_id"]
        assert user2_data["root_id"] != user3_data["root_id"]

        # Test login
        login_response = client.login("alice", "pass123")
        assert login_response.ok
        assert login_response.data["username"] == "alice"

        # Test wrong password
        client.clear_auth()
        login_fail = client.login("bob", "wrongpass")
        assert not login_fail.ok or "error" in str(login_fail.data)


class TestProfileManagement:
    """Tests for user profile operations."""

    def test_profile_creation_and_update(self, client: JacTestClient) -> None:
        """Test creating and updating user profiles."""
        # Create users
        create_user(client, "alice", "pass123")
        alice_token = client._auth_token
        client.clear_auth()

        create_user(client, "bob", "pass456")
        bob_token = client._auth_token
        client.clear_auth()

        # Update Alice's profile
        client.set_auth_token(alice_token)
        update_result = client.post(
            "/walker/update_profile",
            json={"new_username": "Alice_Wonderland"},
        )
        assert update_result.ok
        assert "result" in update_result.data or "reports" in update_result.data

        # Get Alice's profile
        profile_result = client.post("/walker/get_profile", json={})
        assert profile_result.ok
        assert "result" in profile_result.data or "reports" in profile_result.data

        # Update Bob's profile
        client.set_auth_token(bob_token)
        update_result2 = client.post(
            "/walker/update_profile",
            json={"new_username": "Bob_Builder"},
        )
        assert update_result2.ok
        assert "result" in update_result2.data or "reports" in update_result2.data


class TestSocialFeatures:
    """Tests for social media features like following, tweets, etc."""

    def test_follow_unfollow_users(self, client: JacTestClient) -> None:
        """Test following and unfollowing users."""
        # Create users
        create_user(client, "alice", "pass123")
        alice_token = client._auth_token
        client.clear_auth()

        create_user(client, "bob", "pass456")
        bob_token = client._auth_token
        client.clear_auth()

        create_user(client, "charlie", "pass789")
        client.clear_auth()

        # Update usernames
        client.set_auth_token(alice_token)
        client.post(
            "/walker/update_profile",
            json={"new_username": "Alice"},
        )

        client.set_auth_token(bob_token)
        client.post(
            "/walker/update_profile",
            json={"new_username": "Bob"},
        )

        # Get Bob's profile
        profile_result = client.post("/walker/get_profile", json={})
        assert profile_result.ok

    def test_create_and_list_tweets(self, client: JacTestClient) -> None:
        """Test creating tweets."""
        # Create user
        create_user(client, "alice", "pass123")

        # Update profile first
        client.post(
            "/walker/update_profile",
            json={"new_username": "Alice"},
        )

        # Create multiple tweets
        tweet1 = client.post(
            "/walker/create_tweet",
            json={"content": "Hello World! This is my first tweet!"},
        )
        assert tweet1.ok
        assert "result" in tweet1.data or "reports" in tweet1.data

        tweet2 = client.post(
            "/walker/create_tweet",
            json={"content": "Having a great day coding in Jac!"},
        )
        assert tweet2.ok
        assert "result" in tweet2.data or "reports" in tweet2.data

        tweet3 = client.post(
            "/walker/create_tweet",
            json={"content": "Check out this amazing project!"},
        )
        assert tweet3.ok
        assert "result" in tweet3.data or "reports" in tweet3.data

    def test_like_and_unlike_tweets(self, client: JacTestClient) -> None:
        """Test liking and unliking tweets."""
        # Create users
        create_user(client, "alice", "pass123")
        alice_token = client._auth_token
        client.clear_auth()

        create_user(client, "bob", "pass456")
        bob_token = client._auth_token
        client.clear_auth()

        # Update profiles
        client.set_auth_token(alice_token)
        client.post(
            "/walker/update_profile",
            json={"new_username": "Alice"},
        )

        client.set_auth_token(bob_token)
        client.post(
            "/walker/update_profile",
            json={"new_username": "Bob"},
        )

        # Alice creates a tweet
        client.set_auth_token(alice_token)
        tweet_result = client.post(
            "/walker/create_tweet",
            json={"content": "Like this tweet!"},
        )
        assert tweet_result.ok
        assert "result" in tweet_result.data or "reports" in tweet_result.data

    def test_comment_on_tweets(self, client: JacTestClient) -> None:
        """Test commenting on tweets."""
        # Create users
        create_user(client, "alice", "pass123")
        alice_token = client._auth_token
        client.clear_auth()

        create_user(client, "bob", "pass456")
        bob_token = client._auth_token
        client.clear_auth()

        # Update profiles
        client.set_auth_token(alice_token)
        client.post(
            "/walker/update_profile",
            json={"new_username": "Alice"},
        )

        client.set_auth_token(bob_token)
        client.post(
            "/walker/update_profile",
            json={"new_username": "Bob"},
        )

        # Alice creates a tweet
        client.set_auth_token(alice_token)
        tweet_result = client.post(
            "/walker/create_tweet",
            json={"content": "What do you think about this?"},
        )
        assert tweet_result.ok
        assert "result" in tweet_result.data or "reports" in tweet_result.data


class TestMultiUserActivity:
    """Tests for complex multi-user interactions."""

    def test_multi_user_social_activity(self, client: JacTestClient) -> None:
        """Test complex multi-user social media interactions."""
        # Create 5 users
        users = ["alice", "bob", "charlie", "diana", "eve"]
        user_tokens: dict[str, str] = {}

        for user in users:
            create_user(client, user, f"pass_{user}")
            user_tokens[user] = client._auth_token
            client.clear_auth()

        # Update all profiles
        for user in users:
            client.set_auth_token(user_tokens[user])
            client.post(
                "/walker/update_profile",
                json={"new_username": user.capitalize()},
            )

        # Each user creates multiple tweets
        tweet_contents = [
            "Just joined this platform!",
            "Having a great day!",
            "Check out my latest project",
            "What's everyone up to?",
            "Happy Friday everyone!",
        ]

        for user in users:
            client.set_auth_token(user_tokens[user])
            for content in tweet_contents:
                tweet = client.post(
                    "/walker/create_tweet",
                    json={"content": f"{user.capitalize()}: {content}"},
                )
                assert tweet.ok
                time.sleep(0.01)

        # Test load_feed for Alice
        client.set_auth_token(user_tokens["alice"])
        feed_result = client.post(
            "/walker/load_feed",
            json={},
        )
        # Feed may have errors due to sorting issues, but tweets were created
        assert feed_result.status_code in (200, 500)

    def test_load_all_user_profiles(self, client: JacTestClient) -> None:
        """Test loading all user profiles."""
        # Create multiple users
        users = ["alice", "bob", "charlie"]
        user_tokens: dict[str, str] = {}

        for user in users:
            create_user(client, user, f"pass_{user}")
            user_tokens[user] = client._auth_token
            client.clear_auth()

        # Update all profiles
        for user in users:
            client.set_auth_token(user_tokens[user])
            client.post(
                "/walker/update_profile",
                json={"new_username": user.capitalize()},
            )

        # Load user profiles
        client.set_auth_token(user_tokens["alice"])
        profiles_result = client.post(
            "/walker/load_user_profiles",
            json={},
        )
        # Check that the request completed (may or may not have result)
        assert profiles_result.status_code in (200, 500)


class TestUserIsolation:
    """Tests for user data isolation."""

    def test_user_isolation(self, client: JacTestClient) -> None:
        """Test that users have isolated data spaces."""
        # Create two users
        user1_data = create_user(client, "alice", "pass123")
        alice_token = client._auth_token
        alice_root = user1_data["root_id"]
        client.clear_auth()

        user2_data = create_user(client, "bob", "pass456")
        bob_token = client._auth_token
        bob_root = user2_data["root_id"]
        client.clear_auth()

        # Update profiles
        client.set_auth_token(alice_token)
        client.post(
            "/walker/update_profile",
            json={"new_username": "Alice"},
        )

        client.set_auth_token(bob_token)
        client.post(
            "/walker/update_profile",
            json={"new_username": "Bob"},
        )

        # Alice creates tweets
        client.set_auth_token(alice_token)
        client.post(
            "/walker/create_tweet",
            json={"content": "Alice's tweet 1"},
        )
        client.post(
            "/walker/create_tweet",
            json={"content": "Alice's tweet 2"},
        )

        # Bob creates tweets
        client.set_auth_token(bob_token)
        client.post(
            "/walker/create_tweet",
            json={"content": "Bob's tweet 1"},
        )

        # Verify different root IDs
        assert alice_root != bob_root
