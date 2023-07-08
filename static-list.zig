const std = @import("std");

fn StaticList(comptime capacity: usize, comptime T: type) type {
    return struct {
        items: [capacity]T,
        length: usize,

        const Error = error{
            underpop,
            overpush,
        };

        fn init() StaticList(capacity, T) {
            return StaticList(capacity, T){ .items = undefined, .length = 0 };
        }

        fn push(list: *StaticList(capacity, T), value: T) !void {
            if (list.length == list.items.len) {
                return Error.overpush;
            }

            list.items[list.length] = value;

            list.length += 1;
        }

        fn pop(list: *StaticList(capacity, T)) !T {
            if (list.length <= 0) {
                return Error.underpop;
            }

            list.length -= 1;

            return list.items[list.length];
        }
    };
}

const expect = @import("std").testing.expect;
const expectError = @import("std").testing.expectError;

test "Create StaticList" {
    const list = StaticList(2, u8){ .items = [_]u8{ 1, 2 }, .length = 2 };
    try expect(list.items.len == 2);
}

test "Init StaticList" {
    const list = StaticList(2, u8).init();
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
