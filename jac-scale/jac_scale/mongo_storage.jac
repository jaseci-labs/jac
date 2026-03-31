"""MongoDB storage backend for user management."""

import hashlib;
import from datetime { UTC, datetime }
import from typing { Any }
import from pymongo.collection { Collection }
import from jaclang.jac0core.constant { Constants as Con }

obj MongoUserStorage {
    has users_col: Collection,
        sso_col: Collection;

    def create_user(username: str, password: str) -> dict[str, str] {
        import from jaclang.jac0core.constructs { Root }
        import from jaclang { JacRuntime as Jac }
        import secrets;

        if self.users_col.count_documents({'username': username}, limit=1) > 0 {
            return {'error': 'User already exists'};
        }
        user_root = Root();
        Jac.save(user_root);
        Jac.commit(user_root);
        root_id = user_root.__jac__.id.hex;
        token = secrets.token_urlsafe(32);
        password_hash = hashlib.sha256(password.encode()).hexdigest();
        self.users_col.insert_one(
            {
                'username': username,
                'password_hash': password_hash,
                'token': token,
                'root_id': root_id,
                'role': 'user',
                'requires_password_reset': False,
                'is_password_required': True,
                'user_id': None
            }
        );
        return {'username': username, 'token': token, 'root_id': root_id};
    }

    def authenticate(username: str, password: str) -> (dict[str, str] | None) {
        password_hash = hashlib.sha256(password.encode()).hexdigest();
        user = self.users_col.find_one(
            {'username': username, 'password_hash': password_hash},
            {'token': 1, 'root_id': 1, '_id': 0}
        );
        if user {
            return {
                'username': username,
                'token': user['token'],
                'root_id': user['root_id']
            };
        }
        return None;
    }

    def get_root_id(username: str) -> (str | None) {
        user = self.users_col.find_one({'username': username}, {'root_id': 1, '_id': 0});
        return user['root_id'] if user else None;
    }

    def get_user(username: str) -> (dict[str, str] | None) {
        user = self.users_col.find_one(
            {'username': username}, {'token': 1, 'root_id': 1, '_id': 0}
        );
        if not user {
            return None;
        }
        return {'email': username, 'token': user['token'], 'root_id': user['root_id']};
    }

    def user_exists(username: str) -> bool {
        return self.users_col.count_documents({'username': username}, limit=1) > 0;
    }

    def update_username(current_username: str, new_username: str) -> dict[str, str] {
        if self.users_col.count_documents({'username': new_username}, limit=1) > 0 {
            return {'error': 'Username already taken'};
        }
        result = self.users_col.update_one(
            {'username': current_username}, {'$set': {'username': new_username}}
        );
        if result.modified_count == 0 {
            return {'error': 'User not found'};
        }
        self.sso_col.update_many(
            {'user_id': current_username}, {'$set': {'user_id': new_username}}
        );
        user = self.users_col.find_one(
            {'username': new_username}, {'token': 1, 'root_id': 1, '_id': 0}
        );
        if not user {
            return {'error': 'User not found after update'};
        }
        return {
            'username': new_username,
            'token': user['token'],
            'root_id': user['root_id']
        };
    }

    def update_password(
        username: str, current_password: str, new_password: str
    ) -> dict[str, str] {
        current_hash = hashlib.sha256(current_password.encode()).hexdigest();
        user = self.users_col.find_one(
            {'username': username}, {'password_hash': 1, '_id': 0}
        );
        if self.users_col.count_documents(
            {'username': username, 'password_hash': current_hash}, limit=1
        ) == 0 {
            return {'error': 'Current password is incorrect'};
        }
        new_hash = hashlib.sha256(new_password.encode()).hexdigest();
        self.users_col.update_one(
            {'username': username}, {'$set': {'password_hash': new_hash}}
        );
        return {'username': username, 'message': 'Password updated successfully'};
    }

    def link_sso_account(
        user_id: str, platform: str, external_id: str, email: str
    ) -> dict[str, str] {
        existing = self.sso_col.find_one(
            {'platform': platform, 'external_id': external_id}
        );
        if existing {
            if existing['user_id'] == user_id {
                return {'message': 'SSO account already linked to this user'};
            }
            return {'error': 'This SSO account is already linked to another user'};
        }
        self.sso_col.insert_one(
            {
                'user_id': user_id,
                'platform': platform,
                'external_id': external_id,
                'email': email,
                'linked_at': datetime.now(UTC)
            }
        );
        return {
            'message': 'SSO account linked successfully',
            'user_id': user_id,
            'platform': platform
        };
    }

    def unlink_sso_account(user_id: str, platform: str) -> dict[str, str] {
        result = self.sso_col.delete_one({'user_id': user_id, 'platform': platform});
        if result.deleted_count == 0 {
            return {'error': 'SSO account not found'};
        }
        return {
            'message': 'SSO account unlinked successfully',
            'user_id': user_id,
            'platform': platform
        };
    }

    def get_sso_accounts(user_id: str) -> list[dict[str, str]] {
        cursor = self.sso_col.find(
            {'user_id': user_id},
            {'_id': 0, 'platform': 1, 'external_id': 1, 'email': 1, 'linked_at': 1}
        ).sort(
            'linked_at', -1
        );
        accounts: list[dict[str, str]] = [];
        for doc in cursor {
            accounts.append(
                {
                    'platform': doc['platform'],
                    'external_id': doc['external_id'],
                    'email': doc.get('email', ''),
                    'linked_at': str(doc.get('linked_at', ''))
                }
            );
        }
        return accounts;
    }

    def get_user_by_sso(platform: str, external_id: str) -> (dict[str, str] | None) {
        sso_doc = self.sso_col.find_one(
            {'platform': platform, 'external_id': external_id}
        );
        if not sso_doc {
            return None;
        }
        user = self.users_col.find_one(
            {'username': sso_doc['user_id']}, {'token': 1, 'root_id': 1, '_id': 0}
        );
        if not user {
            return None;
        }
        return {
            'email': sso_doc['user_id'],
            'token': user['token'],
            'root_id': user['root_id']
        };
    }

    def get_user_role(username: str) -> (str | None) {
        user = self.users_col.find_one({'username': username}, {'role': 1, '_id': 0});
        if not user {
            return None;
        }
        return user.get('role', 'user') or 'user';
    }

    def set_user_role(username: str, role: str) -> dict[str, str] {
        result = self.users_col.update_one(
            {'username': username}, {'$set': {'role': role}}
        );
        if result.matched_count == 0 {
            return {'error': 'User not found'};
        }
        return {
            'message': f"Role updated to '{role}'",
            'username': username,
            'role': role
        };
    }

    def requires_password_reset(username: str) -> bool {
        user = self.users_col.find_one(
            {'username': username}, {'requires_password_reset': 1, '_id': 0}
        );
        if not user {
            return False;
        }
        return bool(user.get('requires_password_reset', False));
    }

    def set_requires_password_reset(
        username: str, requires_reset: bool
    ) -> dict[str, str] {
        result = self.users_col.update_one(
            {'username': username},
            {'$set': {'requires_password_reset': requires_reset}}
        );
        if result.matched_count == 0 {
            return {'error': 'User not found'};
        }
        return {'message': 'Password reset requirement updated', 'username': username};
    }

    def is_password_required(username: str) -> bool {
        user = self.users_col.find_one(
            {'username': username}, {'is_password_required': 1, '_id': 0}
        );
        if not user {
            return True;
        }
        val = user.get('is_password_required');
        return bool(val) if val is not None else True;
    }

    def set_password_required(username: str, required: bool) -> dict[str, str] {
        result = self.users_col.update_one(
            {'username': username}, {'$set': {'is_password_required': required}}
        );
        if result.matched_count == 0 {
            return {'error': 'User not found'};
        }
        return {'message': 'Password requirement updated', 'username': username};
    }

    def list_all_users(limit: int = 100, offset: int = 0) -> list[dict[str, Any]] {
        cursor = self.users_col.find(
            {'username': {'$ne': Con.GUEST.value}}, {'_id': 0, 'password_hash': 0}
        ).sort(
            'username', 1
        ).skip(
            offset
        ).limit(
            limit
        );
        users: list[dict[str, Any]] = [];
        for doc in cursor {
            users.append(
                {
                    'username': doc.get('username', ''),
                    'root_id': doc.get('root_id', ''),
                    'role': doc.get('role', 'user') or 'user',
                    'requires_password_reset': bool(
                        doc.get('requires_password_reset', False)
                    ),
                    'is_password_required': bool(
                        doc.get('is_password_required', True)
                    )
                        if doc.get('is_password_required') is not None
                        else True,
                    'user_id': doc.get('user_id')
                }
            );
        }
        return users;
    }

    def delete_user(username: str, admin_user_id: str) -> dict[str, str] {
        user = self.users_col.find_one({'username': username}, {'user_id': 1, '_id': 0});
        if user and user.get('user_id') == admin_user_id {
            return {'error': 'Cannot delete the primary admin user'};
        }
        result = self.users_col.delete_one({'username': username});
        if result.deleted_count == 0 {
            return {'error': 'User not found'};
        }
        self.sso_col.delete_many({'user_id': username});
        return {'message': 'User deleted successfully', 'username': username};
    }

    def update_user_fields(username: str, fields: dict[str, Any]) -> bool {
        result = self.users_col.update_one({'username': username}, {'$set': fields});
        return result.matched_count > 0;
    }
}
