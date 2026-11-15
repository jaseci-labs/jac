enum Shade;

enum Level;

obj Paint;

impl Shade{
    DARK = "dark",
    LIGHT = "light"
}

impl Level{
    LOW = 1,
    HIGH = 7
}

impl Paint{
    has shade: Shade,
        level: Level = Level.LOW;

    def label -> str {
        return f"{self.shade.value}/{self.level.value}";
    }
}

with entry {
    p = Paint(shade=Shade.DARK);
    q = Paint(shade=Shade.LIGHT, level=Level.HIGH);
    print(p.label(), q.label(), p.shade == Shade.DARK, q.level == Level.HIGH);
    print(Shade.LIGHT.name, Level.HIGH.name, Level.LOW.value + Level.HIGH.value);
}
