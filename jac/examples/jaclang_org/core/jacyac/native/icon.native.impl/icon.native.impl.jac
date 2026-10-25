impl Icon(name: str, size: int, color: str, fill: bool = False) -> JsxElement {
    Glyph = LUCIDE[name];
    <Glyph size={size} color={color} fill={color if fill else "none"} strokeWidth={2}/>
}
