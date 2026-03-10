"""Compact test for MongoDB user operations using testcontainers."""

import os;
import from jac_scale.user_manager { JacScaleUserManager }
import from jac_scale.config_loader { reset_scale_config }

"""Test MongoDB user CRUD operations with testcontainers."""
test "mongodb user operations" {
    import from testcontainers.mongodb { MongoDbContainer }
    import tempfile;

    # Start MongoDB container
    with MongoDbContainer("mongo:7.0") as mongo {
        mongo_uri = mongo.get_connection_url();
        with tempfile.TemporaryDirectory() as tmpdir {
            toml_content = """
[project]
name = "test-mongo-user-manager"
version = "1.0.0"

[plugins.scale.database]
# MongoDB URI will be set via environment variable

[plugins.scale.jwt]
secret = "test_secret"
algorithm = "HS256"
exp_delta_days = 1

[plugins.scale.sso]
host = "http://localhost:8000/sso"

[plugins.scale.admin]
username = "admin"
default_password = "admin123"
require_password_reset = true
""";
            toml_path = os.path.join(tmpdir, "jac.toml");
            with open(toml_path, 'w') as f {
                f.write(toml_content);
            }
            old_mongodb_uri = os.environ.get('MONGODB_URI');
            os.environ['MONGODB_URI'] = mongo_uri;
            try {
                reset_scale_config();
                um = JacScaleUserManager(base_path=tmpdir);
                # Test: Create user
                result = um.create_user("test_user", "password123");
                assert result.get("username") == "test_user";
                assert "token" in result;
                assert "root_id" in result;
                token1 = result["token"];
                # Test: Duplicate user fails
                result = um.create_user("test_user", "other_password");
                assert "error" in result;
                assert "already exists" in result["error"];
                # Test: Authenticate success
                auth_result = um.authenticate("test_user", "password123");
                assert auth_result is not None;
                assert auth_result["username"] == "test_user";
                assert auth_result["token"] == token1;
                # Test: Authenticate failure (wrong password)
                auth_result = um.authenticate("test_user", "wrong_password");
                assert auth_result is None;
                # Test: Get user
                user = um.get_user("test_user");
                assert user is not None;
                assert user["email"] == "test_user";
                assert user["token"] == token1;
                # Test: User exists
                assert um.user_exists("test_user") == True;
                assert um.user_exists("nonexistent") == False;
                # Test: Get root ID
                root_id = um.get_root_id("test_user");
                assert root_id is not None;
                assert len(root_id) > 0;
                # Test: Update password
                result = um.update_password("test_user", "password123", "new_password");
                assert "message" in result;
                assert "updated successfully" in result["message"];
                # Verify old password doesn't work
                auth_result = um.authenticate("test_user", "password123");
                assert auth_result is None;
                # Verify new password works
                auth_result = um.authenticate("test_user", "new_password");
                assert auth_result is not None;
                # Test: Update username
                result = um.update_username("test_user", "renamed_user");
                assert result.get("username") == "renamed_user";
                assert "token" in result;
                # Verify old username doesn't exist
                assert um.user_exists("test_user") == False;
                assert um.user_exists("renamed_user") == True;
                # Test: Create second user for SSO linking
                result = um.create_user("user2", "pass2");
                assert "error" not in result;
                # Test: Link SSO account
                link_result = um.link_sso_account(
                    "renamed_user", "google", "ext_123", "test@example.com"
                );
                assert "message" in link_result;
                assert "linked successfully" in link_result["message"];
                # Test: Get SSO accounts
                sso_accounts = um.get_sso_accounts("renamed_user");
                assert len(sso_accounts) == 1;
                assert sso_accounts[0]["platform"] == "google";
                assert sso_accounts[0]["external_id"] == "ext_123";
                # Test: Get user by SSO
                user_by_sso = um.get_user_by_sso("google", "ext_123");
                assert user_by_sso is not None;
                assert user_by_sso["email"] == "renamed_user";
                # Test: Unlink SSO account
                unlink_result = um.unlink_sso_account("renamed_user", "google");
                assert "message" in unlink_result;
                assert "unlinked successfully" in unlink_result["message"];
                # Verify SSO account is removed
                sso_accounts = um.get_sso_accounts("renamed_user");
                assert len(sso_accounts) == 0;
                # Test: User roles and admin operations
                assert um.get_user_role("renamed_user") == "user";
                result = um.set_user_role("renamed_user", "admin");
                assert "message" in result;
                assert um.get_user_role("renamed_user") == "admin";
                assert um.is_admin("renamed_user") == True;
                assert um.is_admin("user2") == False;
                # Test: Password reset requirements
                assert um.requires_password_reset("renamed_user") == False;
                result = um.set_requires_password_reset("renamed_user", True);
                assert "message" in result;
                assert um.requires_password_reset("renamed_user") == True;
                # Test: Password required flag
                assert um.is_password_required("renamed_user") == True;
                result = um.set_password_required("renamed_user", False);
                assert "message" in result;
                assert um.is_password_required("renamed_user") == False;
                # Test: List all users
                users = um.list_all_users();
                assert len(users) == 2;
                usernames = {u["username"] for u in users};
                assert "renamed_user" in usernames;
                assert "user2" in usernames;
                # Test: Bootstrap admin user (creates if doesn't exist)
                result = um.bootstrap_admin_user();
                assert "message" in result;
                # Should either create new admin or find existing one
                assert "admin" in result["message"].lower();
                # Test: Bootstrap admin again (should already exist now)
                result = um.bootstrap_admin_user();
                assert "already exists" in result["message"];
                # Test: Delete user
                result = um.delete_user("user2");
                assert "message" in result;
                assert "deleted successfully" in result["message"];
                assert um.user_exists("user2") == False;
                # Verify user list after deletion (renamed_user + admin)
                users = um.list_all_users();
                assert len(users) == 2;
                usernames_final = {u["username"] for u in users};
                assert "renamed_user" in usernames_final;
                assert "admin" in usernames_final;

                um.close();
            } finally {
                # Restore original environment variable
                if old_mongodb_uri is not None {
                    os.environ['MONGODB_URI'] = old_mongodb_uri;
                } else {
                    os.environ.pop('MONGODB_URI', None);
                }
                # Reset config after test
                reset_scale_config();
            }
        }
    }
}
