# app/services/__init__.jac
# Services package initialization - re-exports service functions
import from .user_service {
    create_user,
    get_version
}
