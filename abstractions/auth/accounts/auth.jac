"""The standard auth: accounts of a username and a password, and their
sessions, in a SQLite file. A session's token is the caller's alone: the file
keeps its SHA-256.

- **A username** is 3 to 32 of `a-z`, `0-9`, `.`, `_` and `-`, starting with a
  letter or a digit, compared lowercased. So it is never an email address,
  which signing in also takes, and never holds `:`.
- **A password** has at least 8 characters, and is kept as a salted
  PBKDF2-HMAC-SHA256 hash.
- **Attempts are limited** in each 15 minutes, by the project's limits.
- **With `local_users`,** an app in a window of its own takes the people at
  its machine as its users, by a name each gives and no password: accounts
  whose provider is `local`.
- **With a GitHub OAuth app's client ID and secret where the program runs,**
  a caller may also sign in through GitHub: an account whose provider is
  `github`, known by GitHub's ID for the user and called by their login
  there. The caller is sent to GitHub and comes back to
  `/__jac/auth/github`, which is what the OAuth app registers as its
  callback."""

import base64;
import hashlib;
import hmac;
import json;
import os;
import re;
import secrets;
import threading;
import time;
import urllib.request;
import from urllib.parse { urlencode }
import from auth.contract {
    Auth,
    AuthHost,
    Rejected,
    Session,
    SignIn,
    SignInAction,
    SignInField,
    bearer_token,
}
import from common.contract { Secret }
import from sqlfile { Upgrade, open_db }

glob USERNAME: str = "[a-z0-9][a-z0-9._-]{2,31}",
     ACCOUNTS_FORMAT: int = 1,
     # The steps from each layout of the accounts file a release wrote to the
     # next: none yet, 1 being the first.
     ACCOUNTS_UPGRADES: list[Upgrade] = [],
     # Sign-in attempts allowed in each LIMIT_SECONDS: for one username (or
     # email) from one client address, and from one client address in all;
     # and registrations from one client address. Each attempt costs a
     # password hash.
     LOGIN_PER_USER: int = 5,
     LOGIN_PER_CLIENT: int = 30,
     REGISTER_PER_CLIENT: int = 10,
     LIMIT_SECONDS: int = 900,
     # How long a caller sent to another service has to come back, and how
     # long that service is waited for, in seconds.
     AWAY_SECONDS: int = 600,
     SERVICE_SECONDS: float = 20.0;

