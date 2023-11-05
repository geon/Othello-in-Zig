pub const Coord = struct {
    x: i8,
    y: i8,
    pub fn equal(a: Coord, b: Coord) bool {
        return a.x == b.x and a.y == b.y;
    }
    pub fn add(a: Coord, b: Coord) Coord {
        return Coord{ .x = a.x + b.x, .y = a.y + b.y };
    }
    pub fn sub(a: Coord, b: Coord) Coord {
        return Coord{ .x = a.x - b.x, .y = a.y - b.y };
    }
    pub fn toIndex(coord: Coord) i8 {
        return coord.x + coord.y * 8;
    }
    pub fn fromIndex(index: i8) Coord {
        return Coord{ .x = @mod(index, 8), .y = @divTrunc(index, 8) };
    }
};

const expect = @import("std").testing.expect;
const expectEqual = @import("std").testing.expectEqual;

test "Create Coord" {
    const coord = Coord{ .x = 0, .y = 0 };
    try expect(coord.x == 0);
}

test "Coord equal" {
    const a = Coord{ .x = 0, .y = 0 };
    const b = Coord{ .x = 0, .y = 0 };
    const c = Coord{ .x = 1, .y = 1 };
    try expect(Coord.equal(a, b));
    try expect(!Coord.equal(a, c));
}

test "Add Coord" {
    const a = Coord.add(Coord{ .x = 1, .y = 2 }, Coord{ .x = 3, .y = 4 });
    const b = Coord{ .x = 4, .y = 6 };
    try expect(Coord.equal(a, b));
}

test "Subtract Coord" {
    const a = Coord.sub(Coord{ .x = 1, .y = 2 }, Coord{ .x = 3, .y = 4 });
    const b = Coord{ .x = -2, .y = -2 };
    try expect(Coord.equal(a, b));
}

test "Coord to index" {
    try expectEqual(@as(i8, 0), Coord.toIndex(Coord{ .x = 0, .y = 0 }));
    try expectEqual(@as(i8, 17), Coord.toIndex(Coord{ .x = 1, .y = 2 }));
}

test "Coord from index" {
    try expectEqual(Coord.fromIndex(0), Coord{ .x = 0, .y = 0 });
    try expectEqual(Coord.fromIndex(17), Coord{ .x = 1, .y = 2 });
}
