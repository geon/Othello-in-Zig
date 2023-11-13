const Othello = @import("othello.zig");
const Board = Othello.Board;
const Cell = Othello.Cell;
const Coord = @import("coord.zig").Coord;
const std = @import("std");
const ui = @import("ui.zig");

pub fn main() !void {
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
                try board.getBestMove();

            if (move) |validMove| {
                _ = board.doMove(validMove);
                markedPosition = validMove.position;
            } else {
                break;
            }
        }
    }
}