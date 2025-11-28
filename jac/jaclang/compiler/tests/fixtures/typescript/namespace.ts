// Namespace TypeScript fixture

namespace Geometry {
    export interface Point {
        x: number;
        y: number;
    }

    export function distance(p1: Point, p2: Point): number {
        const dx = p2.x - p1.x;
        const dy = p2.y - p1.y;
        return Math.sqrt(dx * dx + dy * dy);
    }

    export class Circle {
        center: Point;
        radius: number;

        constructor(center: Point, radius: number) {
            this.center = center;
            this.radius = radius;
        }

        area(): number {
            return Math.PI * this.radius * this.radius;
        }
    }

    // Nested namespace
    export namespace ThreeD {
        export interface Point3D extends Point {
            z: number;
        }

        export function distance3D(p1: Point3D, p2: Point3D): number {
            const dx = p2.x - p1.x;
            const dy = p2.y - p1.y;
            const dz = p2.z - p1.z;
            return Math.sqrt(dx * dx + dy * dy + dz * dz);
        }
    }
}

// Module syntax (alternative to namespace)
module Validation {
    export interface StringValidator {
        isValid(s: string): boolean;
    }

    export class EmailValidator implements StringValidator {
        isValid(s: string): boolean {
            return s.includes("@");
        }
    }
}

// Usage - calling functions
const dist = Geometry.distance(null, null);
const isValid = true;
