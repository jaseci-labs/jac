"""UserManager implementations."""
import hashlib;
import secrets;
import from jaclang.runtimelib.server.infra { DataStore, Infra, FileStore }
import from jaclang.runtimelib.server.user_manager { UserManager }
import from jaclang { JacRuntime as Jac }

"""Initialize UserManager with optional data store."""
impl UserManager.init(session_path: str, data_store: (DataStore | None) = None) -> None {
    self.session_path = session_path;
    if data_store {
        self._data_store = data_store;
    } else {
        # Default to file-based store
        file_store = FileStore();
        file_store.init({'path': f"{session_path}.users.json"});
        self._data_store = file_store;
    }
    self._load_db();
}

impl UserManager.postinit -> None {
    # If init wasn't called, use default file store
    if not self._data_store {
        file_store = FileStore();
        file_store.init({'path': f"{self.session_path}.users.json"});
        self._data_store = file_store;
        self._load_db();
    }
}

"""Load user data from persistent storage."""
impl UserManager._load_db -> None {
    if not self._data_store {
        (self._users, self._tokens) = ({}, {});
        return;
    }
    try {
        users_data = self._data_store.get('__jac_users__');
        tokens_data = self._data_store.get('__jac_tokens__');
        self._users = users_data if users_data else {};
        self._tokens = tokens_data if tokens_data else {};
    } except Exception {
        (self._users, self._tokens) = ({}, {});
    }
}

"""Save user data to persistent storage."""
impl UserManager._persist -> None {
    if not self._data_store {
        return;
    }
    try {
        self._data_store.set('__jac_users__', self._users);
        self._data_store.set('__jac_tokens__', self._tokens);
    } except Exception {
        pass;
    }
}

"""Create a new user with their own root node. Returns dict with user data or error."""
impl UserManager.create_user(username: str, password: str) -> dict[str, str] {
    import from jaclang.pycore.constructs { Root }
    if (username in self._users) {
        return {'error': 'User already exists'};
    }
    # Use existing context instead of creating new one (avoids shelf locking issues)
    ctx = Jac.get_context();
    user_root = Root();
    root_anchor = user_root.__jac__;
    Jac.save(root_anchor);
    Jac.commit(root_anchor);
    root_id = root_anchor.id.hex;
    token = secrets.token_urlsafe(32);
    password_hash = hashlib.sha256(password.encode()).hexdigest();
    self._users[username] = {
        'password_hash': password_hash,
        'token': token,
        'root_id': root_id
    };
    self._tokens[token] = username;
    self._persist();
    return {'username': username, 'token': token, 'root_id': root_id};
}

"""Authenticate a user and return their data."""
impl UserManager.authenticate(
    username: str, password: str
) -> (dict[(str, str)] | None) {
    if (username not in self._users) {
        return None;
    }
    user = self._users[username];
    password_hash = hashlib.sha256(password.encode()).hexdigest();
    if (user['password_hash'] == password_hash) {
        return {
            'username': username,
            'token': user['token'],
            'root_id': user['root_id']
        };
    }
    return None;
}

"""Validate token and return username."""
impl UserManager.validate_token(token: str) -> (str | None) {
    return self._tokens.get(token);
}

"""Get user's root node ID."""
impl UserManager.get_root_id(username: str) -> (str | None) {
    return self._users[username]['root_id'] if (username in self._users) else None;
}

"""Get user data by username."""
impl UserManager.get_user(username: str) -> (dict[(str, str)] | None) {
    if (username not in self._users) {
        return None;
    }
    user = self._users[username];
    return {'email': username, 'token': user['token'], 'root_id': user['root_id']};
}

"""Close and persist user data."""
impl UserManager.close -> None {
    self._persist();
    if self._data_store {
        self._data_store.close();
    }
}

