const Othello = @import("othello.zig");
const Board = Othello.Board;
const Cell = Othello.Cell;
const Coord = @import("coord.zig").Coord;
const std = @import("std");
const forceNotNull = @import("force-not-null.zig").forceNotNull;
const Client = @import("client.zig").Client;
const StaticList = @import("static-list.zig").StaticList;
const allPairs = @import("all-pairs.zig").allPairs;

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

    const allBotPairs = try allPairs([]const u8, bots.items, allocator);
    for (allBotPairs.items) |botPair| {
        var resultPathBuffer = [_]u8{undefined} ** 100;
        const resultPath = try std.fmt.bufPrint(&resultPathBuffer, "bot-results/{s}_{s}.txt", .{ botPair[0], botPair[1] });

        var resultFile = std.fs.cwd().createFile(resultPath, .{ .exclusive = true }) catch |e|
            switch (e) {
            error.PathAlreadyExists => {
                std.debug.print("Skipping {s} vs {s}\n", .{ botPair[0], botPair[1] });
                continue;
            },
            else => return e,
        };
        defer resultFile.close();

        std.debug.print("Current Battle: {s} vs {s}\n", .{ botPair[0], botPair[1] });

        var pathBufferA = [_]u8{undefined} ** 100;
        var pathBufferB = [_]u8{undefined} ** 100;
        const pathA = try std.fmt.bufPrint(&pathBufferA, "bots/{?s}", .{botPair[0]});
        const pathB = try std.fmt.bufPrint(&pathBufferB, "bots/{?s}", .{botPair[1]});

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
                    std.debug.print(".", .{});
                    break;
                }

                _ = board.doMove(try (if (board.player == 1) clientA else clientB).requestMove(board));
            }
        }
        std.debug.print("\n", .{});

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

        var resultBuffer = [_]u8{undefined} ** 100;
        const result = try std.fmt.bufPrint(&resultBuffer, "{d} {d}\n", .{ averageScore, standardDeviation });

        std.debug.print("| Average Score: {d:.2} | Stdandard Deviation: {d:.2} |\n", .{ averageScore, standardDeviation });

        _ = try resultFile.write(result);
    }
}
