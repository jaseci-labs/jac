"""App holder for gunicorn multi-worker mode.

Gunicorn workers need to access the FastAPI app instance. This module
stores the app so workers can import it.
"""

from typing import Any

# Module-level storage for the app
app: Any = None
