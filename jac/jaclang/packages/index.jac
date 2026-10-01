import hashlib;
import json;
import os;
import time;
import urllib.error;
import urllib.request;
import from pathlib { Path }
import from urllib.parse { urljoin, urlsplit }
import from jaclang.project.package_scope { is_package_name }

glob DEFAULT_REGISTRY_NAME: str = "jaseci",
     DEFAULT_REGISTRY_URL: str = "https://raw.githubusercontent.com/jaseci-labs/jac-index/main/",
     REGISTRY_ENV: str = "JAC_REGISTRY",
     PROTOCOL_VERSION: int = 1,
     SETTINGS_NAME: str = "config.json",
     INDEX_DIR: str = "index",
     API_DIR: str = "api",
     GITHUB_API: str = "https://api.github.com",
     USER_AGENT: str = "jac-packages";

obj RegistryError(Exception) {}

obj IndexEntry {
    has name: str,
        version: str,
        sha256: str,
        role: str = "lib",
        description: str = "",
        deps: dict[str, str] = {},
        pypi: dict[str, str] = {},
        npm: dict[str, str] = {},
        jac_version: str = "",
        api_digest: str = "",
        exports: list[str] = [],
        pinned: list[str] = [],
        yanked: bool = False,
        published: str = "",
        source: str = "",
        upload: str = "";

    static def from_json(row: dict[str, any]) -> IndexEntry {
        for key in ("name", "version", "sha256") {
            if not isinstance(row.get(key), str) or not row.get(key) {
                raise RegistryError(f"index entry is missing '{key}': {row}");
            }
        }
        return IndexEntry(
            name=row["name"],
            version=row["version"],
            sha256=row["sha256"],
            role=str(row.get("role", "lib")),
            description=str(row.get("description", "")),
            deps=_str_map(row.get("deps")),
            pypi=_str_map(row.get("pypi")),
            npm=_str_map(row.get("npm")),
            jac_version=str(row.get("jac_version", "")),
            api_digest=str(row.get("api_digest", "")),
            exports=[str(x) for x in row.get("exports", [])],
            pinned=[str(x) for x in row.get("pinned", [])],
            yanked=bool(row.get("yanked", False)),
            published=str(row.get("published", "")),
            source=str(row.get("source", "")),
            upload=str(row.get("upload", ""))
        );
    }

    def to_json -> dict[str, any] {
        row: dict[str, any] = {
            "name": self.name,
            "version": self.version,
            "sha256": self.sha256,
            "role": self.role,
            "deps": self.deps,
            "jac_version": self.jac_version,
            "api_digest": self.api_digest,
            "exports": self.exports,
            "pinned": self.pinned,
            "yanked": self.yanked,
            "published": self.published,
            "source": self.source
        };
        if self.description {
            row["description"] = self.description;
        }
        if self.pypi {
            row["pypi"] = self.pypi;
        }
        if self.npm {
            row["npm"] = self.npm;
        }
        if self.upload {
            row["upload"] = self.upload;
        }
        return row;
    }

    def to_line -> str {
        return json.dumps(self.to_json(), sort_keys=True, separators=(",", ":"));
    }
}

def _str_map(raw: any) -> dict[str, str] {
    if not isinstance(raw, dict) {
        return {};
    }
    return {str(k): str(v) for (k, v) in raw.items()};
}

def parse_index_lines(text: str) -> list[IndexEntry] {
    entries: list[IndexEntry] = [];
    for line in text.splitlines() {
        if line.strip() {
            entries.append(IndexEntry.from_json(json.loads(line)));
        }
    }
    return entries;
}

def index_rel_path(name: str) -> str {
    if not is_package_name(name) {
        raise RegistryError(f"'{name}' is not a package name (org/name)");
    }
    return f"{INDEX_DIR}/{name}.json";
}

def api_rel_path(name: str, version: str) -> str {
    if not is_package_name(name) {
        raise RegistryError(f"'{name}' is not a package name (org/name)");
    }
    return f"{API_DIR}/{name}/{version}.json";
}

def name_of_index_path(rel: str) -> str | None {
    if not rel.startswith(f"{INDEX_DIR}/") or not rel.endswith(".json") {
        return None;
    }
    name = rel[len(INDEX_DIR) + 1:-len(".json")];
    return name if is_package_name(name) else None;
}

