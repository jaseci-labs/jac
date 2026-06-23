"""Sidebar navigation groups for the admin portal.

Only IMPLEMENTED pages are listed - the many placeholder/"coming soon"
stubs are intentionally hidden until they're built, so the sidebar
reflects what actually works. Add an entry here (and a matching route
in DashboardLayout's PAGE_ROUTES) when a page goes live.
"""

glob:pub navGroups = [
         {
             "label": "Authentication",
             "items": [{"id": "users", "label": "Users"}, {"id": "sso", "label": "SSO"}]
         },
         {
             "label": "Monitoring",
             "items": [
                 {"id": "metrics", "label": "Metrics"},
                 {"id": "services", "label": "Services"},
                 {"id": "llm_metrics", "label": "LLM Metrics"},
                 {"id": "llm_traces", "label": "LLM Traces"},
                 {"id": "traces", "label": "Traces"},
                 {"id": "logs", "label": "Logs"}
             ]
         },
         {
             "label": "Operations",
             "items": [
                 {"id": "ops", "label": "Self-Check"},
                 {"id": "deploy", "label": "Deploy Health"},
                 {"id": "network", "label": "Endpoints & Storage"},
                 {"id": "podenv", "label": "Pod Env"}
             ]
         }
     ];
