// Enum TypeScript fixture

// Numeric enum (auto-incremented)
enum Direction {
    Up,
    Down,
    Left,
    Right,
}

// Numeric enum with explicit values
enum StatusCode {
    OK = 200,
    BadRequest = 400,
    Unauthorized = 401,
    NotFound = 404,
    InternalError = 500,
}

// String enum
enum Color {
    Red = "RED",
    Green = "GREEN",
    Blue = "BLUE",
}

// Mixed enum (not recommended but valid)
enum Mixed {
    No = 0,
    Yes = "YES",
}

// Const enum (inlined at compile time)
const enum FastEnum {
    A = 1,
    B = 2,
    C = 3,
}

// Computed values
enum FileAccess {
    None,
    Read = 1 << 1,
    Write = 1 << 2,
    ReadWrite = Read | Write,
}

// Enum usage
const dir: Direction = Direction.Up;
const status: StatusCode = StatusCode.OK;
const color: Color = Color.Red;

// Reverse mapping (numeric enums only)
const dirName: string = Direction[Direction.Up];
