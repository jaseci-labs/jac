"""Compact test for MongoDB user operations using testcontainers."""

import os;
import time;
import tempfile;
import from jac_scale.user_manager {
    JacScaleUserManager,
    _decoded_token_cache,
    _revocation_ts_cache,
    _user_token_hashes
}
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

                # Test: Create user (identity-based)
                result = um.create_user(
                    identities=[{'type': 'username', 'value': 'test_user'}],
                    credential={'type': 'password', 'password': 'password123'}
                );
                assert "user_id" in result;
                assert result.get("message") == "User registered successfully";
                user_id = result["user_id"];

                # Test: Duplicate user fails
                result = um.create_user(
                    identities=[{'type': 'username', 'value': 'test_user'}],
                    credential={'type': 'password', 'password': 'other_password'}
                );
                assert "error" in result;
                assert "already registered" in result["error"].lower();

                # Test: Authenticate success
                auth_result = um.authenticate("test_user", "password123");
                assert auth_result is not None;
                assert auth_result["user_id"] == user_id;
                assert "root_id" in auth_result;
                assert auth_result.get("role") == "user";

                # Test: Authenticate failure (wrong password)
                auth_result = um.authenticate("test_user", "wrong_password");
                assert auth_result is None;

                # Test: Get user by user_id
                user = um.get_user(user_id);
                assert user is not None;
                assert user["user_id"] == user_id;

                # Test: User exists
                assert um.user_exists(user_id) == True;
                assert um.user_exists("nonexistent") == False;

                # Test: User exists by identity value (fallback)
                assert um.user_exists("test_user") == True;

                # Test: Get root ID
                root_id = um.get_root_id(user_id);
                assert root_id is not None;
                assert len(root_id) > 0;

                # Test: Get root ID by identity value (fallback)
                root_id_by_name = um.get_root_id("test_user");
                assert root_id_by_name == root_id;

                # Test: Find user by identity
                found = um.find_user_by_identity("test_user");
                assert found is not None;
                assert found["user_id"] == user_id;

                # Test: Get username from user_id
                username = um.get_username(user_id);
                assert username == "test_user";

                # Test: Update password
                result = um.update_password(user_id, "password123", "new_password");
                assert "message" in result;
                assert "updated successfully" in result["message"];

                # Verify old password doesn't work
                auth_result = um.authenticate("test_user", "password123");
                assert auth_result is None;

                # Verify new password works
                auth_result = um.authenticate("test_user", "new_password");
                assert auth_result is not None;

                # Test: Create second user for SSO linking
                result2 = um.create_user(
                    identities=[{'type': 'username', 'value': 'user2'}],
                    credential={'type': 'password', 'password': 'pass2'}
                );
                assert "error" not in result2;
                user2_id = result2["user_id"];

                # Test: Link SSO account
                link_result = um.link_sso_account(user_id, "google", "ext_123");
                assert "message" in link_result;
                assert "linked successfully" in link_result["message"];

                # Test: Get SSO accounts
                sso_accounts = um.get_sso_accounts(user_id);
                assert len(sso_accounts) == 1;
                assert sso_accounts[0]["platform"] == "google";
                assert sso_accounts[0]["external_id"] == "ext_123";

                # Test: Get user by SSO
                user_by_sso = um.get_user_by_sso("google", "ext_123");
                assert user_by_sso is not None;
                assert user_by_sso["user_id"] == user_id;

                # Test: Unlink SSO account
                unlink_result = um.unlink_sso_account(user_id, "google");
                assert "message" in unlink_result;
                assert "unlinked successfully" in unlink_result["message"];

                # Verify SSO account is removed
                sso_accounts = um.get_sso_accounts(user_id);
                assert len(sso_accounts) == 0;

                # Test: User roles and admin operations
                assert um.get_user_role(user_id) == "user";
                result = um.set_user_role(user_id, "admin");
                assert "message" in result;
                assert um.get_user_role(user_id) == "admin";
                assert um.is_admin(user_id) == True;
                assert um.is_admin(user2_id) == False;

                # Test: Password reset requirements
                assert um.requires_password_reset(user_id) == False;
                result = um.set_requires_password_reset(user_id, True);
                assert "message" in result;
                assert um.requires_password_reset(user_id) == True;

                # Test: Password required flag
                assert um.is_password_required(user_id) == True;

                # Test: List all users
                users = um.list_all_users();
                assert len(users) == 2;
                user_ids = {u["user_id"] for u in users};
                assert user_id in user_ids;
                assert user2_id in user_ids;

                # Test: Bootstrap admin user (creates if doesn't exist)
                result = um.bootstrap_admin_user();
                assert "message" in result;
                # Should either create new admin or find existing one
                assert "admin" in result["message"].lower();

                # Test: Bootstrap admin again (should already exist now)
                result = um.bootstrap_admin_user();
                assert "already exists" in result["message"];

                # Test: JWT token operations
                token = um.create_jwt_token(user_id);
                assert token is not None;
                assert len(token) > 0;

                # Validate JWT token
                validated_id = um.validate_jwt_token(token);
                assert validated_id == user_id;

                # Refresh JWT token
                new_token = um.refresh_jwt_token(token);
                assert new_token is not None;

                # Test: Delete user
                result = um.delete_user(user2_id);
                assert "message" in result;
                assert "deleted successfully" in result["message"];
                assert um.user_exists(user2_id) == False;

                # Verify user list after deletion (test_user + admin)
                users = um.list_all_users();
                assert len(users) == 2;
                user_ids_final = {u["user_id"] for u in users};
                assert user_id in user_ids_final;

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

