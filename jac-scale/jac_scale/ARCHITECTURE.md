# Jac-Scale Architecture

## Overview

Jac-Scale is a multi-target deployment system for Jaseci applications. It provides an extensible, factory-based architecture that supports multiple deployment targets (Kubernetes, AWS, GCP, etc.), database providers, image registries, and utilities (loggers, monitoring).

## Design Principles

1. **Separation of Concerns**: Deployment targets, databases, and utilities are separate abstractions
2. **Extensibility**: Easy to add new targets without modifying existing code
3. **Factory Pattern**: Centralized creation of instances for all components
4. **Configuration Isolation**: Target-specific configs are separate from general config
5. **Inheritance Over Duplication**: New implementations inherit from base classes
6. **Type Safety**: Strong typing with Jac's type system

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      User Interface                          │
│                    (plugin.jac, CLI)                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                      Factories                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Deployment   │  │ Database     │  │ Registry     │     │
│  │ Factory      │  │ Factory      │  │ Factory      │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                 │                  │              │
└─────────┼─────────────────┼──────────────────┼─────────────┘
          │                 │                  │
          ▼                 ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    Abstractions                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Deployment   │  │ Database     │  │ Image        │     │
│  │ Target       │  │ Provider     │  │ Registry     │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                 │                  │              │
└─────────┼─────────────────┼──────────────────┼─────────────┘
          │                 │                  │
          ▼                 ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                  Implementations                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Kubernetes   │  │ K8s Mongo    │  │ DockerHub    │     │
│  │ Target       │  │ Provider     │  │ Registry     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │ AWS Target   │  │ K8s Redis    │                        │
│  │ (Future)     │  │ Provider     │                        │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Abstractions Layer

The abstractions layer defines the contracts that all implementations must follow.

#### `abstractions/deployment_target.jac`

Base class for all deployment targets. Defines the interface for:

- `deploy(app_config: AppConfig) -> DeploymentResult`
- `destroy(app_name: str) -> None`
- `get_status(app_name: str) -> ResourceStatusInfo`
- `scale(app_name: str, replicas: int) -> None`
- `get_service_url(app_name: str) -> str | None`

#### `abstractions/database_provider.jac`

Base class for database providers. Defines:

- `deploy(config: dict) -> dict`
- `get_connection_string() -> str`
- `is_available() -> bool`
- `cleanup() -> None`

#### `abstractions/image_registry.jac`

Base class for image registries. Defines:

- `build_image(code_folder: str, image_name: str | None) -> str`
- `push_image(image_name: str) -> None`
- `get_image_url(image_name: str) -> str`

#### `abstractions/logger.jac`

Base class for loggers. Defines:

- `info(message: str, context: dict) -> None`
- `error(message: str, context: dict) -> None`
- `warn(message: str, context: dict) -> None`
- `debug(message: str, context: dict) -> None`

### 2. Configuration Models

#### `abstractions/config/base_config.jac`

Base configuration class with common fields:

- `app_name: str`
- `namespace: str`

#### `abstractions/config/app_config.jac`

Application-specific configuration:

- `code_folder: str`
- `file_name: str`
- `build: bool`
- `app_name: str | None`
- `testing: bool`

#### `targets/kubernetes/kubernetes_config.jac`

Kubernetes-specific configuration extending `BaseConfig`:

- `docker_image_name: str`
- `container_port: int`
- `node_port: int`
- `mongodb_enabled: bool`
- `redis_enabled: bool`
- Resource limits, health check settings, etc.

### 3. Data Models

#### `abstractions/models/deployment_result.jac`

Result of a deployment operation:

- `success: bool`
- `service_url: str | None`
- `message: str | None`
- `details: dict`

#### `abstractions/models/resource_status.jac`

Status information for deployed resources:

- `status: ResourceStatus` (RUNNING, PENDING, FAILED, etc.)
- `replicas: int`
- `ready_replicas: int`
- `message: str | None`

### 4. Factories

Factories provide a centralized way to create instances of abstractions.

#### `factories/deployment_factory.jac`

Creates deployment target instances:

```jac
DeploymentTargetFactory.create(
    target_type: str,  // 'kubernetes', 'aws', 'gcp'
    config: dict,
    logger: Logger | None = None
) -> DeploymentTarget
```

#### `factories/database_factory.jac`

Creates database provider instances:

