python3 -m venv .venv
source .venv/bin/activate
pip install -e jac
pip install -e jac-byllm
pip install -e jac-scale
pip install -e jac-client
pip install pre-commit
pre-commit install
pip install pytest pytest-xdist pytest-asyncio
