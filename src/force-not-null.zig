const std = @import("std");

const ForceNotNullError = error{ValueIsNull};
pub fn forceNotNull(comptime T: type, value: ?T) !T {
    if (value) |validValue| {
        return validValue;
    }

    return ForceNotNullError.ValueIsNull;
}

test "forceNotNull" {
    const ok: ?i8 = 123;
    try std.testing.expectEqual(@as(i8, 123), try forceNotNull(i8, ok));

    const notOk: ?i8 = undefined;
    try std.testing.expectError(ForceNotNullError.ValueIsNull, forceNotNull(i8, notOk));
}
