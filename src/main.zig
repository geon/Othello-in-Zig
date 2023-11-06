const Othello = @import("othello.zig");
const Match = Othello.Match;
const Board = Othello.Board;
const Cell = Othello.Cell;
const Coord = @import("coord.zig").Coord;
const StaticList = @import("static-list.zig").StaticList;
const std = @import("std");

const stdin = std.io.getStdIn().reader();

fn printBoard(
    board: Board,
    markedPosition: Coord,
) void {
    var pl1Count: i8 = 0;
    var pl2Count: i8 = 0;
    for (0..64) |i| {
        if (board.cells[i] == 1) {
            pl1Count += 1;
        } else if (board.cells[i] == -1) {
            pl2Count += 1;
        }
    }

    std.debug.print("\n  Player: ", .{});
    if (board.player == 1) {
        std.debug.print("⚫️", .{});
    } else {
        std.debug.print("⚪️", .{});
    }
    std.debug.print("   ⚫️:{d} ⚪️:{d}", .{ pl1Count, pl2Count });

    // Set style to black on green background.
    const colorOn = "\x1b[30;42m";
    // Reset styles.
    const colorOff = "\x1b[0m";

    std.debug.print("\n  {s}+---+---+---+---+---+---+---+---+{s}\n", .{ colorOn, colorOff });
    for (0..8) |y| {
        std.debug.print("  {s}|", .{colorOn});
        for (0..8) |x| {
            if (board.cells[x + y * 8] == 1) {
                std.debug.print(" ⚫️|", .{});
            } else if (board.cells[x + y * 8] == -1) {
                std.debug.print(" ⚪️|", .{});
            } else {
                std.debug.print("   |", .{});
            }
        }
        std.debug.print("{s}", .{colorOff});
        if (y == markedPosition.y) {
            std.debug.print(" <-", .{});
        }
        std.debug.print("\n  {s}+---+---+---+---+---+---+---+---+{s}\n", .{ colorOn, colorOff });
    }

    for (0..@as(u8, @intCast(markedPosition.x)) + 1) |_| {
        std.debug.print("    ", .{});
    }
    std.debug.print("^\n", .{});
    for (0..@as(u8, @intCast(markedPosition.x)) + 1) |_| {
        std.debug.print("    ", .{});
    }
    std.debug.print("|\n", .{});
}

// Let the user pick a move. Returns null if he/she wants to quit.
fn getUserMove(
    board: Board,
    initialMarkedPosition: Coord,
) !?Board.Move {
    var markedPosition = initialMarkedPosition;

    while (true) {
        const key = try stdin.readByte();

        if (key == 10) {
            // Ignore return key.
        } else if (key == 27 or key == 'q') {
            // 27: [ESC]-key
            return null; // Exit
            // hj/jk and wasd cursor movement.
        } else if ((key == 'h' or key == 'a') and Board.stepIsLegal(markedPosition, Coord{ .x = -1, .y = 0 })) {
            markedPosition = markedPosition.add(Coord{ .x = -1, .y = 0 });
        } else if ((key == 'l' or key == 'd') and Board.stepIsLegal(markedPosition, Coord{ .x = 1, .y = 0 })) {
            markedPosition = markedPosition.add(Coord{ .x = 1, .y = 0 });
        } else if ((key == 'j' or key == 'w') and Board.stepIsLegal(markedPosition, Coord{ .x = 0, .y = -1 })) {
            markedPosition = markedPosition.add(Coord{ .x = 0, .y = -1 });
        } else if ((key == 'k' or key == 's') and Board.stepIsLegal(markedPosition, Coord{ .x = 0, .y = 1 })) {
            markedPosition = markedPosition.add(Coord{ .x = 0, .y = 1 });
        }

        if (key == ' ') {
            var move = Board.Move.init(board, markedPosition, board.player);
            if (move) |validMove| {
                return validMove;
            }
        }

        printBoard(board, markedPosition);
    }
}

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

    var match = Match.init();
    var markedPosition: Coord = match.board.legalMoves.items[1].position;

    while (true) {
        printBoard(match.board, markedPosition);

        if (match.board.gameOver) {
            std.debug.print("  Game Over\n\n", .{});
            break;
        } else {
            const move: ?Board.Move = if (match.board.player == 1)
                // User input.
                try getUserMove(match.board, markedPosition)
            else ai: {
                // AI
                const childStdin = child.stdin.?.writer();
                for (match.board.cells) |cell| {
                    try childStdin.writeByte(@bitCast(cell));
                }
                try childStdin.writeByte(@bitCast(match.board.player));

                const childStdout = child.stdout.?.reader();
                const index = try childStdout.readByte();
                break :ai Board.Move.init(match.board, Coord.fromIndex(@bitCast(index)), match.board.player);
            };

            if (move) |validMove| {
                _ = match.doMove(validMove);
                markedPosition = validMove.position;
            } else {
                break;
            }
        }
    }
}
