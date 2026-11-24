glob NEOJAC_INSTALL: str = "curl -fsSL https://github.com/jaseci-labs/neojac/releases/latest/download/install.sh | bash",
     HOME_INSTALL: str = "curl -fsSL https://jaclang.org/install.sh | bash",
     HOME_PROMPT: str = "Build [your idea] with the neojac binary",
     _PILLARS: list[dict[str, str]] = [
         {"num": "01", "id": "one-language", "title": "One universal language"},
         {"num": "02", "id": "no-glue", "title": "Abstractions beyond “high level”"},
         {"num": "03", "id": "agents", "title": "Agents built in"},
         {"num": "04", "id": "readable", "title": "Slop resistance"},

     ];

def:pub HomeHero -> JsxElement;