def _github_tree(repo: str, branch: str) -> list[str] {
    import from jaclang.packages.github { find_token }
    headers = {"User-Agent": USER_AGENT, "Accept": "application/vnd.github+json"};
    token = find_token();
    if token {
        headers["Authorization"] = f"Bearer {token}";
    }
    url = f"{GITHUB_API}/repos/{repo}/git/trees/{branch}?recursive=1";
    try {
        with urllib.request.urlopen(
            urllib.request.Request(url, headers=headers), timeout=30
        ) as response {
            data = json.loads(response.read().decode("utf-8"));
        }
    } except (urllib.error.URLError, ValueError) as e {
        raise RegistryError(f"cannot list {repo}: {e}");
    }
    return [
        str(item.get("path", ""))
        for item in data.get("tree", [])
        if item.get("type") == "blob"
    ];
}

def _is_local(url: str) -> bool {
    scheme = urlsplit(url).scheme;
    return scheme in ("", "file");
}

def _local_path(url: str) -> Path {
    parts = urlsplit(url);
    return Path(parts.path if parts.scheme == "file" else url);
}

obj Registry {
    has name: str,
        url: str,
        _settings: dict[str, any] | None = None,
        _entries: dict[str, list[IndexEntry]] = {};

    def base -> str {
        if _is_local(self.url) {
            return str(_local_path(self.url).resolve()) + os.sep;
        }
        return self.url if self.url.endswith("/") else self.url + "/";
    }

    def key -> str {
        return hashlib.sha256(self.base().encode()).hexdigest()[:16];
    }

    def _cache_file(rel: str) -> Path {
        import from jaclang.cache.registry { bucket }
        return bucket("pkg-index").path() / self.key() / rel;
    }

    def _read(rel: str) -> str | None {
        if _is_local(self.url) {
            target = Path(self.base()) / rel;
            return target.read_text(encoding="utf-8") if target.is_file() else None;
        }
        import from jaclang.toolchains.store { allowed_url, offline }
        cache = self._cache_file(rel);
        cached: dict[str, any] = {};
        if cache.is_file() {
            try {
                cached = json.loads(cache.read_text(encoding="utf-8"));
            } except (OSError, ValueError) {
                cached = {};
            }
        }
        if offline() {
            if not cached {
                raise RegistryError(
                    f"{self.name}: {rel} is not cached and JAC_OFFLINE is set"
                );
            }
            return cached.get("body");
        }
        url = urljoin(self.base(), rel);
        if not allowed_url(url) {
            raise RegistryError(
                f"registry '{self.name}' must be served over HTTPS: {url}"
            );
        }
        headers = {"User-Agent": USER_AGENT};
        if cached.get("etag") {
            headers["If-None-Match"] = str(cached["etag"]);
        }
        request = urllib.request.Request(url, headers=headers);
        try {
            with urllib.request.urlopen(request, timeout=30) as response {
                body = response.read().decode("utf-8");
                etag = response.headers.get("ETag", "");
            }
        } except urllib.error.HTTPError as e {
            if e.code == 304 and cached {
                return cached.get("body");
            }
            if e.code == 404 {
                return None;
            }
            raise RegistryError(f"{self.name}: GET {url} failed with HTTP {e.code}");
        } except urllib.error.URLError as e {
            if cached {
                return cached.get("body");
            }
            raise RegistryError(f"{self.name}: cannot reach {url} ({e.reason})");
        }
        cache.parent.mkdir(parents=True, exist_ok=True);
        cache.write_text(
            json.dumps({"etag": etag, "fetched": time.time(), "body": body}),
            encoding="utf-8"
        );
        return body;
    }

    def settings -> dict[str, any] {
        if self._settings is None {
            text = self._read(SETTINGS_NAME);
            if text is None {
                raise RegistryError(
                    f"registry '{self.name}' at {self.url} has no {SETTINGS_NAME}"
                );
            }
            data = json.loads(text);
            if int(data.get("protocol", 0)) != PROTOCOL_VERSION {
                raise RegistryError(
                    f"registry '{self.name}' speaks protocol {data.get('protocol')}; "
                    f"this jac speaks {PROTOCOL_VERSION}"
                );
            }
            self._settings = data;
        }
        return self._settings;
    }

    def entries(name: str) -> list[IndexEntry] {
        if name not in self._entries {
            text = self._read(index_rel_path(name));
            self._entries[name] = parse_index_lines(text) if text else [];
        }
        return self._entries[name];
    }

    def list_names -> list[str] {
        if _is_local(self.url) {
            base_dir = Path(self.base());
            rels = [
                str(p.relative_to(base_dir)).replace(os.sep, "/")
                for p in (base_dir / INDEX_DIR).glob("*/*.json")
            ];
        } else {
            repo = str(self.settings().get("repo", ""));
            if "/" not in repo {
                raise RegistryError(
                    f"registry '{self.name}' does not name its GitHub repository in "
                    f"{SETTINGS_NAME}, so its packages cannot be listed"
                );
            }
            rels = _github_tree(repo, str(self.settings().get("branch", "main")));
        }
        names: set[str] = set();
        for rel in rels {
            name = name_of_index_path(rel);
            if name is not None {
                names.add(name);
            }
        }
        return sorted(names);
    }

    def api(name: str, version: str) -> dict[str, any] | None {
        text = self._read(api_rel_path(name, version));
        if not text {
            return None;
        }
        data = json.loads(text);
        return data if isinstance(data, dict) else None;
    }

    def find(name: str, version: str) -> IndexEntry | None {
        for e in self.entries(name) {
            if e.version == version {
                return e;
            }
        }
        return None;
    }

    def blob_url(sha256: str) -> str {
        blob_base = str(self.settings().get("blob_base", "blobs/"));
        if not blob_base.endswith("/") {
            blob_base += "/";
        }
        if urlsplit(blob_base).scheme in ("http", "https", "file") {
            return blob_base + f"{sha256}.jab";
        }
        if _is_local(self.url) {
            return str(Path(self.base()) / blob_base / f"{sha256}.jab");
        }
        return urljoin(self.base(), blob_base) + f"{sha256}.jab";
    }

    def fetch_blob(item: IndexEntry) -> bytes {
        return fetch_verified(
            self.blob_url(item.sha256), item.sha256, f"{item.name} {item.version}"
        );
    }
}

