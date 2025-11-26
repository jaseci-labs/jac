poetry export --without-hashes --output requirements.txt
pip install --no-binary :all: --target=vendor/ -r requirements.txt
