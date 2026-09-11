import from collections { defaultdict }
class DuplicatedNameError(NameError) {}
class NameScope(object) {
    def init(self: NameScope) -> object {
        self._useset = `set(['']);
        self._basenamemap = defaultdict(int);
    }

    def is_used(self: NameScope, name: any) -> object {
        return (name in self._useset);
    }

    def register(self: NameScope, name: any, deduplicate: any = False) -> object {
        if deduplicate {
            name = self.deduplicate(name);
        } elif self.is_used(name) {
            raise DuplicatedNameError(name);
        }
        self._useset.add(name);
        return name;
    }

    def deduplicate(self: NameScope, name: any) -> object {
        basename = name;
        while self.is_used(name) {
            ident = self._basenamemap[basename] + 1;
            self._basenamemap[basename] = ident;
            name = "{0}.{1}".format(basename, ident);
        }
        return name;
    }
}

class _StrCaching(object) {
    has __cached_str: str;

    def _to_string(self: _StrCaching) -> object {
        raise NotImplementedError;
    }

    def _clear_string_cache(self: _StrCaching) -> object {
        try {
            del self.__cached_str;
        } except AttributeError {}
    }

    def __str__(self: _StrCaching) -> object {
        try {
            return self.__cached_str;
        } except AttributeError {
            s = self.__cached_str=self._to_string();
            return s;
        }
    }
}

class _StringReferenceCaching(object) {
    has __cached_refstr: str;

    def _get_reference(self: _StringReferenceCaching) -> str {
        raise NotImplementedError;
    }

    def get_reference(self: _StringReferenceCaching) -> str {
        try {
            return self.__cached_refstr;
        } except AttributeError {
            s = self.__cached_refstr=self._get_reference();
            return s;
        }
    }
}

class _HasMetadata(object) {
    has metadata: dict[str, _StringReferenceCaching | list[_StringReferenceCaching]];

    """
        Attach unnamed metadata *node* to the metadata slot *name* of this
        value.
        """
    def set_metadata(self: _HasMetadata, name: any, `node: any) -> object {
        self.metadata[name] = `node;
    }

    def add_metadata(self: _HasMetadata, name: str, value: _StringReferenceCaching) {
        previous = self.metadata.get(name);
        if previous is None {
            self.metadata[name] = value;
        } elif isinstance(previous, list) {
            previous.append(value);
        } else {
            self.metadata[name] = [previous, value];
        }
    }

    def _stringify_metadata(self: _HasMetadata, leading_comma: any = False) -> object {
        if self.metadata {
            buf = [];
            if leading_comma {
                buf.append("");
            }
            for (key, values) in self.metadata.items() {
                for value in (values if isinstance(values, list) else [values]) {
                    buf.append("!{0} {1}".format(key, value.get_reference()));
                }
            }
            return ', '.join(buf);
        } else {
            return '';
        }
    }
}
