fn StaticList(comptime capacity: usize, comptime T: type) type {
    return struct {
        items: [capacity]T,

        fn init() StaticList(capacity, T) {
            return StaticList(capacity, T){ .items = undefined };
        }
    };
}

const expect = @import("std").testing.expect;

test "Create StaticList" {
    const list = StaticList(2, u8){ .items = [_]u8{ 1, 2 } };
    try expect(list.items.len == 2);
}

test "Init StaticList" {
    const list = StaticList(2, u8).init();
    try expect(list.items.len == 2);
}
