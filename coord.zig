const expect = @import("std").testing.expect;
const expectEqual = @import("std").testing.expectEqual;

const Coord = struct {
    x: i8,
    y: i8,
    fn coordsAreEqual(a: Coord, b: Coord) bool {
        return a.x == b.x and a.y == b.y;
    }
    fn add(a: Coord, b: Coord) Coord {
        return Coord{ .x = a.x + b.x, .y = a.y + b.y };
    }
    fn sub(a: Coord, b: Coord) Coord {
        return Coord{ .x = a.x - b.x, .y = a.y - b.y };
    }
    fn toIndex(coord: Coord) i8 {
        return coord.x + coord.y * 8;
    }
};

test "Create Coord" {
    const coord = Coord{ .x = 0, .y = 0 };
    try expect(coord.x == 0);
}

test "Coord equal" {
    const a = Coord{ .x = 0, .y = 0 };
    const b = Coord{ .x = 0, .y = 0 };
    const c = Coord{ .x = 1, .y = 1 };
    try expect(Coord.coordsAreEqual(a, b));
    try expect(!Coord.coordsAreEqual(a, c));
}

test "Add Coord" {
    const a = Coord.add(Coord{ .x = 1, .y = 2 }, Coord{ .x = 3, .y = 4 });
    const b = Coord{ .x = 4, .y = 6 };
    try expect(Coord.coordsAreEqual(a, b));
}

test "Subtract Coord" {
    const a = Coord.sub(Coord{ .x = 1, .y = 2 }, Coord{ .x = 3, .y = 4 });
    const b = Coord{ .x = -2, .y = -2 };
    try expect(Coord.coordsAreEqual(a, b));
}

test "Coord to index" {
    try expectEqual(@as(i8, 0), Coord.toIndex(Coord{ .x = 0, .y = 0 }));
    try expectEqual(@as(i8, 17), Coord.toIndex(Coord{ .x = 1, .y = 2 }));
}
