glob RUNTIME: str = "runtime",
     DEPLOY: str = "deploy";

glob CAPABILITY_SPECS: dict[str, dict[str, any]] = {
         "serve": {"context": "runtime", "deps": {"python-dotenv": ">=1.2.1,<2.0.0"}},
         "env": {"context": "runtime", "deps": {"python-dotenv": ">=1.2.1,<2.0.0"}},
         "upload": {
             "context": "runtime",
             "deps": {"python-multipart": ">=0.0.21,<1.0.0"}
         },
         "monitoring": {
             "context": "runtime",
             "deps": {
                 "prometheus-client": ">=0.21.0,<1.0.0",
                 "requests": ">=2.32.0,<3.0.0"
             }
         },
         "tracing": {
             "context": "runtime",
             "deps": {
                 "opentelemetry-sdk": ">=1.27.0,<2.0.0",
                 "opentelemetry-exporter-otlp-proto-http": ">=1.27.0,<2.0.0"
             }
         },
         "scheduler": {
             "context": "runtime",
             "deps": {"apscheduler": ">=3.11.2,<4.0.0"}
         },
         "storage.gcs": {
             "context": "runtime",
             "deps": {"google-cloud-storage": ">=2.19.0,<3.0.0"}
         },
         "storage.firebase": {
             "context": "runtime",
             "deps": {
                 "google-cloud-firestore": ">=2.21.0,<3.0.0",
                 "google-cloud-storage": ">=2.19.0,<3.0.0",
                 "firebase-admin": ">=6.0.0,<8.0.0"
             }
         },
         "storage.s3": {"context": "runtime", "deps": {"boto3": ">=1.40.0,<2.0.0"}},
         "deploy.k8s": {
             "context": "deploy",
             "deps": {
                 "kubernetes": ">=34.1.0,<35.0.0",
                 "docker": ">=7.1.0,<8.0.0",
                 "requests": ">=2.32.0,<3.0.0"
             }
         },
         "llm": {
             "context": "runtime",
             "deps": {
                 "litellm": ">=1.102.1,<1.103.0",
                 "pillow": ">=12.0.0,<13.0.0",
                 "httpx": ">=0.27.0",
                 "loguru": ">=0.7.2,<0.8.0"
             }
         },
         "llm.local": {
             "context": "runtime",
             "requires": ["llm"],
             "deps": {"llama-cpp-python": ">=0.2.90", "huggingface_hub": ">=0.24.0"}
         },
         "llm.mcp": {
             "context": "runtime",
             "requires": ["llm"],
             "deps": {"mcp": ">=1.0.0"}
         },
         "llm.video": {
             "context": "runtime",
             "requires": ["llm"],
             "deps": {"opencv-python-headless": ">=4.10.0,<5.0.0"}
         }
     };

glob INTENT_RULES: list[dict[str, any]] = [
         {
             "section": "storage",
             "keys": ["backend", "type", "storage_type"],
             "values": {
                 "gcs": "storage.gcs",
                 "firebase": "storage.firebase",
                 "firestore": "storage.firebase",
                 "s3": "storage.s3"
             }
         },
         {
             "section": "deploy",
             "keys": ["target"],
             "values": {"kubernetes": "deploy.k8s", "k8s": "deploy.k8s"}
         },
         {"section": "monitoring", "keys": ["enabled"], "flag": "monitoring"},
         {"section": "tracing", "keys": ["enabled"], "flag": "tracing"},
         {"section": "scheduler", "keys": ["enabled"], "flag": "scheduler"}
     ];

obj Capability {
    has name: str,
        deps: dict[str, str] = {},
        context: str = "runtime",
        requires: list[str] = [];
}

obj CapabilityClosure {
    has context: str,
        capabilities: list[str] = [],
        deps: dict[str, str] = {};

    def is_empty -> bool;
    def package_names -> list[str];
}

glob _registry: dict[str, Capability] | None = None;

def get_capability_registry -> dict[str, Capability];

def get_capability(name: str) -> Capability | None;

def all_capability_names -> list[str];

def _normalize_package(name: str) -> str;

def derive_capabilities(
    intent: dict[str, any] | None, commands: list[str] | None = None
) -> set[str];

def scale_intent_from_config(config: JacConfig) -> dict[str, any];

def command_capabilities(action: str, scale: bool = False) -> list[str];

def _expand_requires(cap_names: set[str]) -> set[str];

def resolve_closure(cap_names: set[str], context: str) -> CapabilityClosure;

def resolve_closures(cap_names: set[str]) -> dict[str, CapabilityClosure];

def byllm_intent_capabilities(config: JacConfig) -> set[str];

def resolve_config_closures(
    config: JacConfig, action: str = "serve", scale: bool = False
) -> dict[str, CapabilityClosure];

def capability_for_package(package: str) -> str | None;

def missing_capability_error(capability: str) -> str;

def package_missing_error(package: str) -> str;

def missing_capability_dists(capability: str) -> list[str];

def ensure_global_capability(capability: str) -> bool;

def require_optional(package: str, capability: str);

def is_optional_available(package: str) -> bool;
