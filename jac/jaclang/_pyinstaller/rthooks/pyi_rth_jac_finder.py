# Runtime hook: frozen apps skip ``.pth``, so install the Jac meta-path
# finder here before user code runs. Registered via rthooks.dat.
import _jac_finder

_jac_finder.install()
