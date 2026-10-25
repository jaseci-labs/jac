# Jac package marker so `import tests.support` resolves under the sealed
# binary when `jac/` is on JACPATH (meta_importer only treats __init__.jac as
# a package root, not the legacy __init__.py beside this file).
