const expect = @import("std").testing.expect;

const Coord = struct { x: u8, y: u8 };

test "Create Coord" {
    const coord = Coord{ .x = 0, .y = 0 };
    try expect(coord.x == 0);
}
