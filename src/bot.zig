const Othello = @import("othello.zig");
const Board = Othello.Board;
const std = @import("std");

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    while (true) {
        var board = Board.init();

        // Read board and player from stdin.
        for (&board.cells) |*cell| {
            cell.* = readCell: {
                const byte = try stdin.readByte();
                break :readCell @bitCast(byte);
            };
        }
        const player = readPlayer: {
            const byte = try stdin.readByte();
            break :readPlayer @as(i8, @bitCast(byte));
        };

        // AI
        const move = try board.getBestMove(player);

        if (move) |validMove| {
            // Send the move coord index back.
            try stdout.writeByte(@bitCast(validMove.position.toIndex()));
        } else {
            return (error{InvalidMove}).InvalidMove;
        }
    }
}
