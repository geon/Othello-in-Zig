const expect = @import("std").testing.expect;

const Coord = struct {
    x: u8,
    y: u8,
    fn coordsAreEqual(a: Coord, b: Coord) bool {
        return a.x == b.x and a.y == b.y;
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