obj Accounts(Auth) {
    """The file: `accounts.db` in the app's data directory when it is not
    said."""
    has path: str = "",
        # How a password is kept: PBKDF2-HMAC-SHA256 with a salt of its own,
        # at OWASP's 600,000 rounds. A hash keeps its rounds, so raising
        # this applies to a password when it is next set.
        rounds: int = 600000,
        # How long a session lasts: a week.
        session_seconds: float = 604800.0,
        # Whether the people at the machine are the users of an app in a
        # window of its own, with no password.
        local_users: bool = False,
        # Whether an account is made only with an email address.
        email_required: bool = False,
        # A GitHub OAuth app's client ID and secret: signing in through
        # GitHub is offered where both are given.
        github_id: Secret = Secret(variable="SSO_GITHUB_CLIENT_ID"),
        github_secret: Secret = Secret(variable="SSO_GITHUB_CLIENT_SECRET"),
        # Where GitHub is, and its API: another for GitHub Enterprise.
        github: str = "https://github.com",
        github_api: str = "https://api.github.com",
        # Where callers reach the app (`https://example.org`), for the place
        # another service sends them back to. Not said, they are sent to the
        # callback the service has registered.
        origin: str = "";

    has db: any postinit;
    # What a call holds while it is at the file: the calls a server answers
    # at once share its one connection.
    has turn: any postinit;
    # What signs the `state` a caller sent to another service carries there
    # and back: this process's alone, so one who left comes back to it.
    has away_key: bytes postinit;
    # The program it was opened in, and what that says of it: the app's
    # data directory, and whether the app shows itself in a window.
    has host: dyn AuthHost | None postinit;
    has data_dir: str postinit;
    has windowed: bool postinit;
    # The GitHub OAuth app's client ID and secret, as the program gives
    # them: "" for one it gives none of.
    has github_client: str postinit;
    has github_client_secret: str postinit;

    def postinit {
        self.db = None;
        self.turn = threading.RLock();
        self.away_key = secrets.token_bytes(32);
        self.host = None;
        self.data_dir = "";
        self.windowed = False;
        self.github_client = "";
        self.github_client_secret = "";
    }

    def kept_as -> str {
        return self.path if self.path != "" else os.path.join(self.data_dir, "accounts.db");
    }

    def open(host: dyn AuthHost) {
        self.host = host;
        self.data_dir = host.data_dir();
        self.windowed = host.windowed();
        self.github_client = host.secret(self.github_id);
        self.github_client_secret = host.secret(self.github_secret);
        self.db = open_db(
            self.kept_as(),
            ACCOUNTS_FORMAT,
            [
                "create table users (username text primary key, email text, password text not null, created real)",
                # An account another service vouches for: its own namespace,
                # which no username reaches, since its user ID holds a `:`.
                "create table identities (provider text, external_id text, user_id text not null unique, created real, primary key (provider, external_id))",
                "create table sessions (token_hash text primary key, user_id text not null, expires real not null)",
            ],
            ACCOUNTS_UPGRADES,
            host,
        );
    }

    """Counts a use of `scope` by `actor` with the program's limits: how many
    seconds until it is within `limit` uses in `seconds`, 0 while it is."""
    def tried(scope: str, actor: str, limit: int, seconds: int) -> int {
        host = self.host;
        if host is None {
            raise RuntimeError("accounts was asked before it was opened");
        }
        return host.consume_limit(scope, actor, limit, seconds);
    }

    """Whether this app takes the people at its machine as its users: one in
    a window of its own, asked to."""
    def local -> bool {
        return self.local_users and self.windowed;
    }

    """Where an app with local users keeps who is using it now."""
    def local_file -> str {
        return os.path.join(self.data_dir, "local-user");
    }

    """Who of the app's local users is using it now: "" for no one."""
    def local_now -> str {
        try {
            with open(self.local_file()) as f {
                name = f.read().strip();
                return name if name in self.externals("local") else "";
            }
        } except OSError {
            return "";
        }
    }

    """The user ID the session a request carries names, while the session
    lasts."""
    def caller(headers: dict[str, str]) -> str | None {
        credential = bearer_token(headers);
        if credential == "" {
            return None;
        }
        key = token_key(credential);
        user: str | None = None;
        expires = 0.0;
        with self.turn {
            for r in self.db.execute(
                "select user_id, expires from sessions where token_hash = ?", (key,)
            ) {
                user = str(r[0]);
                expires = float(r[1]);
            }
            if user is not None and expires <= time.time() {
                self.db.execute("delete from sessions where token_hash = ?", (key,));
                self.db.commit();
                return None;
            }
        }
        return user;
    }

    """A username and a password, to sign in or to make an account; or, for
    an app with local users, the name of who is at the machine, and a
    session at once for the one who was there last."""
    def asks(headers: dict[str, str]) -> SignIn {
        if self.local() {
            now = self.local_now();
            if now != "" {
                return SignIn(session=self.external("local", now, now));
            }
            return SignIn(
                fields=[
                    SignInField(name="name", label="Your name", choices=self.externals("local")),
                ],
                actions=[SignInAction(name="local", label="Continue", needs=["name"])],
            );
        }
        actions = [
            SignInAction(name="login", label="Sign in", needs=["username", "password"]),
            SignInAction(
                name="register", label="Create account", needs=["username", "email", "password"]
            ),
        ];
        if self.github_offered() {
            actions.append(self.github_action());
        }
        return SignIn(
            fields=[
                SignInField(name="username", label="Username"),
                SignInField(
                    name="email", label="Email" if self.email_required else "Email (optional)"
                ),
                SignInField(name="password", label="Password", secret=True),
            ],
            actions=actions,
        );
    }

    """Whether a caller may sign in through GitHub: where the program runs
    gives the OAuth app's client ID and its secret."""
    def github_offered -> bool {
        return self.github_client != "" and self.github_client_secret != "";
    }

    """Where GitHub sends a caller back to, when this app says where it is
    reached: "" for the callback the OAuth app registers."""
    def github_back -> str {
        return self.origin.rstrip("/") + "/__jac/auth/github" if self.origin != "" else "";
    }

    """What signs a `state` that lasts until `expires` for the page that
    keeps `verifier`."""
    def away_mark(expires: int, verifier: str) -> str {
        said = (str(expires) + "." + verifier).encode("utf-8");
        return hmac.new(self.away_key, said, hashlib.sha256).hexdigest();
    }

    """Signing in through GitHub: the place to go, with a `state` only this
    process makes, and a verifier the page that leaves keeps. GitHub is given
    the verifier's hash now and the verifier when the caller is back (PKCE),
    and the state is signed over it: so the session is given to the page that
    left, and never to one that was only handed the way back."""
    def github_action -> SignInAction {
        verifier = secrets.token_urlsafe(48);
        expires = int(time.time()) + AWAY_SECONDS;
        challenge = base64.urlsafe_b64encode(
            hashlib.sha256(verifier.encode("ascii")).digest()
        ).decode("ascii").rstrip("=");
        query: dict[str, str] = {
            "client_id": self.github_client,
            "state": str(expires) + "." + self.away_mark(expires, verifier),
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        };
        back = self.github_back();
        if back != "" {
            query["redirect_uri"] = back;
        }
        return SignInAction(
            name="github",
            label="Continue with GitHub",
            redirect=self.github.rstrip("/") + "/login/oauth/authorize?" + urlencode(query),
            keeps={"verifier": verifier},
        );
    }

    """The session of the GitHub user a caller came back as: `given` holds
    the `code` and `state` GitHub sent them back with, and the `verifier`
    their page kept."""
    def github_answer(given: dict[str, str]) -> Session {
        if given.get("error", "") != "" {
            raise Rejected(detail="signing in through GitHub was turned away there");
        }
        verifier = given.get("verifier", "");
        (expires_said, dot, mark) = given.get("state", "").partition(".");
        if dot == ""
            or not expires_said.isdigit()
            or verifier == ""
            or not hmac.compare_digest(mark, self.away_mark(int(expires_said), verifier))
        {
            raise Rejected(detail="this sign-in was not begun here: try again");
        }
        if int(expires_said) < time.time() {
            raise Rejected(detail="this sign-in took too long: try again");
        }
        exchange: dict[str, str] = {
            "client_id": self.github_client,
            "client_secret": self.github_client_secret,
            "code": given.get("code", ""),
            "code_verifier": verifier,
        };
        back = self.github_back();
        if back != "" {
            exchange["redirect_uri"] = back;
        }
        try {
            got = asked_json(
                self.github.rstrip("/") + "/login/oauth/access_token",
                {"Accept": "application/json"},
                urlencode(exchange).encode("utf-8"),
            );
            access = str(got.get("access_token", ""));
            if access == "" {
                raise Rejected(detail="GitHub did not accept the sign-in");
            }
            me = asked_json(
                self.github_api.rstrip("/") + "/user",
                {
                    "Authorization": "Bearer " + access,
                    "Accept": "application/vnd.github+json",
                    "User-Agent": "jac-accounts",
                },
            );
        } except OSError {
            raise Rejected(detail="GitHub could not be reached: try again");
        } except ValueError {
            raise Rejected(detail="GitHub's answer could not be read: try again");
        }
        if "id" not in me {
            raise Rejected(detail="GitHub did not say who signed in");
        }
        return self.external("github", str(me["id"]), str(me.get("login", "")));
    }

    def answer(action: str, given: dict[str, str], client: str) -> Session {
        name = given.get("username", "");
        retry = 0;
        if action == "local" and self.local() {
            who = given.get("name", "").strip();
            s = self.external("local", who, who);
            os.makedirs(self.data_dir, exist_ok=True);
            with open(self.local_file(), "w") as f {
                f.write(who + "\n");
            }
            return s;
        }
        if action == "login" {
            # The client's attempts first: a client over its limit counts
            # against no username. Then this username's from this client
            # (its address, which holds no space, ahead of the name): a
            # username's attempts from elsewhere are their own, so guessing
            # wrong locks no one else out.
            retry = self.tried("login", "client " + client, LOGIN_PER_CLIENT, LIMIT_SECONDS);
            if retry == 0 {
                retry = self.tried(
                    "login",
                    "user " + client + " " + name.strip().lower(),
                    LOGIN_PER_USER,
                    LIMIT_SECONDS,
                );
            }
        } elif action == "register" {
            retry = self.tried("register", client, REGISTER_PER_CLIENT, LIMIT_SECONDS);
        } elif action == "github" and self.github_offered() {
            # (Each costs two requests of GitHub.)
            retry = self.tried("github", client, LOGIN_PER_CLIENT, LIMIT_SECONDS);
        } else {
            raise Rejected(detail=f"no way of signing in is '{action}'");
        }
        if retry > 0 {
            raise Rejected(detail="too many attempts: try again later", retry_after=retry);
        }
        if action == "login" {
            return self.login(name, given.get("password", ""));
        }
        if action == "github" {
            return self.github_answer(given);
        }
        return self.register(name, given.get("email", ""), given.get("password", ""));
    }

    def leave(headers: dict[str, str]) {
        self.end(bearer_token(headers));
        if self.local() and os.path.exists(self.local_file()) {
            os.remove(self.local_file());
        }
    }

    """A new session for `user`: its token."""
    def token_for(user: str) -> str {
        now = time.time();
        t = secrets.token_hex(32);
        with self.turn {
            self.db.execute("delete from sessions where expires <= ?", (now,));
            self.db.execute(
                "insert into sessions values (?, ?, ?)",
                (token_key(t), user, now + self.session_seconds),
            );
            self.db.commit();
        }
        return t;
    }

    """End the session `credential` names, if it is one."""
    def end(credential: str) {
        with self.turn {
            self.db.execute("delete from sessions where token_hash = ?", (token_key(credential),));
            self.db.commit();
        }
    }

    def register(username: str, email: str, password: str) -> Session {
        u = username.strip().lower();
        if re.fullmatch(USERNAME, u) is None {
            raise Rejected(
                detail="a username is 3 to 32 letters, digits, '.', '_' or '-', starting with a letter or a digit",
            );
        }
        e = email.strip().lower();
        if e == "" and self.email_required {
            raise Rejected(detail="an account needs an email address");
        }
        if e != "" and (len(e) > 254 or re.fullmatch(r"[^@\s]+@[^@\s]+", e) is None) {
            raise Rejected(detail="that isn't an email address");
        }
        if len(password) < 8 {
            raise Rejected(detail="a password has at least 8 characters");
        }
        # (Hashed before the file is held: it takes a while, by design.)
        record = password_record(password, self.rounds);
        with self.turn {
            for r in self.db.execute(
                "select username from users where username = ? or (email != '' and email = ?)",
                (u, e),
            ) {
                raise Rejected(detail="that username or email is taken");
            }
            self.db.execute("insert into users values (?, ?, ?, ?)", (u, e, record, time.time()));
            self.db.commit();
        }
        return Session(user=u, token=self.token_for(u));
    }

    """A session for the account `username` (or its email) names, if
    `password` is its password. An unknown account costs the same hash, so the
    time taken doesn't say which accounts exist."""
    def login(username: str, password: str) -> Session {
        u = username.strip().lower();
        user = "";
        record = "pbkdf2_sha256$" + str(self.rounds) + "$" + "00" * 16 + "$" + "00" * 32;
        with self.turn {
            for r in self.db.execute(
                "select username, password from users where username = ? or (email != '' and email = ?)",
                (u, u),
            ) {
                user = str(r[0]);
                record = str(r[1]);
            }
        }
        if not password_matches(password, record) or user == "" {
            raise Rejected(detail="incorrect username or password");
        }
        return Session(user=user, token=self.token_for(user));
    }

    """A session for the user `provider` (a name of a-z, 0-9, `_` and `-`)
    knows as `external_id` and calls `name`, their account made the first
    time: its user ID is `provider:external_id`."""
    def external(provider: str, external_id: str, name: str = "") -> Session {
        if re.fullmatch("[a-z0-9_-]{1,32}", provider) is None
            or external_id == ""
            or len(external_id) > 256
        {
            raise Rejected(
                detail="an external identity is a provider's name and its ID for the user"
            );
        }
        user = "";
        with self.turn {
            for r in self.db.execute(
                "select user_id from identities where provider = ? and external_id = ?",
                (provider, external_id),
            ) {
                user = str(r[0]);
            }
            if user == "" {
                user = provider + ":" + external_id;
                self.db.execute(
                    "insert into identities values (?, ?, ?, ?)",
                    (provider, external_id, user, time.time()),
                );
                self.db.commit();
            }
        }
        return Session(user=user, token=self.token_for(user), name=name);
    }

    """Each user `provider` knows, by its ID for them, in the order their
    accounts were made."""
    def externals(provider: str) -> list[str] {
        out: list[str] = [];
        with self.turn {
            for r in self.db.execute(
                "select external_id from identities where provider = ? order by created",
                (provider,),
            ) {
                out.append(str(r[0]));
            }
        }
        return out;
    }
}

