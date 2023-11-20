const Othello = @import("othello.zig");
const Board = Othello.Board;
const Cell = Othello.Cell;
const Coord = @import("coord.zig").Coord;
const std = @import("std");
const forceNotNull = @import("force-not-null.zig").forceNotNull;
const Client = @import("client.zig").Client;
const StaticList = @import("static-list.zig").StaticList;

fn compareStrings(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.order(u8, lhs, rhs).compare(std.math.CompareOperator.lt);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Find the bot names.
    var botsDir = try std.fs.cwd().openIterableDir("bots", .{});
    defer botsDir.close();
    var dirIterator = botsDir.iterate();
    var bots = std.ArrayList([]const u8).init(allocator);
    while (try dirIterator.next()) |bot| {
        try bots.append(bot.name);
    }

    std.sort.insertion([]const u8, bots.items, {}, compareStrings);

    const botNameA = bots.items[0];
    const botNameB = bots.items[1];

    var pathBufferA = [_]u8{undefined} ** 100;
    var pathBufferB = [_]u8{undefined} ** 100;
    const pathA = try std.fmt.bufPrint(&pathBufferA, "bots/{?s}", .{botNameA});
    const pathB = try std.fmt.bufPrint(&pathBufferB, "bots/{?s}", .{botNameB});

    var clientA = try Client.init(pathA, allocator);
    var clientB = try Client.init(pathB, allocator);
    defer clientA.deinit();
    defer clientB.deinit();

    const numMatches = 100;
    var scores = StaticList(numMatches, i32).init();

    for (0..numMatches) |_| {
        var board = Board.init();
        while (true) {
            if (board.gameOver) {
                try scores.push(board.pieceBalance(1));
                break;
            }

            _ = board.doMove(try (if (board.player == 1) clientA else clientB).requestMove(board));
        }
    }

    var sumScore: f32 = 0;
    for (scores.getSlice()) |score| {
        sumScore += @floatFromInt(score);
    }
    const averageScore = sumScore / numMatches;
    var sumSquaredDeviation: f32 = 0;
    for (scores.items[0..scores.length]) |score| {
        sumSquaredDeviation += std.math.pow(f32, @as(f32, @floatFromInt(score)) - averageScore, 2);
    }
    const standardDeviation = std.math.sqrt(sumSquaredDeviation / numMatches);
    std.debug.print("{d} {d}\n", .{ averageScore, standardDeviation });
}
