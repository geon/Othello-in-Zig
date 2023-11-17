const Othello = @import("othello.zig");
const Board = Othello.Board;
const Cell = Othello.Cell;
const Coord = @import("coord.zig").Coord;
const std = @import("std");
const ui = @import("ui.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Find the bot name.
    var args = std.process.args();
    _ = args.skip();
    const botName = args.next();
    var pathBuffer = [_]u8{undefined} ** 100;
    const path = try std.fmt.bufPrint(&pathBuffer, "bots/{?s}", .{botName});

    // Set up bot IPC.
    var child = std.ChildProcess.init(&[_][]const u8{path}, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    defer {
        child.stdin.?.close();
        child.stdin = null;
        child.stdout.?.close();
        child.stdout = null;
        _ = child.wait() catch unreachable;
    }

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
            else ai: {
                // AI
                const childStdin = child.stdin.?.writer();
                for (board.cells) |cell| {
                    try childStdin.writeByte(@bitCast(cell));
                }
                try childStdin.writeByte(@bitCast(board.player));

                const childStdout = child.stdout.?.reader();
                const index = try childStdout.readByte();
                break :ai Board.Move.init(board, Coord.fromIndex(@bitCast(index)), board.player);
            };

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
