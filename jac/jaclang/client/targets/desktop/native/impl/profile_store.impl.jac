impl LocalProfile.public -> dict[str, any] {
    return {"id": self.id, "name": self.name, "created": self.created};
}

impl ProfileStore.load(path: str) -> ProfileStore {
    store = ProfileStore(path=path, profiles=[]);
    try {
        with open(path, encoding="utf-8") as f {
            data = json.load(f);
        }
    } except (OSError, ValueError) {
        return store;
    }
    if not isinstance(data, dict) {
        return store;
    }
    raw_profiles = data.get("profiles");
    for raw in raw_profiles if isinstance(raw_profiles, list) else [] {
        if not isinstance(raw, dict) or not raw.get("id") or not raw.get("user_id") {
            continue;
        }
        try {
            created = float(raw.get("created") or 0.0);
        } except (TypeError, ValueError) {
            created = 0.0;
        }
        store.profiles.append(
            LocalProfile(
                id=str(raw["id"]),
                name=str(raw.get("name") or ""),
                user_id=str(raw["user_id"]),
                created=created
            )
        );
    }
    active = str(data.get("active") or "");
    store.active = active if store.find(active) is not None else "";
    return store;
}

impl ProfileStore.save {
    os.makedirs(os.path.dirname(os.path.abspath(self.path)), exist_ok=True);
    tmp = f"{self.path}.{os.getpid()}.{threading.get_ident()}.tmp";
    with open(tmp, "w", encoding="utf-8") as f {
        json.dump(
            {
                "active": self.active,
                "profiles": [
                    {
                        "id": p.id,
                        "name": p.name,
                        "user_id": p.user_id,
                        "created": p.created
                    } for p in self.profiles
                ]
            },
            f
        );
    }
    os.replace(tmp, self.path);
}

impl ProfileStore._lock_file -> any {
    os.makedirs(os.path.dirname(os.path.abspath(self.path)), exist_ok=True);
    handle = open(self.path + ".lock", "a+");
    if sys.platform == "win32" {
        msvcrt: any = importlib.import_module("msvcrt");
        handle.seek(0);
        while True {
            try {
                msvcrt.locking(handle.fileno(), msvcrt.LK_LOCK, 1);
                break;
            } except OSError {
                continue;
            }
        }
    } else {
        import fcntl;
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX);
    }
    return handle;
}

impl ProfileStore._unlock_file(handle: any) {
    if sys.platform == "win32" {
        msvcrt: any = importlib.import_module("msvcrt");
        handle.seek(0);
        msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1);
    }
    handle.close();
}

impl ProfileStore.load_for_write(path: str) -> ProfileStore {
    if not os.path.exists(path) {
        return ProfileStore(path=path, profiles=[]);
    }
    try {
        with open(path, encoding="utf-8") as f {
            data = json.load(f);
        }
    } except (OSError, ValueError) as e {
        raise RuntimeError(
            f"the saved profile list {path} cannot be read ({e}); not overwriting it"
        );
    }
    if not isinstance(data, dict) or not isinstance(data.get("profiles", []), list) {
        raise RuntimeError(
            f"the saved profile list {path} is not a profile list; not overwriting it"
        );
    }
    return ProfileStore.load(path);
}

impl ProfileStore._reload {
    fresh = ProfileStore.load_for_write(self.path);
    self.profiles = fresh.profiles;
    self.active = fresh.active;
}

impl ProfileStore.find(profile_id: str) -> (LocalProfile | None) {
    for p in self.profiles {
        if p.id == profile_id {
            return p;
        }
    }
    return None;
}

impl ProfileStore.describe -> dict[str, any] {
    return {"active": self.active, "profiles": [p.public() for p in self.profiles]};
}

impl ProfileStore.add(name: str, user_id: str, profile_id: str) -> LocalProfile {
    with self._lock {
        handle = self._lock_file();
        try {
            self._reload();
            made = LocalProfile(
                id=profile_id, name=name, user_id=user_id, created=time.time()
            );
            self.profiles.append(made);
            self.active = made.id;
            self.save();
            return made;
        } finally {
            self._unlock_file(handle);
        }
    }
}

impl ProfileStore.select(profile_id: str) {
    with self._lock {
        handle = self._lock_file();
        try {
            fresh = ProfileStore.load_for_write(self.path);
            self.profiles = fresh.profiles;
            if profile_id and fresh.find(profile_id) is None {
                raise ValueError(f"unknown profile '{profile_id}'");
            }
            self.active = profile_id;
            self.save();
        } finally {
            self._unlock_file(handle);
        }
    }
}

impl ProfileStore.script -> str {
    return "window.__JAC_PROFILES__="
        + json.dumps(self.describe())
        + ";\n"
        + PROFILE_SESSION_JS
        + "\n";
}

impl new_profile_id -> str {
    return secrets.token_hex(6);
}

impl clean_profile_name(name: str) -> str {
    cleaned = " ".join(str(name or "").split());
    if not cleaned {
        raise ValueError("a profile needs a name");
    }
    if len(cleaned) > MAX_PROFILE_NAME {
        raise ValueError(f"a profile name is at most {MAX_PROFILE_NAME} characters");
    }
    return cleaned;
}
