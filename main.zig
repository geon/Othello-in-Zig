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
    player: i8,
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
    if (player == 1) {
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
    player: i8,
    initialMarkedPosition: Coord,
    legalMoves: StaticList(64, Board.Move),
) !?Board.Move {
    _ = legalMoves;
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
            var move: Board.Move = undefined;
            var legal = try Board.Move.init(&move, board, markedPosition, player);
            if (legal) {
                return move;
            }
        }

        printBoard(board, markedPosition, player);
    }
}

pub fn main() !void {
    var markedPosition: Coord = undefined;
    var match = Match.init();
    var matchState = try match.start();

    {
        // Reset the marked position initially.
        markedPosition = matchState.legalMoves.items[1].position;
    }

    while (true) {
        printBoard(match.board, markedPosition, matchState.player);

        if (matchState.legalMoves.length > 0) {
            var move: ?Board.Move = undefined;
            if (matchState.player == 1) {
                // User input.
                move = try getUserMove(match.board, matchState.player, markedPosition, matchState.legalMoves);
            } else {
                // AI
                move = try match.board.getBestMove(matchState.player);
            }

            if (move) |validMove| {
                matchState = try match.doMove(validMove);
                markedPosition = validMove.position;
            } else {
                break;
            }
        } else {
            printBoard(match.board, markedPosition, matchState.player);
            std.debug.print("  Game Over\n\n", .{});
            break;
        }
    }
}
