import from unittest.mock { MagicMock }
import from jaclang.scale.sso.github { GithubSSOProvider }

obj FakeTokens {
    has records: dict = {},
        counter: int = 0;

    def create_token(
        user_id: str, purpose: str, ttl_seconds: int, identity_value: str
    ) -> str {
        self.counter += 1;
        key = "s" * 42 + str(self.counter);
        self.records[key] = {
            "user_id": user_id,
            "purpose": purpose,
            "identity_value": identity_value
        };
        return key;
    }

    def peek_token(token: str, purpose: str) -> dict | None {
        record = self.records.get(token);
        return record if record and record["purpose"] == purpose else None;
    }

    def consume_token(token: str, purpose: str) -> dict | None {
        record = self.peek_token(token, purpose);
        if record {
            del self.records[token];
        }
        return record;
    }
}

def fake_users -> any {
    manager = MagicMock();
    manager.get_user_by_sso.return_value = None;
    manager.get_sso_accounts.return_value = [];
    manager.create_user.return_value = {"user_id": "new-user"};
    manager.link_sso_account.return_value = {};
    manager.create_jwt_token.return_value = "session-token";
    manager.get_user.return_value = {
        "profile": {},
        "identities": [
            {"type": "username", "value_raw": "alice", "value_normalized": "alice"}
        ]
    };
    return manager;
}

def provider -> GithubSSOProvider {
    return GithubSSOProvider(
        client_id="client",
        client_secret="secret",
        redirect_uri="https://example.test/callback"
    );
}
