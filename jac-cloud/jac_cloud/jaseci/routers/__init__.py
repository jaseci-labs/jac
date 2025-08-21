"""Jaseci Routers."""

from .healthz import router as healthz_router
from .sso import router as sso_router
from .user import router as user_router
from .utils import router as utils_router
from .webhook import router as webhook_router

routers = [healthz_router, sso_router, user_router, webhook_router, utils_router]
