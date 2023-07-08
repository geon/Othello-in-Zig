fn StaticList(comptime capacity: usize, comptime T: type) type {
    return struct {
        items: [capacity]T,
    };
}

const expect = @import("std").testing.expect;

test "Create StaticList" {
    const list = StaticList(2, u8){ .items = [_]u8{ 1, 2 } };
    try expect(list.items.len == 2);
}
