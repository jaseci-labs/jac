# Kubernetes Deployment

Scale your Jac application with jac-scale on Kubernetes.

> **Prerequisites**
>
> - Completed: [Local API Server](local.md)
> - Familiar with: Kubernetes basics (kubectl, deployments)
> - Time: ~30 minutes

---

## Overview

jac-scale provides cloud-native deployment for Jac applications:

```
┌─────────────────────────────────────────────┐
│            Kubernetes Cluster               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Pod 1   │  │  Pod 2   │  │  Pod 3   │  │
│  │ jac-app  │  │ jac-app  │  │ jac-app  │  │
│  └──────────┘  └──────────┘  └──────────┘  │
│         ↑           ↑           ↑          │
│         └───────────┼───────────┘          │
│                     ↓                      │
│              ┌──────────────┐              │
│              │ Load Balancer│              │
│              └──────────────┘              │
└─────────────────────────────────────────────┘
```

---

## Prerequisites

- Docker installed
- Kubernetes cluster (local: minikube, kind; cloud: GKE, EKS, AKS)
- `kubectl` configured
- jac-scale installed: `pip install jac-scale`

---

## Quick Start

### 1. Prepare Your Application

```jac
# app.jac
node Counter {
    has value: int = 0;
}

walker:pub increment {
    can inc with `root entry {
        counters = [-->](`?Counter);
        if len(counters) == 0 {
            root ++> Counter();
            counters = [-->](`?Counter);
        }

        counters[0].value += 1;
        report {"value": counters[0].value};
    }
}

walker:pub get_count {
    can fetch with `root entry {
        counters = [-->](`?Counter);
        if len(counters) > 0 {
            report {"value": counters[0].value};
        } else {
            report {"value": 0};
        }
    }
}

