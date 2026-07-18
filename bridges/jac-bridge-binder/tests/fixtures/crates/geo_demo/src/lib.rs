//! A purpose-built serde-DTO crate for the wide typed-record lane (FFI-LANES 2.10
//! part 2 / 2.9-followup). An opaque `Canvas` handle whose methods pass derived
//! serde DTOs by value: a flat record, a NESTED record, CONTAINER fields
//! (Vec/Option/Map), and an ENUM with unit + newtype variants. This is the shape
//! real serde crates rarely expose directly but the wide lane is built for.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// A flat scalar/String record (the 2.9 baseline shape).
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Point {
    pub x: i64,
    pub y: i64,
    pub label: String,
}

/// A NESTED record: both fields are another typed record.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Region {
    pub tl: Point,
    pub br: Point,
}

/// CONTAINER fields: a list of nested records, an optional scalar, a string-keyed map.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Path {
    pub pts: Vec<Point>,
    pub name: Option<String>,
    pub weights: HashMap<String, i64>,
}

/// An ENUM: a unit variant, a newtype scalar variant, a newtype nested-record
/// variant, and a newtype String variant.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum Shape {
    Empty,
    Dot(Point),
    Area(Region),
    Tag(String),
}

/// An opaque handle: methods pass the DTOs by value across the wide lane.
pub struct Canvas {
    origin: Point,
}

impl Canvas {
    pub fn new(x: i64, y: i64) -> Canvas {
        Canvas { origin: Point { x, y, label: "origin".to_string() } }
    }

    /// Wide param + wide return, both a NESTED record.
    pub fn translate(&self, r: Region, dx: i64, dy: i64) -> Region {
        Region {
            tl: Point { x: r.tl.x + dx, y: r.tl.y + dy, label: r.tl.label },
            br: Point { x: r.br.x + dx, y: r.br.y + dy, label: r.br.label },
        }
    }

    /// Wide CONTAINER param -> scalar return.
    pub fn trace(&self, p: Path) -> i64 {
        p.pts.len() as i64 + p.weights.values().sum::<i64>()
    }

    /// Wide CONTAINER return.
    pub fn make_path(&self, n: i64) -> Path {
        let pts = (0..n).map(|i| Point { x: i, y: i, label: String::new() }).collect();
        Path { pts, name: None, weights: HashMap::new() }
    }

    /// Wide ENUM param -> String.
    pub fn describe(&self, s: Shape) -> String {
        match s {
            Shape::Empty => "empty".to_string(),
            Shape::Dot(p) => format!("dot@{},{}", p.x, p.y),
            Shape::Area(r) => format!("area {}x{}", r.br.x - r.tl.x, r.br.y - r.tl.y),
            Shape::Tag(t) => t,
        }
    }

    /// Wide ENUM return.
    pub fn origin_shape(&self) -> Shape {
        Shape::Dot(self.origin.clone())
    }

    /// A plain `-> Option<String>` return (M6 nullable-String lane): the `Tag`
    /// variant carries a name, every other shape is anonymous. `None` crosses the
    /// boundary in-band as a null JacBuf pointer, distinct from a present `""`.
    pub fn shape_name(&self, s: Shape) -> Option<String> {
        match s {
            Shape::Tag(t) => Some(t),
            _ => None,
        }
    }

    /// A plain `-> Option<Vec<u8>>` return (M6 nullable-bytes lane): the `Tag`
    /// variant's name as its raw UTF-8 bytes, every other shape is anonymous.
    /// `None` crosses in-band as a null JacBuf pointer, distinct from a present
    /// empty `b""` — the byte analogue of `shape_name`.
    pub fn shape_name_bytes(&self, s: Shape) -> Option<Vec<u8>> {
        match s {
            Shape::Tag(t) => Some(t.into_bytes()),
            _ => None,
        }
    }
}