"""Test legacy user migration and progressive password rehashing."""
test "legacy user migration and progressive rehashing" {
    import from testcontainers.mongodb { MongoDbContainer }
    import from pymongo { MongoClient }
    import hashlib;
    import tempfile;
    import from jac_scale.identity_storage { IdentityStorage }

    ADMIN_UUID = '00000000-0000-0000-0000-000000000000';
    NEW_USER_UUID = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

    with MongoDbContainer("mongo:7.0") as mongo {
        mongo_uri = mongo.get_connection_url();
        with tempfile.TemporaryDirectory() as tmpdir {
            toml_path = os.path.join(tmpdir, "jac.toml");
            with open(toml_path, 'w') as f {
                f.write(
                    "[project]\nname = \"test-migration\"\nversion = \"1.0.0\"\n"
                    "[plugins.scale.jwt]\nsecret = \"test_secret\"\n"
                    "[plugins.scale.sso]\nhost = \"http://localhost:8000\"\n"
                    "[plugins.scale.admin]\nenabled = false\n"
                );
            }
            client = MongoClient(mongo_uri);
            db = client['jac_db'];
            old_password = "test_password";
            sha256_hash = hashlib.sha256(old_password.encode()).hexdigest();
            bcrypt_hash = IdentityStorage.hash_password('new_password');
            db.users.insert_many(
                [
                    {
                        'username': 'olduser1',
                        'password_hash': sha256_hash,
                        'token': 'tok1',
                        'root_id': 'r1',
                        'role': 'user',
                        'user_id': None
                    },
                    {
                        'username': 'admin',
                        'password_hash': sha256_hash,
                        'token': 'tok2',
                        'root_id': 'r2',
                        'role': 'admin',
                        'requires_password_reset': True,
                        'user_id': ADMIN_UUID
                    },
                    {
                        'username': 'user@example.com',
                        'password_hash': sha256_hash,
                        'token': 'tok3',
                        'root_id': 'r3',
                        'role': 'user',
                        'user_id': None
                    },
                    {
                        'user_id': NEW_USER_UUID,
                        'status': 'active',
                        'identities': [
                            {
                                'type': 'username',
                                'value_raw': 'newuser',
                                'value_normalized': 'newuser',
                                'verified': True
                            }
                        ],
                        'credentials': [
                            {'type': 'password', 'password_hash': bcrypt_hash}
                        ],
                        'root_id': 'r4',
                        'role': 'user',
                        'created_at': '2026-01-01T00:00:00+00:00',
                        'updated_at': '2026-01-01T00:00:00+00:00'
                    }
                ]
            );
            db.users.create_index('username', unique=True);
            db.users.create_index('token', unique=True, sparse=True);
            old_mongodb_uri = os.environ.get('MONGODB_URI');
            os.environ['MONGODB_URI'] = mongo_uri;
            try {
                reset_scale_config();
                um = JacScaleUserManager(base_path=tmpdir);

                # --- Migration: verify ran once, only on old docs ---
                migration = db['_migrations'].find_one(
                    {'name': 'legacy_user_migration'}
                );
                assert migration is not None and migration['count'] == 3;

                # All docs should be in new format now
                for doc in db.users.find() {
                    assert 'identities' in doc and 'credentials' in doc;
                    assert doc.get('user_id') is not None;
                    assert 'username' not in doc and 'token' not in doc;
                }

                # Identity type detection: email vs username
                assert um.find_user_by_identity('user@example.com')['identities'][0][
                    'type'
                ] == 'email';
                assert um.find_user_by_identity('olduser1')['identities'][0]['type'] == 'username';

                # Admin fields preserved
                admin_doc = db.users.find_one({'user_id': ADMIN_UUID});
                assert admin_doc.get('role') == 'admin';
                assert admin_doc.get('requires_password_reset') is True;

                # New-format user untouched
                new_doc = db.users.find_one({'user_id': NEW_USER_UUID});
                assert new_doc['credentials'][0]['password_hash'] == bcrypt_hash;
                assert 'algorithm' not in new_doc['credentials'][0];
                assert new_doc.get('created_at') == '2026-01-01T00:00:00+00:00';
                assert um.authenticate('newuser', 'new_password') is not None;

                # --- Progressive rehashing: SHA256 -> bcrypt ---
                auth = um.authenticate('olduser1', old_password);
                assert auth is not None;
                # Verify rehashed to bcrypt
                cred = db.users.find_one({'user_id': auth['user_id']})['credentials'][
                    0
                ];
                assert cred['password_hash'].startswith('$2b$');
                assert 'algorithm' not in cred;
                # Second login uses bcrypt directly
                assert um.authenticate('olduser1', old_password) is not None;
                # Wrong password fails
                assert um.authenticate('olduser1', 'wrong') is None;

                # --- Protected deletion ---
                assert 'error' in um.delete_user(ADMIN_UUID);
                guest = um.find_user_by_identity('__guest__');
                if guest {
                    assert 'error' in um.delete_user(guest['user_id']);
                }

                # --- Idempotency: second startup skips migration ---
                reset_scale_config();
                um2 = JacScaleUserManager(base_path=tmpdir);
                assert db['_migrations'].find_one({'name': 'legacy_user_migration'})[
                    'count'
                ] == 3;

                um.close();
                um2.close();
            } finally {
                if old_mongodb_uri is not None {
                    os.environ['MONGODB_URI'] = old_mongodb_uri;
                } else {
                    os.environ.pop('MONGODB_URI', None);
                }
                reset_scale_config();
                client.close();
            }
        }
    }
}


