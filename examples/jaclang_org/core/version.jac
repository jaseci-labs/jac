"""The release of jac the knowledge service follows: the tag of the jac
repository its checkout serves, and the jac ninjaclaw's tutorials are verified
on. The docs the site serves are jac's, labelled by core.docs.guides."""

import os;

def resolve_cli_version -> str {
    return os.environ.get("JAC_VERSION", "0.39.1");
}
