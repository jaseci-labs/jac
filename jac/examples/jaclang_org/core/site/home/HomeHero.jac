glob HOME_INSTALL: str = "curl -fsSL https://jaclang.org/install.sh | bash",
     HOME_PROMPT: str = "Build [your idea] with the jac binary",
     _PILLARS: list[dict[str, str]] = [
         {"num": "01", "id": "one-language", "title": "One universal language"},
         {"num": "02", "id": "no-glue", "title": "Abstractions beyond “high level”"},
         {"num": "03", "id": "agents", "title": "Agents built in"},
         {"num": "04", "id": "readable", "title": "Slop resistance"},

     ];

def:pub HomeHero -> JsxElement;