test "JAC_DATA_PATH redirects SQLite identity store away from base_path" {
    import tempfile;
    import from pathlib { Path }

    with tempfile.TemporaryDirectory() as base_dir {
        with tempfile.TemporaryDirectory() as data_dir {
            with open(os.path.join(base_dir, "jac.toml"), "w") as f {
                f.write('[project]\nname = "t"\nversion = "1.0.0"\n');
            }
            prev = os.environ.get('JAC_DATA_PATH');
            os.environ.pop('MONGODB_URI', None);
            os.environ['JAC_DATA_PATH'] = data_dir;
            try {
                reset_scale_config();
                JacScaleUserManager(base_path=base_dir);
                assert (Path(data_dir) / ".jac" / "data" / "users.db").exists();
                assert not (Path(base_dir) / ".jac" / "data" / "users.db").exists();
            } finally {
                if prev is None {
                    os.environ.pop('JAC_DATA_PATH', None);
                } else {
                    os.environ['JAC_DATA_PATH'] = prev;
                }
                reset_scale_config();
            }
        }
    }
}

# ============================================================================
# JWT cache + credential-epoch revocation tests (SQLite backend, no containers)
# ============================================================================
glob _JWT_TEST_TOML = (
         "[project]\nname = \"test-jwt-cache\"\nversion = \"1.0.0\"\n"
         "[plugins.scale.jwt]\nsecret = \"test_jwt_secret_x\"\n"
         "algorithm = \"HS256\"\nexp_delta_days = 1\n"
         "[plugins.scale.sso]\nhost = \"http://localhost:8000\"\n"
         "[plugins.scale.admin]\nenabled = false\n"
     );

def _jwt_make_manager(tmpdir: any) -> JacScaleUserManager {
    with open(os.path.join(str(tmpdir), "jac.toml"), "w") as f {
        f.write(_JWT_TEST_TOML);
    }
    os.environ.pop("MONGODB_URI", None);
    reset_scale_config();
    return JacScaleUserManager(base_path=str(tmpdir));
}

def _jwt_clear_caches {
    _decoded_token_cache.clear();
    _revocation_ts_cache.clear();
    _user_token_hashes.clear();
}

def _jwt_make_user(um: JacScaleUserManager, username: str) -> str {
    result = um.create_user(
        identities=[{'type': 'username', 'value': username}],
        credential={'type': 'password', 'password': 'pw_test_123'}
    );
    assert "user_id" in result , f"create_user failed: {result}";
    return str(result["user_id"]);
}


