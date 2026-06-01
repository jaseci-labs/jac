"""Category and sub-tab definitions for admin portal navigation."""

cl {
    glob:pub categories = [
             {"id": "auth", "label": "Authentication", "default": "users"},
             {"id": "data", "label": "Data", "default": "graph"},
             {"id": "ops", "label": "Operations", "default": "walkers"},
             {"id": "monitor", "label": "Monitoring", "default": "metrics"},
             {"id": "settings", "label": "Settings", "default": "config"},
             {"id": "integrations", "label": "Integrations", "default": "email"},
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
                 {"id": "workloads", "label": "Workloads"},
                 {"id": "usage", "label": "Usage"},
                 {"id": "llm_metrics", "label": "LLM Metrics"},
                 {"id": "llm_traces", "label": "LLM Traces"},
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
             "audit": [
                 {"id": "activity", "label": "Activity Log"},
                 {"id": "security", "label": "Security Events"}
             ]
         };
}
