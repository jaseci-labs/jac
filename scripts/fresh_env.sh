python3 -m venv .venv
source .venv/bin/activate
pip install -e jac
jac install -e jac-byllm
jac install -e jac-scale
jac install -e jac-super
jac install -e jac-mcp
pip install pre-commit
pre-commit install
pip install pytest pytest-xdist pytest-asyncio
