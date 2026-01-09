# Jac-Scale Developer Guide

## Architecture Overview

Jac-Scale has been refactored to be extensible while maintaining backward compatibility. The architecture is based on simple abstractions that allow new deployment targets to be added easily.

## Core Concepts

### Engine Abstractions

The `engine/` directory contains the core abstractions:

- **DeploymentTarget** (`engine/deployment_target.jac`) - Base class for all deployment targets
- **DatabaseProvider** (`engine/database_provider.jac`) - Base class for database implementations
- **ImageRegistry** (`engine/image_registry.jac`) - Base class for image registries
- **Logger** (`engine/logger.jac`) - Base class for loggers

### Current Implementation

- **KubernetesTarget** (`targets/kubernetes/kubernetes_target.jac`) - Kubernetes deployment implementation
- **StandardLogger** (`loggers/standard_logger.jac`) - Python logging implementation

## Adding a New Deployment Target

To add a new deployment target (e.g., EKS, GKE), follow these steps:

### Step 1: Create Target Class

Create a new file `targets/<target_name>/<target_name>_target.jac`:

```jac
import from jac_scale.engine.deployment_target { DeploymentTarget }
import from jac_scale.targets.kubernetes.kubernetes_target { KubernetesTarget }
import from jac_scale.engine.models.app_config { AppConfig }
import from jac_scale.engine.models.deployment_result { DeploymentResult }

class EKSTarget(KubernetesTarget) {
    # Inherit most behavior from KubernetesTarget
    # Only override what's different for EKS

    def _build_service(self: EKSTarget, app_config: AppConfig) -> dict {
        service = super()._build_service(app_config);
        # Add EKS-specific annotations
        service['metadata']['annotations'] = {
            'service.beta.kubernetes.io/aws-load-balancer-type': 'nlb'
        };
        return service;
    }

    def get_service_url(self: EKSTarget, app_name: str) -> str {
        # EKS-specific: Get NLB URL
        return self._get_nlb_url(app_name);
    }
}
```

### Step 2: Create Config Class (Optional)

If you need target-specific configuration:

```jac
import from jac_scale.engine.config.k8s_config { KubernetesConfig }

class EKSConfig(KubernetesConfig) {
    has cluster_name: str;
    has region: str = 'us-east-1';
    has iam_role_arn: (str | None) = None;
}
```

### Step 3: Register in Factory

Update `factories/deployment_factory.jac`:

```jac
static def create(...) -> DeploymentTarget {
    if target_type == 'kubernetes' {
        return KubernetesTarget(...);
    } elif target_type == 'eks' {
        import from jac_scale.targets.eks.eks_target { EKSTarget }
        return EKSTarget(...);
    }
    # ...
}
```

### Step 4: Use It

```jac
config = EKSConfig(...);
target = DeploymentTargetFactory.create('eks', config);
result = target.deploy(app_config);
```

## Adding a New Database Provider

To add support for a new database (e.g., AWS DocumentDB):

### Step 1: Create Provider Class

```jac
import from jac_scale.engine.database_provider { DatabaseProvider }

class DocumentDBProvider(DatabaseProvider) {
    def deploy(self: DocumentDBProvider, config: dict) -> dict {
        # Deploy DocumentDB via AWS API
        # Return deployment info
    }

    def get_connection_string(self: DocumentDBProvider) -> str {
        # Return MongoDB connection string
    }

    def is_available(self: DocumentDBProvider) -> bool {
        # Check if DocumentDB is available
    }

    def cleanup(self: DocumentDBProvider) -> None {
        # Cleanup DocumentDB resources
    }
}
```

### Step 2: Register in Factory

Create or update `factories/database_factory.jac`:

```jac
class DatabaseProviderFactory {
    static def create(provider_type: str, target: DeploymentTarget) -> DatabaseProvider {
        if provider_type == 'documentdb' {
            return DocumentDBProvider(target=target);
        }
        # ...
    }
}
```

## Adding a New Logger

To add a new logger (e.g., CloudWatch):

### Step 1: Create Logger Class

```jac
import from jac_scale.engine.logger { Logger }

class CloudWatchLogger(Logger) {
    has log_group: str;
    has client: CloudWatchLogsClient;

    def info(self: CloudWatchLogger, message: str, context: dict = {}) -> None {
        # Send to CloudWatch
    }

    # Implement other methods...
}
```

### Step 2: Register in Factory

Update `factories/logger_factory.jac`:

```jac
class LoggerFactory {
    static def create(logger_type: str, config: dict) -> Logger {
        if logger_type == 'cloudwatch' {
            return CloudWatchLogger(...);
        }
        # ...
    }
}
```

## Design Principles

1. **Keep It Simple** - Don't over-engineer. Add abstractions only when needed.

2. **Backward Compatibility** - Always maintain existing functionality. New code should not break old code.

3. **Extensibility Over Features** - Focus on making the architecture extensible rather than implementing all features upfront.

4. **Inheritance Over Duplication** - When adding new targets, inherit from existing implementations and only override what's different.

5. **Clear Abstractions** - Each abstraction should have a single, clear purpose.

## File Structure

```
jac_scale/
├── engine/                    # Core abstractions
│   ├── deployment_target.jac  # Base class for targets
│   ├── database_provider.jac  # Base class for databases
│   ├── image_registry.jac     # Base class for registries
│   ├── logger.jac             # Base class for loggers
│   ├── config/                # Configuration models
│   └── models/                 # Data models
├── targets/                    # Deployment target implementations
│   └── kubernetes/             # Kubernetes target
├── factories/                  # Factory classes
├── loggers/                    # Logger implementations
├── providers/                  # Provider implementations
│   ├── database/              # Database providers
│   └── registry/              # Image registry providers
└── kubernetes/                 # Legacy code (maintained for compatibility)
```

## Testing

When adding new components:

1. **Unit Tests** - Test the component in isolation
2. **Integration Tests** - Test with real deployments
3. **Backward Compatibility** - Ensure existing tests still pass

## Common Patterns

### Wrapper Pattern

When refactoring existing code, use the wrapper pattern:

```jac
class NewImplementation(AbstractBase) {
    def method(self: NewImplementation) -> Result {
        # Call existing function
        existing_function(...);
        # Wrap result
        return Result(...);
    }
}
```

### Factory Pattern

Use factories to create instances:

```jac
target = DeploymentTargetFactory.create('kubernetes', config);
```

### Configuration Pattern

Extend base config for target-specific options:

```jac
class TargetConfig(BaseConfig) {
    has target_specific_option: str;
}
```

## Questions?

- Check existing implementations in `targets/kubernetes/` for examples
- Review the audit document (`AUDIT.md`) for architecture decisions
- See the proposal plan (`PROPOSAL_PLAN.md`) for the migration strategy
