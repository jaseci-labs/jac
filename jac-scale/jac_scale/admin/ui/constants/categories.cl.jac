"""Sidebar navigation groups for the admin portal.

Only IMPLEMENTED pages are listed - the many placeholder/"coming soon"
stubs are intentionally hidden until they're built, so the sidebar
reflects what actually works. Add an entry here (and a matching route
in DashboardLayout's PAGE_ROUTES) when a page goes live.
"""

cl {
    glob:pub navGroups = [
             {
                 "label": "Authentication",
                 "items": [
                     {"id": "users", "label": "Users"},
                     {"id": "sso", "label": "SSO"}
                 ]
             },
             {
                 "label": "Monitoring",
                 "items": [
                     {"id": "metrics", "label": "Metrics"},
                     {"id": "llm_metrics", "label": "LLM Metrics"},
                     {"id": "llm_traces", "label": "LLM Traces"},
                     {"id": "traces", "label": "Traces"},
                     {"id": "logs", "label": "Logs"}
                 ]
             }
         ];
}
