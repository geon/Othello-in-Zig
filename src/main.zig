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

    // Find the bot name.
    var args = std.process.args();
    _ = args.skip();
    const botName = args.next();
    var pathBuffer = [_]u8{undefined} ** 100;
    const path = try std.fmt.bufPrint(&pathBuffer, "bots/{?s}", .{botName});

    var client = try Client.init(path, allocator);
    defer client.deinit();

    var board = Board.init();
    var markedPosition: Coord = board.legalMoves.items[1].position;

    while (true) {
        ui.printBoard(board, markedPosition);

        if (board.gameOver) {
            std.debug.print("  Game Over\n\n", .{});
            break;
        } else {
            const move: ?Board.Move = if (board.player == 1)
                // User input.
                try ui.getUserMove(board, markedPosition)
            else
                // AI
                try client.requestMove(board);

            if (move) |validMove| {
                _ = board.doMove(validMove);
                if (board.legalMoves.length > 0) {
                    markedPosition = board.legalMoves.items[0].position;
                }
            } else {
                break;
            }
        }
    }
}