```jac
DatabaseProviderFactory.create(
    provider_type: str,  // 'kubernetes_mongo', 'kubernetes_redis'
    target: DeploymentTarget | None = None,
    config: dict | None = None
) -> DatabaseProvider
```

#### `factories/registry_factory.jac`

Creates image registry instances:

```jac
ImageRegistryFactory.create(
    registry_type: str,  // 'dockerhub', 'ecr', 'gcr'
    config: dict | None = None
) -> ImageRegistry
```

#### `factories/utility_factory.jac`

Creates utility instances:

```jac
UtilityFactory.create_logger(
    logger_type: str = 'standard',  // 'standard', 'cloudwatch', 'elasticsearch'
    config: dict | None = None
) -> Logger
```

## Current Implementations

### Deployment Targets

#### Kubernetes (`targets/kubernetes/kubernetes_target.jac`)

- Full Kubernetes deployment support
- Manages Deployments, Services, StatefulSets, PVCs
- Health checks (readiness and liveness probes)
- Resource limits and requests
- MongoDB and Redis integration
- Code synchronization via PVCs

### Database Providers

#### Kubernetes MongoDB (`providers/database/kubernetes_mongo.jac`)

- Deploys MongoDB StatefulSet in Kubernetes
- Returns connection string
- Integrates with KubernetesTarget

#### Kubernetes Redis (`providers/database/kubernetes_redis.jac`)

- Deploys Redis Deployment in Kubernetes
- Returns connection string
- Integrates with KubernetesTarget

### Image Registries

#### DockerHub (`providers/registry/dockerhub.jac`)

- Builds Docker images
- Pushes to DockerHub
- Supports authentication

### Utilities

#### Standard Logger (`utilities/loggers/standard_logger.jac`)

- Python logging integration
- Configurable log levels
- Context support

## Usage Examples

### Basic Deployment

```jac
import from jac_scale.factories.deployment_factory { DeploymentTargetFactory }
import from jac_scale.factories.utility_factory { UtilityFactory }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.config_loader { get_scale_config }

// Get configuration
scale_config = get_scale_config();
target_config = scale_config.get_kubernetes_config();

// Create logger
logger = UtilityFactory.create_logger('standard');

// Create deployment target
deployment_target = DeploymentTargetFactory.create(
    'kubernetes',
    target_config,
    logger
);

// Create app config
app_config = AppConfig(
    code_folder='/path/to/code',
    file_name='app.jac',
    build=True
);

// Deploy
result = deployment_target.deploy(app_config);
```

### With Image Registry

```jac
import from jac_scale.factories.registry_factory { ImageRegistryFactory }

// Create image registry
image_registry = ImageRegistryFactory.create('dockerhub', target_config);
deployment_target.image_registry = image_registry;

// Deploy (will build and push image if build=True)
result = deployment_target.deploy(app_config);
```

### With Database Providers

```jac
import from jac_scale.factories.database_factory { DatabaseProviderFactory }

// Create database providers
mongo_provider = DatabaseProviderFactory.create(
    'kubernetes_mongo',
    target=deployment_target,
    config={'app_name': 'myapp'}
);

redis_provider = DatabaseProviderFactory.create(
    'kubernetes_redis',
    target=deployment_target,
    config={'app_name': 'myapp'}
);

// Add to deployment target
deployment_target.database_providers = [mongo_provider, redis_provider];
```

## Extending the System

### Adding a New Deployment Target

1. **Create the target class**:

   ```jac
   // targets/aws/aws_target.jac
   import from jac_scale.abstractions.deployment_target { DeploymentTarget }

   class AWSTarget(DeploymentTarget) {
       // Implement all abstract methods
       def deploy(self: AWSTarget, app_config: AppConfig) -> DeploymentResult {
           // AWS-specific deployment logic
       }
       // ... other methods
   }
   ```

2. **Create the config class**:

   ```jac
   // targets/aws/aws_config.jac
   import from jac_scale.abstractions.config.base_config { BaseConfig }

   class AWSConfig(BaseConfig) {
       has region: str;
       has ecs_cluster: str;
       // ... other AWS-specific fields
   }
   ```

3. **Update the factory**:

   ```jac
   // factories/deployment_factory.jac
   if target_type == 'aws' {
       import from jac_scale.targets.aws.aws_target { AWSTarget }
       import from jac_scale.targets.aws.aws_config { AWSConfig }
       aws_config = AWSConfig.from_dict(AWSConfig, config);
       return AWSTarget(config=aws_config, logger=logger);
   }
   ```