walker:pub health {
    can check with `root entry {
        report {"status": "healthy"};
    }
}
```

### 2. Create Dockerfile

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install Jac
RUN pip install jaclang

# Copy application
COPY app.jac .

# Expose port
EXPOSE 8000

# Run server
CMD ["jac", "start", "app.jac", "--host", "0.0.0.0", "--port", "8000"]
```

### 3. Build and Push Image

```bash
# Build image
docker build -t myapp:latest .

# Tag for registry
docker tag myapp:latest myregistry.com/myapp:v1.0.0

# Push to registry
docker push myregistry.com/myapp:v1.0.0
```

---

## Kubernetes Manifests

### Deployment

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jac-app
  labels:
    app: jac-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: jac-app
  template:
    metadata:
      labels:
        app: jac-app
    spec:
      containers:
      - name: jac-app
        image: myregistry.com/myapp:v1.0.0
        ports:
        - containerPort: 8000
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
```

### Service

```yaml
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: jac-app-service
spec:
  selector:
    app: jac-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: ClusterIP
```

### Ingress

```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jac-app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: api.myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jac-app-service
            port:
              number: 80
```

### Secrets

```yaml
# k8s/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  database-url: "postgresql://user:pass@db-host:5432/mydb"
  api-key: "your-api-key-here"
```

---

## Using jac-scale CLI

jac-scale simplifies Kubernetes deployment:

### Initialize Project

```bash
jac scale init
```

This creates:

```
k8s/
├── deployment.yaml
├── service.yaml
├── ingress.yaml
├── configmap.yaml
└── secrets.yaml
```

### Deploy Application

```bash
# Deploy to current kubectl context
jac scale deploy

# Deploy with custom replicas
jac scale deploy --replicas 5

# Deploy to specific namespace
jac scale deploy --namespace production
```

### Scale Application

```bash
# Scale up
jac scale replicas 10

# Scale down
jac scale replicas 2

# Autoscale based on CPU
jac scale autoscale --min 2 --max 10 --cpu-percent 80
```

### Monitor

```bash
# View pods
jac scale status

# View logs
jac scale logs

# Follow logs
jac scale logs -f
```

---

## Horizontal Pod Autoscaler

```yaml
# k8s/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: jac-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: jac-app
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## Persistent Storage

### For Graph Database

```yaml
# k8s/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jac-data-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard
```

Mount in deployment:

```yaml
spec:
  containers:
  - name: jac-app
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: jac-data-pvc
```

### Using External Database

```toml
# Configure in jac.toml
[database]
url = "${DATABASE_URL}"
pool_size = 10
```

---

## Configuration Management

### ConfigMap

```yaml
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: jac-app-config
data:
  LOG_LEVEL: "info"
  MAX_CONNECTIONS: "100"
  CACHE_TTL: "3600"
```

Use in deployment:

```yaml
envFrom:
- configMapRef:
    name: jac-app-config
```

### Environment-Specific Configs

```bash
# Development
kubectl apply -f k8s/overlays/dev/

# Staging
kubectl apply -f k8s/overlays/staging/

# Production
kubectl apply -f k8s/overlays/prod/
```

---

## Rolling Updates

### Update Image

```bash
# Update deployment with new image
kubectl set image deployment/jac-app jac-app=myregistry.com/myapp:v1.1.0

# Or using jac-scale
jac scale update --image myregistry.com/myapp:v1.1.0
```

### Rollback

```bash
# View rollout history
kubectl rollout history deployment/jac-app

# Rollback to previous version
kubectl rollout undo deployment/jac-app

# Rollback to specific revision
kubectl rollout undo deployment/jac-app --to-revision=2
```

---

## Monitoring

### Prometheus Metrics

```jac
# Add metrics endpoint
walker:pub metrics {
    can export with `root entry {
        import psutil;

        report {
            "requests_total": get_request_count(),
            "memory_usage_bytes": psutil.virtual_memory().used,
            "cpu_percent": psutil.cpu_percent()
        };
    }
}
```

### ServiceMonitor for Prometheus

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: jac-app-monitor
spec:
  selector:
    matchLabels:
      app: jac-app
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

---

## Production Checklist

### Security

- [ ] Use non-root user in container
- [ ] Enable network policies
- [ ] Store secrets in Vault or sealed-secrets
- [ ] Enable RBAC
- [ ] Scan images for vulnerabilities

### Reliability

- [ ] Set resource requests and limits
- [ ] Configure liveness and readiness probes
- [ ] Set up HPA for autoscaling
- [ ] Configure PodDisruptionBudget
- [ ] Enable persistent storage

### Observability

- [ ] Configure logging to stdout
- [ ] Set up Prometheus metrics
- [ ] Configure distributed tracing
- [ ] Set up alerting

### Deployment

- [ ] Use immutable tags (not :latest)
- [ ] Configure rolling update strategy
- [ ] Test rollback procedure
- [ ] Set up CI/CD pipeline

---

## Example: Complete Production Setup

```yaml
# k8s/production/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jac-app
  namespace: production
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: jac-app
  template:
    metadata:
      labels:
        app: jac-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: jac-app
        image: myregistry.com/myapp:v1.0.0
        imagePullPolicy: Always
        ports:
        - containerPort: 8000
          name: http
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 15
          periodSeconds: 20
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 10
        envFrom:
        - configMapRef:
            name: jac-app-config
        - secretRef:
            name: jac-app-secrets
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: jac-data-pvc
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: jac-app
              topologyKey: kubernetes.io/hostname
```

---

## CLI Reference

| Command | Description |
|---------|-------------|
| `jac scale init` | Initialize k8s manifests |
| `jac scale deploy` | Deploy application |
| `jac scale status` | Show deployment status |
| `jac scale logs` | View application logs |
| `jac scale replicas N` | Scale to N replicas |
| `jac scale autoscale` | Configure HPA |
| `jac scale update` | Update deployment |
| `jac scale rollback` | Rollback deployment |

---

## Next Steps

- [Local API Server](local.md) - Development setup
- [Authentication](../fullstack/auth.md) - Secure your API
