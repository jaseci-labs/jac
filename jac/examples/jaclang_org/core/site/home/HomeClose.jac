import from "@jac/runtime" { Link }

glob _INSTALL: str = "curl -fsSL https://jaclang.org/install.sh | bash",
     _NEXT: list[dict[str, str]] = [
         {
             "to": "/tech-demo",
             "title": "Tech demo",
             "body": "A WebAssembly game, this site's live source, the mobile app and more."
         },
         {
             "to": "/docs/latest",
             "title": "Documentation",
             "body": "The install guide, a first app and the language reference."
         },
         {
             "to": "/wait-wuuut",
             "title": "Wait, Wuuut?!",
             "body": "The ideas behind Jac's design."
         },

     ];

def:pub HomeClose -> JsxElement;
