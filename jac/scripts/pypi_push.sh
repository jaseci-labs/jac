python3 -m pip install --upgrade pip
pip install -U setuptools wheel twine
pip install -U build
python3 -m build
python3 -m twine upload --skip-existing dist/*