def fetch_verified(url: str, sha256: str, label: str) -> bytes {
    if urlsplit(url).scheme not in ("http", "https") {
        path = _local_path(url);
        if not path.is_file() {
            raise RegistryError(f"{label}: blob missing at {path}");
        }
        data = path.read_bytes();
        if hashlib.sha256(data).hexdigest() != sha256 {
            raise RegistryError(f"{label}: blob does not match its sha256");
        }
        return data;
    }
    import from jaclang.toolchains.store { Artifact, fetch }
    import from jaclang.cache.registry { bucket }
    dest = bucket("pkgs").ensure() / f".fetch-{sha256}.jab";
    try {
        fetched = fetch(
            Artifact(
                name="jac-package",
                version=sha256[:12],
                platform="jab",
                url=url,
                digest=sha256
            ),
            destination=dest,
            bucket_name="pkgs"
        );
        return fetched.read_bytes();
    } finally {
        dest.unlink(missing_ok=True);
    }
}

def registry_urls(configured: dict[str, str] | None = None) -> dict[str, str] {
    urls: dict[str, str] = {
        DEFAULT_REGISTRY_NAME: os.environ.get(REGISTRY_ENV, "") or DEFAULT_REGISTRY_URL
    };
    for (name, url) in (configured or {}).items() {
        urls[name] = url;
    }
    return urls;
}

glob _open_registries: dict[str, Registry] = {};

def registry_named(name: str, configured: dict[str, str] | None = None) -> Registry {
    urls = registry_urls(configured);
    key = name or DEFAULT_REGISTRY_NAME;
    if key not in urls {
        raise RegistryError(
            f"unknown registry '{key}'; declare it under [registries] in jac.toml"
        );
    }
    url = urls[key];
    cache_key = f"{key}|{url}";
    if cache_key not in _open_registries {
        _open_registries[cache_key] = Registry(name=key, url=url);
    }
    return _open_registries[cache_key];
}

def forget_registries {
    _open_registries.clear();
}
