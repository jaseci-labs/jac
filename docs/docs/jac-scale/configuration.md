# Jac scale configuration

`jac start --scale` not only simplifies application deployment but also supports advanced configurations.

### JWT environment variables

| Parameter | Description | Default |
|-----------|-------------|---------|
| `JWT_EXP_DELTA_DAYS` | Number of days until JWT token expires | `7` |
| `JWT_SECRET` | Secret key used for JWT token signing and verification | `'supersecretkey'` |
| `JWT_ALGORITHM` | Algorithm used for JWT token encoding/decoding | `'HS256'` |

For production environment make sure you set a strong `JWT_SECRET` and rotate it frequently

### SSO environment variables

| Parameter | Description | Default |
|-----------|-------------|---------|
| `SSO_HOST` | SSO host URL | `'http://localhost:8000/sso'` |
| `SSO_GOOGLE_CLIENT_ID` | Google OAuth client ID | - |
| `SSO_GOOGLE_CLIENT_SECRET` | Google OAuth client secret | - |

### Kubernetes environment variables

| Parameter | Description | Default |
|-----------|-------------|---------|
| `APP_NAME` | Name of your JAC application | `jaseci` |
| `DOCKER_USERNAME` | DockerHub username for pushing the image | - |
| `DOCKER_PASSWORD` | DockerHub password or access token | - |
| `K8s_NAMESPACE` | Kubernetes namespace to deploy the application | `default` |
| `K8s_NODE_PORT` | Port in which your local kubernetes application will run on| `30001` |
| `K8s_CPU_REQUEST` | CPU request for the application container | - |
| `K8s_CPU_LIMIT` | CPU limit for the application container | - |
| `K8s_MEMORY_REQUEST` | Memory request for the application container | - |
| `K8s_MEMORY_LIMIT` | Memory limit for the application container | - |
| `K8s_READINESS_INITIAL_DELAY` | Seconds before readiness probe first checks the pod | `120` |
| `K8s_READINESS_PERIOD` | Seconds between readiness probe checks | `30` |
| `K8s_LIVENESS_INITIAL_DELAY` | Seconds before liveness probe first checks the pod | `120` |
| `K8s_LIVENESS_PERIOD` | Seconds between liveness probe checks | `30` |
| `K8s_LIVENESS_FAILURE_THRESHOLD` | Consecutive liveness probe failures before restart | `10` |
| `K8s_MONGODB` | Whether k8s MongoDB is needed (`True`/`False`) | `True` |
| `K8s_REDIS` | Whether k8s Redis is needed (`True`/`False`) | `True` |

### Database environment variables

| Parameter | Description | Default |
|-----------|-------------|---------|
| `MONGODB_URI` | URL of MongoDB database | - |
| `REDIS_URL` | URL of Redis database | - |

if you are manually setting `MONGODB_URI`,`REDIS_URL` as environment variable make sure you keep `K8s_MONGODB` and `K8s_REDIS` False respectively
