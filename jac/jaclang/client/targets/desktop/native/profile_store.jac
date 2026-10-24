import json;
import os;
import secrets;
import threading;
import time;

glob PROFILE_SESSION_JS: str = (
         "(function(){try{var s=window.localStorage,x=new XMLHttpRequest();"
         + "x.open('POST','/__jac/profiles/session',false);x.send();"
         + "var t=x.status===200?JSON.parse(x.responseText).token:'';"
         + "if(t)s.setItem('jac_token',t);else s.removeItem('jac_token');}catch(e){}})();"
     ),
     MAX_PROFILE_NAME: int = 64;


obj LocalProfile {
    has id: str,
        name: str,
        user_id: str,
        created: float = 0.0;

    def public -> dict[str, any];
}


obj ProfileStore {
    has path: str,
        active: str = "",
        profiles: list[LocalProfile] = [],
        _lock: threading.Lock = threading.Lock();

    static def load(path: str) -> ProfileStore;
    def save;
    def find(profile_id: str) -> (LocalProfile | None);
    def describe -> dict[str, any];
    def add(name: str, user_id: str, profile_id: str) -> LocalProfile;
    def select(profile_id: str);
    def script -> str;
}

def new_profile_id -> str;

def clean_profile_name(name: str) -> str;

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
    for raw in data.get("profiles") or [] {
        if isinstance(raw, dict) and raw.get("id") and raw.get("user_id") {
            store.profiles.append(
                LocalProfile(
                    id=str(raw["id"]),
                    name=str(raw.get("name") or ""),
                    user_id=str(raw["user_id"]),
                    created=float(raw.get("created") or 0.0)
                )
            );
        }
    }
    active = str(data.get("active") or "");
    store.active = active if store.find(active) is not None else "";
    return store;
}

impl ProfileStore.save {
    os.makedirs(os.path.dirname(os.path.abspath(self.path)), exist_ok=True);
    tmp = self.path + ".tmp";
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
        made = LocalProfile(
            id=profile_id, name=name, user_id=user_id, created=time.time()
        );
        self.profiles.append(made);
        self.active = made.id;
        self.save();
        return made;
    }
}

impl ProfileStore.select(profile_id: str) {
    with self._lock {
        if profile_id and self.find(profile_id) is None {
            raise ValueError(f"unknown profile '{profile_id}'");
        }
        self.active = profile_id;
        self.save();
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
