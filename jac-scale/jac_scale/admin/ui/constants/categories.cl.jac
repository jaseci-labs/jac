"""Category and sub-tab definitions for admin portal navigation."""

cl {
    glob:pub categories = [
             {"id": "auth", "label": "Authentication", "default": "users"},
             {"id": "data", "label": "Data", "default": "graph"},
             {"id": "ops", "label": "Operations", "default": "walkers"},
             {"id": "monitor", "label": "Monitoring", "default": "metrics"},
             {"id": "settings", "label": "Settings", "default": "config"},
             {"id": "integrations", "label": "Integrations", "default": "email"},
             {"id": "deploy", "label": "Deployment", "default": "deployments"},
             {"id": "audit", "label": "Audit", "default": "activity"}
         ];

    glob:pub subTabs = {
             "auth": [
                 {"id": "users", "label": "Users"},
                 {"id": "sso", "label": "SSO"},
                 {"id": "sessions", "label": "Sessions"},
                 {"id": "apikeys", "label": "API Keys"}
             ],
             "data": [
                 {"id": "graph", "label": "Graph"},
                 {"id": "storage", "label": "Storage"},
                 {"id": "cache", "label": "Cache"}
             ],
             "ops": [
                 {"id": "walkers", "label": "Walkers"},
                 {"id": "jobs", "label": "Jobs"},
                 {"id": "webhooks", "label": "Webhooks"}
             ],
             "monitor": [
                 {"id": "metrics", "label": "Metrics"},
                 {"id": "logs", "label": "Logs"},
                 {"id": "health", "label": "Health"},
                 {"id": "alerts", "label": "Alerts"}
             ],
             "settings": [
                 {"id": "config", "label": "Configuration"},
                 {"id": "environment", "label": "Environment"},
                 {"id": "secrets", "label": "Secrets"},
                 {"id": "ratelimits", "label": "Rate Limits"},
                 {"id": "cors", "label": "CORS"}
             ],
             "integrations": [
                 {"id": "email", "label": "Email"},
                 {"id": "notifications", "label": "Notifications"},
                 {"id": "storage_providers", "label": "Storage"},
                 {"id": "database", "label": "Database"}
             ],
             "deploy": [
                 {"id": "deployments", "label": "Deployments"},
                 {"id": "scaling", "label": "Scaling"},
                 {"id": "pods", "label": "Pods"}
             ],
             "audit": [
                 {"id": "activity", "label": "Activity Log"},
                 {"id": "security", "label": "Security Events"}
             ]
         };
}