"""What the service at `url` answers a request with `headers`, a JSON
object: a POST of `body` when there is one. OSError where it is not reached
or refuses, ValueError for an answer that is not one."""
def asked_json(url: str, headers: dict[str, str], body: bytes | None = None) -> dict[str, any] {
    req = urllib.request.Request(url, data=body, headers=headers);
    with urllib.request.urlopen(req, timeout=SERVICE_SECONDS) as r {
        got: any = json.loads(r.read().decode("utf-8"));
    }
    if not isinstance(got, dict) {
        raise ValueError("not a JSON object");
    }
    made: dict[str, any] = got;
    return made;
}

"""What the accounts file keeps of a session's token."""
def token_key(token: str) -> str {
    return hashlib.sha256(token.encode("utf-8")).hexdigest();
}

"""How the accounts file keeps `password`:
`pbkdf2_sha256$<rounds>$<salt>$<key>`, the salt fresh and both in hex."""
def password_record(password: str, rounds: int) -> str {
    salt = secrets.token_bytes(16);
    key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, rounds);
    return "pbkdf2_sha256$" + str(rounds) + "$" + salt.hex() + "$" + key.hex();
}

"""Whether `password` is the one `record` keeps, compared in constant time."""
def password_matches(password: str, record: str) -> bool {
    parts = record.split("$");
    if len(parts) != 4 or parts[0] != "pbkdf2_sha256" {
        raise ValueError("a password record of an unknown kind");
    }
    key = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), bytes.fromhex(parts[2]), int(parts[1])
    );
    return hmac.compare_digest(key, bytes.fromhex(parts[3]));
}
