import zipfile
import os

with zipfile.ZipFile("/jaclang.zip", "r") as zip_ref:
    zip_ref.extractall("/jaclang")

os.sys.path.append("/jaclang")
print("JacLang files loaded!")