test "token issued before invalidate_user_tokens is rejected" {
    with tempfile.TemporaryDirectory() as tmpdir {
        um = _jwt_make_manager(tmpdir);
        try {
            user_id = _jwt_make_user(um, "rev_before");
            _jwt_clear_caches();

            token = um.create_jwt_token(user_id);
            time.sleep(0.02);  # ensure iat strictly precedes tokens_valid_from
            um.invalidate_user_tokens(user_id);

            assert um.validate_jwt_token(token) is None , (
                "Token issued before invalidate_user_tokens() must be rejected"
            );
        } finally {
            um.close();
            reset_scale_config();
        }
    }
}


test "token issued after invalidate_user_tokens is accepted" {
    with tempfile.TemporaryDirectory() as tmpdir {
        um = _jwt_make_manager(tmpdir);
        try {
            user_id = _jwt_make_user(um, "rev_after");
            _jwt_clear_caches();

            um.invalidate_user_tokens(user_id);
            time.sleep(0.02);  # ensure new iat strictly follows tokens_valid_from
            token = um.create_jwt_token(user_id);

            result = um.validate_jwt_token(token);
            assert result == user_id , (
                f"Token issued after invalidate_user_tokens() must be accepted, got {result}"
            );
        } finally {
            um.close();
            reset_scale_config();
        }
    }
}


test "password change immediately invalidates old token in same worker" {
    with tempfile.TemporaryDirectory() as tmpdir {
        um = _jwt_make_manager(tmpdir);
        try {
            user_id = _jwt_make_user(um, "pw_revoke");
            _jwt_clear_caches();

            old_token = um.create_jwt_token(user_id);
            # Seed L1 decode cache to verify eager eviction (not just L3 path)
            assert um.validate_jwt_token(old_token) == user_id;

            time.sleep(0.02);
            um.update_password(user_id, "pw_test_123", "new_pw_456");

            assert um.validate_jwt_token(old_token) is None , (
                "Token from before password change must be rejected"
            );

            time.sleep(0.02);
            new_token = um.create_jwt_token(user_id);
            assert um.validate_jwt_token(new_token) == user_id , (
                "Token issued after password change must be accepted"
            );
        } finally {
            um.close();
            reset_scale_config();
        }
    }
}


test "deleted user token is rejected immediately in same worker" {
    with tempfile.TemporaryDirectory() as tmpdir {
        um = _jwt_make_manager(tmpdir);
        try {
            user_id = _jwt_make_user(um, "del_revoke");
            _jwt_clear_caches();

            token = um.create_jwt_token(user_id);
            # Seed L1 decode cache to verify eager eviction on delete
            assert um.validate_jwt_token(token) == user_id;

            um.delete_user(user_id);

            assert um.validate_jwt_token(token) is None , (
                "Token for a deleted user must be rejected immediately in the same worker"
            );
        } finally {
            um.close();
            reset_scale_config();
        }
    }
}


test "cache overflow above TOKEN_CACHE_MAX_SIZE does not panic" {
    with tempfile.TemporaryDirectory() as tmpdir {
        um = _jwt_make_manager(tmpdir);
        try {
            user_id = _jwt_make_user(um, "cache_overflow");
            _jwt_clear_caches();

            # Fill cache past eviction threshold with synthetic entries
            fake_exp = time.monotonic() + 3600.0;
            for i in range(50001) {
                fake_hash = f"deadbeef{i:08d}";
                _decoded_token_cache[fake_hash] = (user_id, fake_exp);
                _user_token_hashes.setdefault(user_id, set()).add(fake_hash);
            }
            assert len(_decoded_token_cache) == 50001;

            token = um.create_jwt_token(user_id);
            validated = um.validate_jwt_token(token);
            assert validated == user_id , (
                f"Real token must validate after cache eviction, got {validated}"
            );
            assert len(_decoded_token_cache) == 1 , (
                f"Cache should hold exactly 1 entry after eviction, got {len(
                    _decoded_token_cache
                )}"
            );
        } finally {
            um.close();
            reset_scale_config();
        }
    }
}


test "tokens_valid_from absent on legacy user document is backward-compatible" {
    with tempfile.TemporaryDirectory() as tmpdir {
        um = _jwt_make_manager(tmpdir);
        try {
            user_id = _jwt_make_user(um, "legacy_user");
            _jwt_clear_caches();

            token = um.create_jwt_token(user_id);

            # Simulate a legacy doc where the field was never set (set to None)
            um._identity_storage.update_user_fields(
                user_id, {'tokens_valid_from': None}
            );

            # Token must still be accepted: None coerces to 0.0, all iat values pass
            assert um.validate_jwt_token(token) == user_id , (
                "Token must be accepted when tokens_valid_from is None (legacy user doc)"
            );
        } finally {
            um.close();
            reset_scale_config();
        }
    }
}
