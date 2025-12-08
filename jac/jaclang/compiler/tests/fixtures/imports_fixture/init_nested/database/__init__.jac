# database/__init__.jac
# Top-level package init - aggregates from subpackages

# Re-export from models subpackage
import from .models { User, Post }

# Re-export from connections subpackage
import from .connections { connect, disconnect }

# Package-level constant
glob DB_VERSION = "3.0.0";
