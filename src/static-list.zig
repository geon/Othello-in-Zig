const std = @import("std");

pub fn StaticList(comptime capacity: usize, comptime T: type) type {
    return struct {
        items: [capacity]T,
        length: usize,

        const Error = error{
            underpop,
            overpush,
            overshrink,
        };

        pub fn init() @This() {
            return @This(){
                .items = undefined,
                .length = 0,
            };
        }

        pub fn push(list: *@This(), value: T) !void {
            if (list.length == list.items.len) {
                return Error.overpush;
            }

            list.items[list.length] = value;

            list.length += 1;
        }

        pub fn pop(list: *@This()) !T {
            if (list.length <= 0) {
                return Error.underpop;
            }

            list.length -= 1;

            return list.items[list.length];
        }

        pub fn shrink(list: *@This(), newLength: usize) !void {
            if (newLength > list.length) {
                return Error.overshrink;
            }

            list.length = newLength;
        }

        pub fn getSlice(list: *const @This()) []const T {
            return list.items[0..list.length];
        }
    };
}

const expect = @import("std").testing.expect;
const expectError = @import("std").testing.expectError;
const expectEqual = @import("std").testing.expectEqual;

test "Create StaticList" {
    const list = StaticList(2, u8){ .items = [_]u8{ 1, 2 }, .length = 2 };
    try expect(list.items.len == 2);
}

test "Init StaticList" {
    const list = StaticList(2, u8).init();
    try expect(list.items.len == 2);
}

test "Init existing StaticList" {
    var list = StaticList(2, u8).init();
    try expect(list.items.len == 2);
}

test "initial length" {
    const list = StaticList(2, u8).init();
    try expect(list.length == 0);
}

test "push increases length" {
    var list = StaticList(2, u8).init();
    try list.push(0);
    try expect(list.length == 1);
    try list.push(0);
    try expect(list.length == 2);
}

test "pop decreases length" {
    var list = StaticList(2, u8).init();
    try list.push(0);
    try expect(list.length == 1);
    _ = try list.pop();
    try expect(list.length == 0);
}

test "pop on empty list is invalid" {
    var list = StaticList(2, u8).init();
    try expectError(StaticList(2, u8).Error.underpop, list.pop());
}

test "pushing beyond capacity is invalid" {
    var list = StaticList(1, u8).init();
    try list.push(0);
    try expectError(StaticList(1, u8).Error.overpush, list.push(0));
}

test "Popping after pushing should return the pushed value." {
    var list = StaticList(1, u8).init();
    try list.push(42);
    try expect(try list.pop() == 42);
}

test "Popping multiple times after pushing should return the pushed values in reverse order." {
    var list = StaticList(3, u8).init();
    try list.push(1);
    try list.push(2);
    try list.push(3);
    try expect(try list.pop() == 3);
    try expect(try list.pop() == 2);
    try expect(try list.pop() == 1);
}

test "Shrinking the list to a larger length is invalid." {
    var list = StaticList(2, u8).init();
    try expectError(
        StaticList(1, u8).Error.overshrink,
        list.shrink(3),
    );
}

test "Shrinking the list discards the items at the end." {
    var list = StaticList(3, u8).init();
    try list.push(1);
    try list.push(2);
    try list.push(3);
    try list.shrink(2);
    try expect(try list.pop() == 2);
    try expect(try list.pop() == 1);
}

test "getSlice should return a slice with the same length and base address." {
    var list = StaticList(1, u8).init();
    var emptySlice = list.getSlice();
    try expectEqual(emptySlice.ptr, &list.items);
    try expectEqual(list.length, emptySlice.len);
    try list.push(0);
    var fullSlice = list.getSlice();
    try expectEqual(list.length, fullSlice.len);
}
