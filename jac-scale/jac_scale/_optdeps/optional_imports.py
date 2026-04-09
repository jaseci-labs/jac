"""Re-exports optional dependencies with ImportError guards.

.jac files cannot use try/except at module level, so they import
optional symbols from this module instead of directly from the
third-party packages. When a package is not installed, its symbols
are set to None — runtime guards (require_optional) catch actual
usage before a None would cause trouble.
"""

# ──────────────────────────────────────────────
# [data] group — pymongo
# ──────────────────────────────────────────────
try:
    from pymongo import MongoClient, UpdateOne
    from pymongo.results import (
        InsertOneResult as PyMongoInsertOneResult,
        InsertManyResult as PyMongoInsertManyResult,
        UpdateResult as PyMongoUpdateResult,
        DeleteResult as PyMongoDeleteResult,
    )
    from pymongo.cursor import Cursor
    from pymongo.collection import Collection
    from pymongo.errors import ConnectionFailure

    HAS_PYMONGO = True
except ImportError:
    MongoClient = None
    UpdateOne = None
    PyMongoInsertOneResult = None
    PyMongoInsertManyResult = None
    PyMongoUpdateResult = None
    PyMongoDeleteResult = None
    Cursor = None
    Collection = None
    ConnectionFailure = Exception

    HAS_PYMONGO = False

try:
    from bson import ObjectId

    HAS_BSON = True
except ImportError:
    ObjectId = None
    HAS_BSON = False

# ──────────────────────────────────────────────
# [data] group — redis
# ──────────────────────────────────────────────
try:
    import redis as redis_module
    from redis import Redis

    HAS_REDIS = True
except ImportError:
    redis_module = None
    Redis = None

    HAS_REDIS = False

# ──────────────────────────────────────────────
# [monitoring] group — prometheus-client
# ──────────────────────────────────────────────
try:
    from prometheus_client import (
        Counter,
        Histogram,
        Gauge,
        generate_latest,
        CONTENT_TYPE_LATEST,
        REGISTRY,
        CollectorRegistry,
    )

    HAS_PROMETHEUS = True
except ImportError:
    Counter = None
    Histogram = None
    Gauge = None
    generate_latest = None
    CONTENT_TYPE_LATEST = None
    REGISTRY = None
    CollectorRegistry = None

    HAS_PROMETHEUS = False

# ──────────────────────────────────────────────
# [scheduler] group — apscheduler
# ──────────────────────────────────────────────
try:
    from apscheduler.schedulers.background import BackgroundScheduler
    from apscheduler.executors.pool import ThreadPoolExecutor as APThreadPoolExecutor

    HAS_APSCHEDULER = True
except ImportError:
    BackgroundScheduler = None
    APThreadPoolExecutor = None

    HAS_APSCHEDULER = False

# ──────────────────────────────────────────────
# [deploy] group — kubernetes
# ──────────────────────────────────────────────
try:
    from kubernetes import client as k8s_client, config as k8s_config
    from kubernetes.client.exceptions import ApiException as K8sApiException
    from kubernetes.config.config_exception import (
        ConfigException as K8sConfigException,
    )
    from kubernetes.client import (
        AutoscalingV2Api,
        V2CrossVersionObjectReference,
        V2HorizontalPodAutoscaler,
        V2HorizontalPodAutoscalerSpec,
        V2MetricSpec,
        V2ResourceMetricSource,
    )

    HAS_KUBERNETES = True
except ImportError:
    k8s_client = None
    k8s_config = None
    K8sApiException = Exception
    K8sConfigException = Exception
    AutoscalingV2Api = None
    V2CrossVersionObjectReference = None
    V2HorizontalPodAutoscaler = None
    V2HorizontalPodAutoscalerSpec = None
    V2MetricSpec = None
    V2ResourceMetricSource = None

    HAS_KUBERNETES = False

# ──────────────────────────────────────────────
# [deploy] group — docker
# ──────────────────────────────────────────────
try:
    import docker as docker_module
    from docker.errors import APIError as DockerAPIError, BuildError as DockerBuildError

    HAS_DOCKER = True
except ImportError:
    docker_module = None
    DockerAPIError = Exception
    DockerBuildError = Exception

    HAS_DOCKER = False
