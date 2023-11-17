const Othello = @import("othello.zig");
const Board = Othello.Board;
const std = @import("std");

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    var seed: u64 = undefined;
    try std.os.getrandom(std.mem.asBytes(&seed));
    var prngImplementation = std.rand.DefaultPrng.init(seed);
    var prng = prngImplementation.random();

    while (true) {
        // Read board and player from stdin.
        var cells: [64]i8 = undefined;
        for (&cells) |*cell| {
            cell.* = readCell: {
                const byte = try stdin.readByte();
                break :readCell @bitCast(byte);
            };
        }
        const player = readPlayer: {
            const byte = try stdin.readByte();
            break :readPlayer @as(i8, @bitCast(byte));
        };

        var board = Board.initScenario(cells, player);

        // AI
        const move = try board.getBestMove(&prng);

        if (move) |validMove| {
            // Send the move coord index back.
            try stdout.writeByte(@bitCast(validMove.position.toIndex()));
        } else {
            return (error{InvalidMove}).InvalidMove;
        }
    }
}
