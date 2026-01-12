# Chapter 18: Deployment Strategies

!!! note "About Jac Cloud vs Jac Scale"
    This chapter includes references to **Jac Cloud**, which has been superseded by **jac-scale**. For current deployment best practices, see the [Production & Scaling Guide](../production/index.md) which covers the modern `jac start` and `jac start --scale` commands.

In this chapter, we'll explore how to deploy Jac applications to production environments. We'll take our weather API from development to production using various deployment strategies including Docker, Kubernetes, and jac-scale.

!!! info "What You'll Learn"
    - Local vs cloud deployment comparison
    - Docker containerization for Jac applications
    - Kubernetes orchestration and scaling
    - jac-scale deployment with real examples
    - Production monitoring and maintenance

---

## Local to Cloud Deployment

One of Jac's most powerful features is its scale-agnostic nature - the same code that runs locally can be deployed to production without changes.

!!! success "Deployment Benefits"
    - **Zero Code Changes**: Same application runs locally and in production
    - **Automatic Scaling**: Built-in support for horizontal scaling
    - **Container Ready**: Applications naturally containerize
    - **Kubernetes Native**: Seamless Kubernetes integration
    - **Production Features**: Built-in monitoring, logging, and health checks

### Development to Production Pipeline

Let's start with our weather API and show how it progresses from development to production:

!!! example "Weather API Deployment Journey"
    === "Development (Local)"
        ```jac
        # weather_api.jac - Same code at every stage
        import from os { getenv }

        glob config = {
            "api_key": getenv("WEATHER_API_KEY", "dev-key"),
            "cache_timeout": int(getenv("CACHE_TIMEOUT", "300")),
            "debug": getenv("DEBUG", "true").lower() == "true"
        };

        node WeatherData {
            has city: str;
            has temperature: float;
            has description: str;
            has last_updated: str;
        }

        walker get_weather {
            has city: str;

            can fetch_weather with `root entry {
                # Check cache first
                cached = [-->(`?WeatherData)](?city == self.city);

                if cached {
                    weather = cached[0];
                    report {
                        "city": weather.city,
                        "temperature": weather.temperature,
                        "description": weather.description,
                        "cached": True
                    };
                } else {
                    # Simulate API call
                    new_weather = WeatherData(
                        city=self.city,
                        temperature=22.5,
                        description="Sunny",
                        last_updated="2024-01-15T10:00:00Z"
                    );
                    here ++> new_weather;

                    report {
                        "city": self.city,
                        "temperature": 22.5,
                        "description": "Sunny",
                        "cached": False
                    };
                }
            }
        }

        walker health_check {
            can check_health with `root entry {
                weather_count = len([-->(`?WeatherData)]);
                report {
                    "status": "healthy",
                    "cached_cities": weather_count,
                    "debug_mode": config["debug"]
                };
            }
        }
        ```

    === "Local Development"
        ```bash
        # Development workflow
        export DEBUG=true
        export WEATHER_API_KEY=dev-key

        # Run locally for development
        jac run weather_api.jac

        # Test as service locally
        jac start weather_api.jac --port 8000

        # Test the endpoints
        curl -X POST http://localhost:8000/walker/get_weather \
          -H "Content-Type: application/json" \
          -d '{"city": "New York"}'
        ```

---

## Docker Containerization

Docker packaging makes your Jac applications portable and consistent across environments.

### Basic Dockerfile for Jac Applications

!!! example "Jac Application Dockerfile"
    === "Dockerfile"
        ```dockerfile
        # Dockerfile
        FROM python:3.11-slim

        # Set working directory
        WORKDIR /app

        # Install system dependencies
        RUN apt-get update && apt-get install -y \
            curl \
            && rm -rf /var/lib/apt/lists/*

        # Install Jac
        RUN pip install jaclang

        # Copy application files
        COPY weather_api.jac .
        COPY requirements.txt .

        # Install Python dependencies if any
        RUN pip install -r requirements.txt

        # Expose port
        EXPOSE 8000

        # Set environment variables
        ENV JAC_FILE=weather_api.jac
        ENV PORT=8000
        ENV DEBUG=false

        # Health check
        HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
            CMD curl -f http://localhost:$PORT/walker/health_check -X POST -H "Content-Type: application/json" -d '{}' || exit 1

        # Run the application
        CMD jac start $JAC_FILE --port $PORT
        ```

    === "requirements.txt"
        ```txt
        # requirements.txt
        jaclang
        requests
        python-dotenv
        ```

    === "docker-compose.yml"
        ```yaml
        # docker-compose.yml
        version: '3.8'

        services:
          weather-api:
            build: .
            ports:
              - "8000:8000"
            environment:
              - DEBUG=false
              - WEATHER_API_KEY=${WEATHER_API_KEY}
              - CACHE_TIMEOUT=600
            volumes:
              - weather_data:/app/data
            restart: unless-stopped
            healthcheck:
              test: ["CMD", "curl", "-f", "http://localhost:8000/walker/health_check", "-X", "POST", "-H", "Content-Type: application/json", "-d", "{}"]
              interval: 30s
              timeout: 10s
              retries: 3

        volumes:
          weather_data:
        ```

### Building and Testing Docker Images

```bash
# Build the image
docker build -t weather-api:latest .

# Test locally
docker run -p 8000:8000 \
  -e WEATHER_API_KEY=your-key \
  -e DEBUG=true \
  weather-api:latest

# Test with docker-compose
echo "WEATHER_API_KEY=your-key" > .env
docker-compose up -d

# View logs
docker-compose logs -f weather-api

# Test the containerized API
curl -X POST http://localhost:8000/walker/get_weather \
  -H "Content-Type: application/json" \
  -d '{"city": "London"}'

# Check health
curl -X POST http://localhost:8000/walker/health_check \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## Kubernetes Deployment

Kubernetes provides orchestration, scaling, and reliability for production deployments.

### Kubernetes Manifests

!!! example "Complete Kubernetes Deployment"
    === "namespace.yaml"
        ```yaml
        # k8s/namespace.yaml
        apiVersion: v1
        kind: Namespace
        metadata:
          name: weather-app
          labels:
            app: weather-api
        ```

    === "configmap.yaml"
        ```yaml
        # k8s/configmap.yaml
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: weather-config
          namespace: weather-app
        data:
          DEBUG: "false"
          CACHE_TIMEOUT: "600"
          PORT: "8000"
        ```

    === "secret.yaml"
        ```yaml
        # k8s/secret.yaml
        apiVersion: v1
        kind: Secret
        metadata:
          name: weather-secrets
          namespace: weather-app
        type: Opaque
        data:
          weather-api-key: eW91ci1iYXNlNjQtZW5jb2RlZC1hcGkta2V5  # Base64 encoded
        ```

    === "deployment.yaml"
        ```yaml
        # k8s/deployment.yaml
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: weather-api
          namespace: weather-app
          labels:
            app: weather-api
        spec:
          replicas: 3
          selector:
            matchLabels:
              app: weather-api
          template:
            metadata:
              labels:
                app: weather-api
            spec:
              containers:
              - name: weather-api
                image: weather-api:latest
                ports:
                - containerPort: 8000
                env:
                - name: WEATHER_API_KEY
                  valueFrom:
                    secretKeyRef:
                      name: weather-secrets
                      key: weather-api-key
                envFrom:
                - configMapRef:
                    name: weather-config
                resources:
                  limits:
                    cpu: "1"
                    memory: "1Gi"
                  requests:
                    cpu: "500m"
                    memory: "512Mi"
                livenessProbe:
                  httpPost:
                    path: /walker/health_check
                    port: 8000
                    httpHeaders:
                    - name: Content-Type
                      value: application/json
                  initialDelaySeconds: 30
                  periodSeconds: 30
                readinessProbe:
                  httpPost:
                    path: /walker/health_check
                    port: 8000
                    httpHeaders:
                    - name: Content-Type
                      value: application/json
                  initialDelaySeconds: 5
                  periodSeconds: 10
        ```

    === "service.yaml"
        ```yaml
        # k8s/service.yaml
        apiVersion: v1
        kind: Service
        metadata:
          name: weather-api-service
          namespace: weather-app
        spec:
          selector:
            app: weather-api
          ports:
          - protocol: TCP
            port: 80
            targetPort: 8000
          type: ClusterIP
        ```

    === "ingress.yaml"
        ```yaml
        # k8s/ingress.yaml
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: weather-api-ingress
          namespace: weather-app
          annotations:
            kubernetes.io/ingress.class: "nginx"
            nginx.ingress.kubernetes.io/rewrite-target: /
        spec:
          rules:
          - host: weather-api.yourdomain.com
            http:
              paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: weather-api-service
                    port:
                      number: 80
        ```

### Deploying to Kubernetes

```bash
# Deploy everything in order
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml

# Create secret with your actual API key
echo -n "your-actual-api-key" | base64
# Update secret.yaml with the base64 value
kubectl apply -f k8s/secret.yaml

kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

# Check deployment status
kubectl get all -n weather-app

# Watch pods come online
kubectl get pods -n weather-app -w

# Check logs
kubectl logs -f deployment/weather-api -n weather-app

# Test the service
kubectl port-forward service/weather-api-service 8080:80 -n weather-app

# Test from another terminal
curl -X POST http://localhost:8080/walker/get_weather \
  -H "Content-Type: application/json" \
  -d '{"city": "Tokyo"}'
```

---

## Kubernetes Deployment

!!! warning "jac-cloud is Deprecated"
    The jac-cloud deployment method described below is deprecated. For new deployments, use **jac-scale** which provides:

    - Simplified deployment with `jac start --scale app.jac`
    - Auto-provisioned MongoDB and Redis
    - Built-in health checks and scaling
    - See the [Production (jac-scale) documentation](../production/index.md) for current deployment instructions.

The following section shows the legacy jac-cloud Kubernetes deployment approach for reference.

### Jac Cloud Setup

!!! example "Jac Cloud Deployment"
    === "Directory Structure"
        ```
jac-cloud/
        ├── scripts/
        │   ├── Dockerfile
        │   ├── init_jac_cloud.sh
        │   └── jac-cloud.yml
        └── weather_api.jac
        ```

    === "Prerequisites"
        ```bash
        # Prerequisites for Jac Cloud deployment
        # 1. Kubernetes cluster access
        kubectl cluster-info

        # 2. Docker for building images
        docker --version

        # 3. kubectl configured
        kubectl config current-context

        # 4. Target namespace should be created before deployment
        kubectl create namespace littlex

        # 5. Optional: OpenAI API key
        echo "OPENAI_API_KEY=your-key-here" > .env
        ```

    === "Build and Deploy"
        ```bash
        # 1. Build and push Docker image
        docker build -t your-dockerhub-username/jac-cloud:latest -f jac-cloud/scripts/Dockerfile .
        docker push your-dockerhub-username/jac-cloud:latest

        # 2. Update image reference in jac-cloud.yml
        sed -i 's|image: .*|image: your-dockerhub-username/jac-cloud:latest|' jac-cloud/scripts/jac-cloud.yml


        # 4. Deploy Jac Cloud application
        kubectl apply -f jac-cloud/scripts/jac-cloud.yml

        # 5. Verify deployment
        kubectl get all -n littlex
        ```

### Jac Cloud Configuration Files

!!! example "Complete Jac Cloud Configuration"
    === "jac-cloud.yml"
        ```yaml
        # jac-cloud/scripts/jac-cloud.yml
        apiVersion: v1
        kind: Namespace
        metadata:
          name: littlex
        ---
        apiVersion: v1
        kind: ServiceAccount
        metadata:
          name: jac-cloud-sa
          namespace: littlex
        ---
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRole
        metadata:
          name: jac-cloud-role
        rules:
        - apiGroups: [""]
          resources: ["pods", "services", "configmaps"]
          verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
        - apiGroups: ["apps"]
          resources: ["deployments"]
          verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
        ---
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRoleBinding
        metadata:
          name: jac-cloud-binding
        roleRef:
          apiGroup: rbac.authorization.k8s.io
          kind: ClusterRole
          name: jac-cloud-role
        subjects:
        - kind: ServiceAccount
          name: jac-cloud-sa
          namespace: littlex
        ---
        apiVersion: v1
        kind: Secret
        metadata:
          name: openai-secret
          namespace: littlex
        type: Opaque
        data:
          openai-key: eW91ci1iYXNlNjQtZW5jb2RlZC1rZXk=  # Replace with your base64 encoded key
        ---
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: jac-cloud
          namespace: littlex
        spec:
          replicas: 1
          selector:
            matchLabels:
              app: jac-cloud
          template:
            metadata:
              labels:
                app: jac-cloud
            spec:
              serviceAccountName: jac-cloud-sa
              containers:
              - name: jac-cloud
                image: your-dockerhub-username/jac-cloud:latest
                ports:
                - containerPort: 8000
                env:
                - name: NAMESPACE
                  value: "littlex"
                - name: FILE_NAME
                  value: "weather_api.jac"
                - name: OPENAI_API_KEY
                  valueFrom:
                    secretKeyRef:
                      name: openai-secret
                      key: openai-key
                volumeMounts:
                - name: config-volume
                  mountPath: /app/config
                resources:
                  limits:
                    cpu: "1"
                    memory: "2Gi"
                  requests:
                    cpu: "500m"
                    memory: "1Gi"
        ---
        apiVersion: v1
        kind: Service
        metadata:
          name: jac-cloud-service
          namespace: littlex
        spec:
          selector:
            app: jac-cloud
          ports:
          - protocol: TCP
            port: 80
            targetPort: 8000
          type: LoadBalancer
        ```

    === "Dockerfile"
        ```dockerfile
        # jac-cloud/scripts/Dockerfile
        FROM python:3.11-slim

        # Set working directory
        WORKDIR /app

        # Install system dependencies
        RUN apt-get update && apt-get install -y \
            curl \
            git \
            && rm -rf /var/lib/apt/lists/*

        # Install Jac and required packages
        RUN pip install jaclang

        # Copy application files
        COPY weather_api.jac .
        COPY jac-cloud/scripts/init_jac_cloud.sh .

        # Make scripts executable
        RUN chmod +x init_jac_cloud.sh

        # Expose port
        EXPOSE 8000

        # Set environment variables
        ENV JAC_FILE=weather_api.jac
        ENV PORT=8000
        ENV NAMESPACE=littlex

        # Health check
        HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
            CMD curl -f http://localhost:$PORT/walker/health_check -X POST -H "Content-Type: application/json" -d '{}' || exit 1

        # Run the application
        CMD ["./init_jac_cloud.sh"]
        ```

### Environment Variables and Configuration

The Jac Cloud deployment supports the following environment variables:

| Variable          | Description                              | Default Value |
|--------------------|------------------------------------------|---------------|
| `NAMESPACE`        | Target namespace for the deployment     | `default`     |
| `FILE_NAME`        | JAC file to execute in the pod          | `example.jac` |
| `OPENAI_API_KEY`   | OpenAI API key (from secret)            | None          |

### Step-by-Step Deployment Guide

Follow these steps to deploy your Jac application to Kubernetes:

```bash
# 1. Build and push Docker image
docker build -t your-dockerhub-username/jac-cloud:latest -f jac-cloud/scripts/Dockerfile .
docker push your-dockerhub-username/jac-cloud:latest

# 2. Update image reference in jac-cloud.yml
sed -i 's|image: .*|image: your-dockerhub-username/jac-cloud:latest|' jac-cloud/scripts/jac-cloud.yml

# 4. Deploy Jac Cloud application
kubectl apply -f jac-cloud/scripts/jac-cloud.yml

# 5. Verify deployment
kubectl get all -n littlex
```

### Monitoring and Updating

```bash
# Monitor logs in real-time
kubectl logs -f deployment/jac-cloud -n littlex

# Update configurations
# 1. Modify the YAML files as needed
# 2. Apply the changes:
kubectl apply -f jac-cloud/scripts/jac-cloud.yml

# Scale for handling more traffic
kubectl scale deployment jac-cloud --replicas=3 -n littlex

# Configure resource limits (edit jac-cloud.yml first)
# Then apply:
kubectl apply -f jac-cloud/scripts/jac-cloud.yml
```

### Troubleshooting and Validation

```bash
# Verify namespace exists
kubectl get namespaces

# Verify ConfigMap is properly applied
kubectl get configmap -n littlex

# Verify deployment status
kubectl get pods -n littlex

# View logs for troubleshooting
kubectl logs -f deployment/jac-cloud -n littlex

# Check all resources in the namespace
kubectl get all -n littlex
```

### Advanced Configuration Management

```bash
# Restart deployment to pick up config changes
kubectl rollout restart deployment/jac-cloud -n littlex

# Scale the deployment for increased capacity
kubectl scale deployment jac-cloud --replicas=3 -n littlex

# Check rollout status
kubectl rollout status deployment/jac-cloud -n littlex

# Adjust CPU and memory limits in jac-cloud.yml
# Then apply the changes:
kubectl apply -f jac-cloud/scripts/jac-cloud.yml
```

---

### Cleanup

To remove all deployed resources when you're done:

```bash
# Remove the entire namespace and all resources
kubectl delete namespace littlex

# This will delete all resources associated with your Jac Cloud deployment
```

---

## Production Monitoring and Maintenance

### Enhanced Health Checks and Metrics

!!! example "Production-Ready Weather API"
    ```jac
    # production_weather.jac
    import from datetime { datetime }
    import from time { time }

    glob metrics = {
        "requests_total": 0,
        "requests_per_city": {},
        "cache_hits": 0,
        "cache_misses": 0,
        "start_time": time()
    };

    node WeatherData {
        has city: str;
        has temperature: float;
        has description: str;
        has last_updated: str;
    }

    walker get_weather {
        has city: str;

        can fetch_weather with `root entry {
            # Update metrics
            metrics["requests_total"] += 1;
            metrics["requests_per_city"][self.city] = metrics["requests_per_city"].get(self.city, 0) + 1;

            # Check cache first
            cached = [-->(`?WeatherData)](?city == self.city);

            if cached {
                metrics["cache_hits"] += 1;
                weather = cached[0];
                report {
                    "city": weather.city,
                    "temperature": weather.temperature,
                    "description": weather.description,
                    "cached": True
                };
            } else {
                metrics["cache_misses"] += 1;
                # Simulate external API call
                new_weather = WeatherData(
                    city=self.city,
                    temperature=22.5,
                    description="Sunny",
                    last_updated=datetime.now().isoformat()
                );
                here ++> new_weather;

                report {
                    "city": self.city,
                    "temperature": 22.5,
                    "description": "Sunny",
                    "cached": False
                };
            }
        }
    }

    walker health_check {
        can check_health with `root entry {
            uptime = time() - metrics["start_time"];
            cache_hit_rate = metrics["cache_hits"] / max(metrics["requests_total"], 1) * 100;

            report {
                "status": "healthy",
                "uptime_seconds": uptime,
                "total_requests": metrics["requests_total"],
                "cache_hit_rate_percent": round(cache_hit_rate, 2),
                "cached_cities": len([-->(`?WeatherData)]),
                "timestamp": datetime.now().isoformat()
            };
        }
    }

    walker metrics_endpoint {
        can get_metrics with `root entry {
            uptime = time() - metrics["start_time"];
            cache_hit_rate = metrics["cache_hits"] / max(metrics["requests_total"], 1) * 100;

            report {
                "uptime_seconds": uptime,
                "total_requests": metrics["requests_total"],
                "cache_hit_rate_percent": round(cache_hit_rate, 2),
                "requests_by_city": metrics["requests_per_city"],
                "timestamp": datetime.now().isoformat()
            };
        }
    }

    walker detailed_health_check {
        can comprehensive_health with `root entry {
            cached_cities = len([-->(`?WeatherData)]);
            memory_usage = "healthy";  # Simplified for demo

            # Check if service is responding normally
            status = "healthy";
            if metrics["requests_total"] == 0 and time() - metrics["start_time"] > 300 {
                status = "warning";  # No requests in 5 minutes
            }

            report {
                "status": status,
                "cached_cities": cached_cities,
                "total_requests": metrics["requests_total"],
                "memory_status": memory_usage,
                "uptime_seconds": time() - metrics["start_time"],
                "version": "1.0.0"
            };
        }
    }
    ```

### Scaling and Performance

```bash
# Manual scaling
kubectl scale deployment jac-cloud --replicas=3 -n littlex

# Horizontal Pod Autoscaler
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: jac-cloud-hpa
  namespace: littlex
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: jac-cloud
  minReplicas: 1
  maxReplicas: 5
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
EOF

# Monitor scaling
kubectl get hpa -n littlex -w

# Load testing (using hey or similar)
hey -n 1000 -c 10 -m POST \
  -H "Content-Type: application/json" \
  -d '{"city":"London"}' \
  http://your-service-url/walker/get_weather

# Check resource usage during load test
kubectl top pods -n littlex
```

---

## Best Practices

!!! summary "Deployment Guidelines"
    - **Create namespaces beforehand**: Ensure target namespaces exist before deployment
    - **Monitor resource usage**: Track CPU and memory consumption for optimal scaling
    - **Secure API keys**: Use Kubernetes secrets for sensitive configuration
    - **Plan for module dependencies**: Configure dependencies correctly in the module configuration
    - **Test locally first**: Verify your JAC application works before deploying to the cloud
    - **Version your deployments**: Tag Docker images with specific versions for reproducible deployments
    - **Clean up resources**: Always clean up test deployments to avoid unnecessary costs

## Key Takeaways

!!! summary "What We've Learned"
    **Deployment Strategies:**

    - **Local development**: Same code runs everywhere without modifications
    - **Docker containerization**: Package applications for consistent deployment
    - **Kubernetes orchestration**: Production-grade scaling and reliability
    - **Jac Cloud integration**: Kubernetes-based deployment with built-in module management

    **Production Features:**

    - **Module management**: Dynamic loading of Python modules with resource control
    - **RBAC security**: Proper service accounts and role-based access control
    - **Health checks**: Monitor application health and readiness
    - **Resource management**: Control CPU and memory usage effectively
    - **Scaling strategies**: Manual and automatic scaling based on demand
    - **Configuration management**: Secure and flexible environment configuration

    **Monitoring and Maintenance:**

    - **Metrics collection**: Track application performance and usage
    - **Log aggregation**: Centralized logging for debugging and analysis
    - **Resource monitoring**: Track module resource usage and optimization
    - **Performance optimization**: Identify and resolve bottlenecks
    - **Troubleshooting tools**: Use kubectl commands for debugging deployments

    **Best Practices:**

    - **Infrastructure as Code**: Version control your deployment configurations
    - **Module optimization**: Configure appropriate resource limits for each module
    - **Security hardening**: Implement security best practices at every layer
    - **Namespace isolation**: Use dedicated namespaces for different environments
    - **Progressive deployment**: Test in staging before production rollout

!!! tip "Try It Yourself"
    Practice deployment by:
    - Setting up the Jac Cloud deployment with your own Docker registry
    - Experimenting with different module configurations and resource limits
    - Implementing comprehensive monitoring and alerting systems
    - Testing scaling behavior under different load conditions
    - Creating CI/CD pipelines for automated deployment workflows

    Remember: Jac Cloud provides a production-ready platform with built-in best practices for JAC applications!

---

*Ready to optimize performance? Continue to [Chapter 20: Performance Optimization](chapter_19.md)!*
