import from collections { defaultdict }
class DuplicatedNameError(NameError) {}
class NameScope(object) {
    def init(self: NameScope) -> object {
        self._useset = `set(['']);
        self._basenamemap = defaultdict(int);
    }
    def is_used(self: NameScope, name: Any) -> object {
        return (name in self._useset);
    }
    def register(self: NameScope, name: Any, deduplicate: Any = False) -> object {
        if deduplicate {
            name = self.deduplicate(name);
        } elif self.is_used(name) {
            raise DuplicatedNameError(name);
        }
        self._useset.add(name);
        return name;
    }
    def deduplicate(self: NameScope, name: Any) -> object {
        basename = name;
        while self.is_used(name) {
            ident = self._basenamemap[basename] + 1;
            self._basenamemap[basename] = ident;
            name = "{0}.{1}".format(basename, ident);
        }
        return name;
    }
    def get_child(self: NameScope) -> object {
        return `type(self)(parent=self);
    }
}
class _StrCaching(object) {
    def _clear_string_cache(self: _StrCaching) -> object {
        try {
            del self.__cached_str;
        } except AttributeError {
            ;
        }
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
    def get_reference(self: _StringReferenceCaching) -> object {
        try {
            return self.__cached_refstr;
        } except AttributeError {
            s = self.__cached_refstr=self._get_reference();
            return s;
        }
    }
}
class _HasMetadata(object) {
    """
        Attach unnamed metadata *node* to the metadata slot *name* of this
        value.
        """
    def set_metadata(self: _HasMetadata, name: Any, `node: Any) -> object {
        self.metadata[name] = `node;
    }

    def _stringify_metadata(self: _HasMetadata, leading_comma: Any = False) -> object {
        if self.metadata {
            buf = [];
            if leading_comma {
                buf.append("");
            }
            buf += [
                "!{0} {1}".format(k, v.get_reference())
                for (k, v) in self.metadata.items()
            ];
            return ', '.join(buf);
        } else {
            return '';
        }
    }
}

