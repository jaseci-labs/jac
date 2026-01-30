import subprocess


def _call(*args, **kwargs):
    kwargs["text"] = True
    try:
        return subprocess.check_output(*args, **kwargs).splitlines()
    except subprocess.CalledProcessError:
        return []


class FilesCompleter:
    """File completer class, optionally takes a list of allowed extensions."""

    def __init__(self, allowednames=(), directories=True):
        if isinstance(allowednames, (str, bytes)):
            allowednames = [allowednames]
        self.allowednames = [x.lstrip("*").lstrip(".") for x in allowednames]
        self.directories = directories

    def __call__(self, prefix, **kwargs):
        completion = []
        if self.allowednames:
            if self.directories:
                files = _call(
                    ["bash", "-c", f"bind; compgen -A directory -- '{prefix}'"],
                    stderr=subprocess.DEVNULL,
                )
                completion += [f + "/" for f in files]
            for x in self.allowednames:
                completion += _call(
                    ["bash", "-c", f"bind; compgen -A file -X '!*.{x}' -- '{prefix}'"],
                    stderr=subprocess.DEVNULL,
                )
        else:
            completion += _call(
                ["bash", "-c", f"bind; compgen -A file -- '{prefix}'"],
                stderr=subprocess.DEVNULL,
            )
            anticomp = _call(
                ["bash", "-c", f"bind; compgen -A directory -- '{prefix}'"],
                stderr=subprocess.DEVNULL,
            )
            completion = list(set(completion) - set(anticomp))
            if self.directories:
                completion += [f + "/" for f in anticomp]
        return completion
