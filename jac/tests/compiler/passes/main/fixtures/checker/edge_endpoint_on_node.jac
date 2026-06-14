"""An endpoint clause `: Src --> Tgt` is only valid on an edge archetype (#6657)."""
node Profile { has name: str = ""; }
node Bad: Profile --> Profile {}
