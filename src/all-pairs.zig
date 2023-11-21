const std = @import("std");

pub fn allPairs(comptime T: type, values: []const T, allocator: std.mem.Allocator) !std.ArrayList([2]T) {
    var pairs = std.ArrayList([2]T).init(allocator);
    for (values, 0..) |valueA, indexA| {
        for (values[indexA + 1 ..]) |valueB| {
            try pairs.append([2]T{ valueA, valueB });
        }
    }

    return pairs;
}

test "123" {
    const values = [_]u8{ 1, 2, 3, 4, 5 };
    const actualPairs = try allPairs(u8, &values, std.heap.page_allocator);
    const expectedPairs = [_][2]u8{
        [2]u8{ 1, 2 },
        [2]u8{ 1, 3 },
        [2]u8{ 1, 4 },
        [2]u8{ 1, 5 },
        [2]u8{ 2, 3 },
        [2]u8{ 2, 4 },
        [2]u8{ 2, 5 },
        [2]u8{ 3, 4 },
        [2]u8{ 3, 5 },
        [2]u8{ 4, 5 },
    };
    try std.testing.expectEqualDeep(@as([]const [2]u8, &expectedPairs), actualPairs.items);
}
