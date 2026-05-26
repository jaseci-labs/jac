"""Client-side validation for jac-shadcn theme parameters.

The plugin ships a hardcoded set of known-valid values as a fallback so it
works against the public registry today. When the registry exposes a
`GET /options` endpoint (a planned 15-line addition on the registry side),
the plugin prefers that response so self-hosted mirrors with custom themes
work without a plugin bump.

Lists kept in sync with the registry at /home/ahzan-dev/Documents/jaseci/jac-shadcn/
(data/themes.json, lib/styles.cl.jac, lib/fonts.cl.jac, lib/config.cl.jac)
as of jac-shadcn 0.4.0. Bump these when the registry adds new options.
"""

"""Known-valid styles (5)."""
glob KNOWN_STYLES: list = ["nova", "vega", "maia", "lyra", "mira"];

"""Known-valid baseColors (4 -- the grayscale foundations)."""
glob KNOWN_BASE_COLORS: list = ["neutral", "stone", "zinc", "gray"];

"""Known-valid themes (21 -- 4 grayscale + 17 accents)."""
glob KNOWN_THEMES: list = [
         "amber",
         "blue",
         "cyan",
         "emerald",
         "fuchsia",
         "gray",
         "green",
         "indigo",
         "lime",
         "neutral",
         "orange",
         "pink",
         "purple",
         "red",
         "rose",
         "sky",
         "stone",
         "teal",
         "violet",
         "yellow",
         "zinc",

     ];

"""Known-valid fonts (12 -- param values, not display names)."""
glob KNOWN_FONTS: list = [
         "geist",
         "geist-mono",
         "inter",
         "noto-sans",
         "nunito-sans",
         "figtree",
         "roboto",
         "raleway",
         "dm-sans",
         "public-sans",
         "outfit",
         "jetbrains-mono",

     ];

"""Known-valid radii. NOTE: registry uses 'small/medium/large', NOT 'sm/md/lg'."""
glob KNOWN_RADII: list = ["default", "none", "small", "medium", "large"];

"""Known-valid menuAccents."""
glob KNOWN_MENU_ACCENTS: list = ["subtle", "bold"];

"""Process-lifetime cache of /options responses, keyed by registry URL.
Populated lazily on first validation attempt; survives subsequent calls
within the same CLI invocation."""
glob _options_cache: dict = {};


"""Fetch /options from the registry once and cache it. Returns the parsed
dict, or None if the registry has no /options endpoint yet (the common
case today). Callers fall back to the hardcoded lists above when None."""
def _load_registry_options(registry_url: str) -> any;


"""Resolve the universe of valid values for one field, preferring the
registry's /options response if available. Falls back to the hardcoded
list above."""
def _valid_values(field: str, registry_url: str) -> list;


"""Validate a single theme param. Returns (ok, suggestions):
  - (True, []) when value is None/empty (treat as "not specified") or valid
  - (False, [close_matches]) when invalid
The caller decides whether to error or carry on.
"""
def validate_field(field: str, value: any, registry_url: str) -> tuple;


"""Validate a whole theme params dict in one shot. Returns a list of
human-readable error strings; empty list means everything checks out.
Use this from the CLI handler to fail fast before any HTTP call."""
def validate_theme_params(params: dict, registry_url: str) -> list;
