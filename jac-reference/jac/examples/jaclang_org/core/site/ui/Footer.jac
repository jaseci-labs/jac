import from "@jac/runtime" { Link }

glob _COLS: list[dict[str, any]] = [
         {
             "title": "Language",
             "links": [
                 {"label": "Documentation", "href": "/docs/latest"},
                 {"label": "Playground", "href": "https://playground.jaseci.org"},
                 {
                     "label": "First-app tutorial",
                     "href": "/docs/latest/tutorials/first-app/build-ai-day-planner"
                 },
                 {"label": "Install guide", "href": "/docs/latest/quick-guide/install"},

             ],

         },
         {
             "title": "Community",
             "links": [
                 {"label": "GitHub", "href": "https://github.com/jaseci-labs/jac"},
                 {"label": "Discord", "href": "https://discord.gg/6j3QNdtcN6"},
                 {
                     "label": "Contributing",
                     "href": "/docs/latest/community/contributing"
                 },
                 {
                     "label": "This is Jac (demo)",
                     "href": "https://github.com/jaseci-labs/this_is_jac"
                 },

             ],

         },
         {
             "title": "Research",
             "links": [
                 {
                     "label": "Object-Spatial Programming",
                     "href": "https://arxiv.org/abs/2503.15812"
                 },
                 {
                     "label": "Meaning-Typed Programming",
                     "href": "https://arxiv.org/abs/2405.08965"
                 },
                 {
                     "label": "The ninja book",
                     "href": "https://doi.org/10.5281/zenodo.21464040"
                 },
                 {
                     "label": "Research & papers",
                     "href": "/docs/latest/community/research"
                 },

             ],

         },

     ];

def:pub Footer -> JsxElement;
