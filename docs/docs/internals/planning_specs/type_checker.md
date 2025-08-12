```python
from abc import ABC, abstractmethod
from enum import Enum
from typing import Any, Dict, List, Optional, Set, Union
from dataclasses import dataclass

class TypeCategory(Enum):
    """Categories of types in the Jac type system."""
    UNKNOWN = "unknown"
    UNBOUND = "unbound"
    ANY = "any"
    NEVER = "never"
    GENERIC = "generic"
    UNION = "union"
    OVERLOADED = "overloaded"
    MODULE = "module"
    CLASS = "class"
    FUNCTION = "function"
    TYPE_VAR = "type_var"
```

Need to discuss:
1. will UNBOUND be used effectively

2. Do we need overloaded?

3. Do we need separate class for ability
    add a flag

```python
class TypeFlags(Enum):
    """Flags for type instances."""
    NONE = 0
    INSTANTIABLE = 1 << 0
    INSTANCE = 1 << 1
    AMBIGUOUS = 1 << 2
    TypeCompatibilityMask = Instantiable | Instance
```
Need to discuss:
1. When we need ambiguous?

```python
@dataclass
class TypeBase(ABC):
    """Base class for all types in the Jac type system."""
    category: TypeCategory
    flags: TypeFlags = TypeFlags.NONE

    @abstractmethod
    def is_same_type(self, other: 'TypeBase') -> bool:
        """Check if this type is the same as another type."""
        pass

    @abstractmethod
    def is_assignable_to(self, target: 'TypeBase') -> bool:
        """Check if this type can be assigned to the target type."""
        pass

    @abstractmethod
    def get_display_name(self) -> str:
        """Get the display name for this type."""
        pass
```