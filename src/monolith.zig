const Othello = @import("othello.zig");
const Board = Othello.Board;
const Cell = Othello.Cell;
const Coord = @import("coord.zig").Coord;
const std = @import("std");
const ui = @import("ui.zig");

pub fn main() !void {
    var seed: u64 = undefined;
    try std.os.getrandom(std.mem.asBytes(&seed));
    var prngImplementation = std.rand.DefaultPrng.init(seed);
    var prng = prngImplementation.random();

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
                try board.getBestMove(&prng);

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
