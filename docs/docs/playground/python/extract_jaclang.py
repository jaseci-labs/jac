import zipfile
import sys

with zipfile.ZipFile("/jaclang.zip", "r") as zip_ref:
    zip_ref.extractall("/jaclang")

sys.path.append("/jaclang")
print("JacLang files loaded!")
