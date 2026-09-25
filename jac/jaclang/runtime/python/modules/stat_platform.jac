"""_stat platform flags for a target with no stat_platform.<os>.jac; the binding rejects it."""

glob:pub PLATFORM: str = "";

glob:pub S_IFWHT: u64 = 0,
     UF_SETTABLE: u64 = 0,
     UF_NODUMP: u64 = 0,
     UF_IMMUTABLE: u64 = 0,
     UF_APPEND: u64 = 0,
     UF_OPAQUE: u64 = 0,
     UF_NOUNLINK: u64 = 0,
     UF_COMPRESSED: u64 = 0,
     UF_TRACKED: u64 = 0,
     UF_DATAVAULT: u64 = 0,
     UF_HIDDEN: u64 = 0,
     SF_SETTABLE: u64 = 0,
     SF_ARCHIVED: u64 = 0,
     SF_IMMUTABLE: u64 = 0,
     SF_APPEND: u64 = 0,
     SF_NOUNLINK: u64 = 0,
     SF_SNAPSHOT: u64 = 0,
     SF_FIRMLINK: u64 = 0,
     SF_DATALESS: u64 = 0,
     SF_SUPPORTED: u64 = 0,
     SF_SYNTHETIC: u64 = 0,
     HAS_SF_SUPPORTED: bool = False;
