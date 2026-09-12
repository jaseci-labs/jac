"""Ownership-aware identity uniqueness (#9103).

An identity value is refused only when a different account holds it. The same
account may hold one value under more than one type (an email-shaped username
plus the matching email identity), and renaming a username never frees a lookup
row that another identity on the same account still uses.
"""

import shutil;
import uuid;
import from tempfile { mkdtemp }
import from jaclang.server.identity.identity_storage { IdentityTakenError }
import from jaclang.server.identity.user_manager { UserManager }


def _manager -> tuple[str, UserManager] {
    test_dir = mkdtemp();
    return (test_dir, UserManager(base_path=test_dir));
}


def _email_identity(value: str) -> dict[str, any] {
    return {
        'type': 'email',
        'value_raw': value,
        'value_normalized': value.lower().strip(),
        'verified': False,
        'is_recovery': False
    };
}


def _username_identity(value: str) -> dict[str, any] {
    return {
        'type': 'username',
        'value_raw': value,
        'value_normalized': value.lower().strip(),
        'verified': True,
        'is_recovery': False
    };
}


def _types_holding(users: UserManager, user_id: str, value: str) -> list[str] {
    user = users.get_user(user_id) or {};
    return [
        str(i.get('type'))
        for i in user.get('identities', [])
        if i.get('value_normalized') == value
    ];
}


def _refused(users: UserManager, user_id: str, identity: dict[str, any]) -> bool {
    try {
        users.add_identity(user_id, identity);
    } except IdentityTakenError {
        return True;
    }
    return False;
}


test "email-shaped username can attach the same address as an email identity" {
    (test_dir, users) = _manager();
    try {
        addr = f"owner_{uuid.uuid4().hex[:8]}@example.com";
        user_id = str(users.create_user(addr, 'pw12345')['user_id']);
        assert users.add_identity(user_id, _email_identity(addr));
        assert _types_holding(users, user_id, addr) == ['username', 'email'];
        assert users.set_identity_verified(user_id, addr);
        found = users.find_user_by_identity(addr) or {};
        assert str(found.get('user_id')) == user_id;
    } finally {
        shutil.rmtree(test_dir, ignore_errors=True);
    }
}


test "a value held by another account is still refused" {
    (test_dir, users) = _manager();
    try {
        tag = uuid.uuid4().hex[:8];
        addr = f"holder_{tag}@example.com";
        holder_id = str(users.create_user(addr, 'pw12345')['user_id']);
        other_id = str(users.create_user(f"other_{tag}", 'pw12345')['user_id']);
        assert _refused(users, other_id, _email_identity(addr));
        assert _types_holding(users, other_id, addr) == [];
        assert users.create_user(addr, 'pw12345').get('code') == 'IDENTITY_TAKEN';
        renamed = users.rename_username(other_id, addr);
        assert renamed.get('code') == 'IDENTITY_TAKEN';
        found = users.find_user_by_identity(addr) or {};
        assert str(found.get('user_id')) == holder_id;
    } finally {
        shutil.rmtree(test_dir, ignore_errors=True);
    }
}


test "an identity already held under the same type is refused" {
    (test_dir, users) = _manager();
    try {
        tag = uuid.uuid4().hex[:8];
        name = f"dup_{tag}";
        addr = f"dup_{tag}@example.com";
        user_id = str(users.create_user(name, 'pw12345')['user_id']);
        assert users.add_identity(user_id, _email_identity(addr));
        assert _refused(users, user_id, _email_identity(addr));
        assert _refused(users, user_id, _username_identity(name));
        assert _types_holding(users, user_id, addr) == ['email'];
        assert _types_holding(users, user_id, name) == ['username'];
    } finally {
        shutil.rmtree(test_dir, ignore_errors=True);
    }
}


test "the same-account duplicate decision is made inside the database" {
    (test_dir, users) = _manager();
    try {
        tag = uuid.uuid4().hex[:8];
        addr = f"atomic_{tag}@example.com";
        user_id = str(users.create_user(f"atomic_{tag}", 'pw12345')['user_id']);
        storage = users._identity_storage;
        assert storage._append_identity(user_id, _email_identity(addr));
        assert not storage._append_identity(user_id, _email_identity(addr));
        assert _types_holding(users, user_id, addr) == ['email'];
        assert not storage._append_identity(f"missing_{tag}", _email_identity(addr));
        assert users.add_identity(user_id, _username_identity(addr));
        assert _types_holding(users, user_id, addr) == ['email', 'username'];
    } finally {
        shutil.rmtree(test_dir, ignore_errors=True);
    }
}


test "username may be renamed to the account's own email address" {
    (test_dir, users) = _manager();
    try {
        tag = uuid.uuid4().hex[:8];
        addr = f"mine_{tag}@example.com";
        user_id = str(users.create_user(f"mine_{tag}", 'pw12345')['user_id']);
        assert users.add_identity(user_id, _email_identity(addr));
        renamed = users.rename_username(user_id, addr);
        assert 'error' not in renamed , renamed;
        assert renamed.get('username') == addr;
        assert _types_holding(users, user_id, addr) == ['username', 'email'];
        assert users.find_user_by_identity(f"mine_{tag}") is None;
        assert users.authenticate(addr, 'pw12345') is not None;
    } finally {
        shutil.rmtree(test_dir, ignore_errors=True);
    }
}


test "renaming a username away keeps a shared value on the email identity" {
    (test_dir, users) = _manager();
    try {
        tag = uuid.uuid4().hex[:8];
        addr = f"shared_{tag}@example.com";
        created = users.create_user_with_identities(
            [{'type': 'username', 'value': addr}, {'type': 'email', 'value': addr}],
            {'type': 'password', 'password': 'pw12345'}
        );
        user_id = str(created['user_id']);
        assert _types_holding(users, user_id, addr) == ['username', 'email'];
        first = users.rename_username(user_id, f"plain_{tag}");
        assert 'error' not in first , first;
        assert _types_holding(users, user_id, addr) == ['email'];
        assert users.authenticate(addr, 'pw12345') is not None;
        assert users.authenticate(f"plain_{tag}", 'pw12345') is not None;
        second = users.rename_username(user_id, f"plainer_{tag}");
        assert 'error' not in second , second;
        assert users.find_user_by_identity(f"plain_{tag}") is None;
        assert users.authenticate(addr, 'pw12345') is not None;
    } finally {
        shutil.rmtree(test_dir, ignore_errors=True);
    }
}
