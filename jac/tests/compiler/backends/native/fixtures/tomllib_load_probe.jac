import os;
import tomllib;

with entry {
    path = os.path.join("/tmp", f"jac_tomllib_load_probe_{os.getpid()}.toml");
    with open(path, "w") as out {
        out.write('[project]\nname = "probe"\nversion = "1.2.3"\n\n[serve]\nport = 8080\nhot = true\n');
    }
    with open(path, "rb") as handle {
        data = tomllib.load(handle);
    }
    project = data["project"];
    serve = data["serve"];
    print("name", project["name"]);
    print("version", project["version"]);
    print("port", serve["port"]);
    print("hot", serve["hot"]);
    print("tables", sorted(data.keys()));
    os.remove(path);
}
