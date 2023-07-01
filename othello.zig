const Coord = @import("coord.zig").Coord;

fn stepIsLegal(position: Coord, offSet: Coord) bool {
    // Take care of left, ...
    if (position.x == 0 and offSet.x == -1) {
        return false;
    }
    // ... right, ...
    if (position.x == 7 and offSet.x == 1) {
        return false;
    }
    // ... upper, ...
    if (position.y == 0 and offSet.y == -1) {
        return false;
    }

    // The step is not illegal, return true.
    return true;
}

const expect = @import("std").testing.expect;

test "stepIsLegal" {
    try expect(!stepIsLegal(Coord{ .x = 0, .y = 0 }, Coord{ .x = -1, .y = 0 }));
    try expect(!stepIsLegal(Coord{ .x = 7, .y = 0 }, Coord{ .x = 1, .y = 0 }));
    try expect(!stepIsLegal(Coord{ .x = 0, .y = 0 }, Coord{ .x = 0, .y = -1 }));
}