### Adding a New Database Provider

1. **Create the provider class**:

   ```jac
   // providers/database/aws_documentdb.jac
   import from jac_scale.abstractions.database_provider { DatabaseProvider }

   class AWSDocumentDBProvider(DatabaseProvider) {
       def deploy(self: AWSDocumentDBProvider, config: dict) -> dict {
           // AWS DocumentDB deployment logic
       }
       // ... other methods
   }
   ```

2. **Update the factory**:

   ```jac
   // factories/database_factory.jac
   if provider_type == 'aws_documentdb' {
       import from jac_scale.providers.database.aws_documentdb { AWSDocumentDBProvider }
       return AWSDocumentDBProvider(target=target, config=config or {});
   }
   ```

### Adding a New Logger

1. **Create the logger class**:

   ```jac
   // utilities/loggers/cloudwatch_logger.jac
   import from jac_scale.abstractions.logger { Logger }

   class CloudWatchLogger(Logger) {
       def info(self: CloudWatchLogger, message: str, context: dict) -> None {
           // CloudWatch logging logic
       }
       // ... other methods
   }
   ```

2. **Update the factory**:

   ```jac
   // factories/utility_factory.jac
   if logger_type == 'cloudwatch' {
       import from jac_scale.utilities.loggers.cloudwatch_logger { CloudWatchLogger }
       return CloudWatchLogger(config=config or {});
   }
   ```

## Data Flow

### Deployment Flow

1. **User invokes deployment** via `plugin.jac` or CLI
2. **Configuration loaded** from `config_loader.jac`
3. **Factories create instances**:
   - `DeploymentTargetFactory` creates target
   - `ImageRegistryFactory` creates registry (if needed)
   - `DatabaseProviderFactory` creates providers (if needed)
   - `UtilityFactory` creates logger
4. **Target deploys application**:
   - Builds/pushes image (if `build=True`)
   - Deploys databases (if enabled)
   - Creates deployment resources
   - Waits for readiness
5. **Returns result** with service URL and status

### Destroy Flow

1. **User invokes destroy** via `plugin.jac` or CLI
2. **Factory creates target** instance
3. **Target destroys resources**:
   - Deletes main deployment
   - Deletes services
   - Deletes databases (if enabled)
   - Cleans up PVCs and other resources

## File Structure

```
jac_scale/
├── abstractions/              # Core abstractions
│   ├── deployment_target.jac
│   ├── database_provider.jac
│   ├── image_registry.jac
│   ├── logger.jac
│   ├── config/
│   │   ├── base_config.jac
│   │   └── app_config.jac
│   └── models/
│       ├── deployment_result.jac
│       └── resource_status.jac
├── targets/                   # Deployment target implementations
│   └── kubernetes/
│       ├── kubernetes_target.jac
│       └── kubernetes_config.jac
├── providers/                 # Provider implementations
│   ├── database/
│   │   ├── kubernetes_mongo.jac
│   │   └── kubernetes_redis.jac
│   └── registry/
│       └── dockerhub.jac
├── utilities/                 # Utility implementations
│   └── loggers/
│       └── standard_logger.jac
├── factories/                 # Factory classes
│   ├── deployment_factory.jac
│   ├── database_factory.jac
│   ├── registry_factory.jac
│   └── utility_factory.jac
├── kubernetes/               # Legacy Kubernetes utilities
│   └── ...
├── plugin.jac                # Main entry point
└── config_loader.jac         # Configuration management
```

## Key Design Patterns

### Factory Pattern

Centralized creation of instances based on type strings. Allows easy extension without modifying existing code.

### Strategy Pattern

Different deployment targets, database providers, and registries can be swapped at runtime.

### Template Method Pattern

Base classes define the interface, implementations provide specific behavior.

### Dependency Injection

Components receive dependencies (logger, config) through constructors.

### Planned Targets

- AWS ECS/EKS
- GCP Cloud Run/GKE
- Azure Container Instances/AKS

### Planned Providers

- AWS DocumentDB
- AWS ElastiCache
- GCP Cloud SQL
- Managed Redis services

### Planned Utilities

- CloudWatch Logger
- Elasticsearch Logger
- Prometheus Monitoring
- Datadog Monitoring
