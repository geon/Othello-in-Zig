const Othello = @import("othello.zig");
const Board = Othello.Board;
const Cell = Othello.Cell;
const Coord = @import("coord.zig").Coord;
const std = @import("std");
const ui = @import("ui.zig");
const forceNotNull = @import("force-not-null.zig").forceNotNull;
const Client = @import("client.zig").Client;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Find the bot names.
    var args = std.process.args();
    _ = args.skip();
    const botNameA = args.next();
    const botNameB = args.next();
    var pathBufferA = [_]u8{undefined} ** 100;
    var pathBufferB = [_]u8{undefined} ** 100;
    const pathA = try std.fmt.bufPrint(&pathBufferA, "bots/{?s}", .{botNameA});
    const pathB = try std.fmt.bufPrint(&pathBufferB, "bots/{?s}", .{botNameB});

    std.debug.print("{s} {s}", .{ pathA, pathB });

    var clientA = try Client.init(pathA, allocator);
    var clientB = try Client.init(pathB, allocator);
    defer clientA.deinit();
    defer clientB.deinit();

    var board = Board.init();

    while (true) {
        if (board.gameOver) {
            ui.printBoard(board, Coord.fromIndex(0));
            std.debug.print("  Game Over\n\n", .{});
            break;
        }

        _ = board.doMove(try (if (board.player == 1) clientA else clientB).requestMove(board));
    }
}
