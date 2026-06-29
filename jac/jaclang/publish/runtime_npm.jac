import from pathlib { Path }

glob RUNTIME_PKG_NAME: str = "@jaseci/runtime",
     CORE_RUNTIME_SYMBOLS: set[str] = set(
         [
             "navigate",
             "jacSpawn",
             "jacSignup",
             "jacLogin",
             "jacLogout",
             "jacIsLoggedIn",
             "jacSsoLogin",
             "jacSetToken",
             "__createJacSchema",
             "__jacSpawn",
             "__jacCallFunction",
             "__normalizeIdentity",
             "__normalizeCredential",
             "__jacClearCache",
             "__jacDesktopBroker",
             "__jacPollBrokerSession",
             "__jacSleep",
             "__getApiBaseUrl",
             "__getLocalStorage",
             "__setLocalStorage",
             "__removeLocalStorage",
             "__getEndpointEffects",
             "__getCacheState",
             "__isFresh",
             "__cacheGet",
             "__cacheSet",
             "__evictOldest",
             "__doWalkerFetch",
             "__doFuncFetch",
             "__cachedEndpointCall",
             "__invalidateEndpoint",
             "__overlaps",
             "__jacReportError",
             "__jacInstallErrorHandlers"
         ]
     );

def runtime_api_names(framework: str = "") -> set[str];

def compile_runtime_js(framework: str = "") -> str;

def runtime_pkg_name(framework: str = "") -> str;

def runtime_export_names(js: str, framework: str = "") -> list[str];

def build_runtime_tarball(
    version: str, pkg_name: str = "", framework: str = ""
) -> bytes;

def build_runtime_to(
    output_dir: Path, version: str, pkg_name: str = "", framework: str = ""
) -> Path;

def runtime_peer_deps(js: str) -> dict[str, str];
