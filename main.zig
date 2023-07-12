const Othello = @import("othello.zig");
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
        std.debug.print("X", .{});
    } else {
        std.debug.print("O", .{});
    }
    std.debug.print("   X:{d} O:{d}", .{ pl1Count, pl2Count });

    std.debug.print("\n  +-+-+-+-+-+-+-+-+\n", .{});
    for (0..8) |y| {
        std.debug.print("  |", .{});
        for (0..8) |x| {
            if (board.cells[x + y * 8] == 1) {
                std.debug.print("X|", .{});
            } else if (board.cells[x + y * 8] == -1) {
                std.debug.print("O|", .{});
            } else {
                std.debug.print(" |", .{});
            }
        }
        if (y == markedPosition.y) {
            std.debug.print(" <-", .{});
        }
        std.debug.print("\n  +-+-+-+-+-+-+-+-+\n", .{});
    }

    for (0..@as(u8, @intCast(markedPosition.x)) + 1) |_| {
        std.debug.print("  ", .{});
    }
    std.debug.print(" ^\n", .{});
    for (0..@as(u8, @intCast(markedPosition.x)) + 1) |_| {
        std.debug.print("  ", .{});
    }
    std.debug.print(" |\n", .{});
}

// Let the user pick a move. Returns null if he/she wants to quit.
fn getUserMove(
    board: Board,
    player: i8,
    initialMarkedPosition: Coord,
) !?Coord {
    var markedPosition = initialMarkedPosition;

    while (true) {
        printBoard(board, markedPosition, player);

        const key = try stdin.readByte();

        if (key == 10) {
            // Ignore return key.
        } else if (key == 27) {
            return null; // [ESC]-key
        } else if (key == 'h' and Board.stepIsLegal(markedPosition, Coord{ .x = -1, .y = 0 })) {
            markedPosition = markedPosition.add(Coord{ .x = -1, .y = 0 });
        } else if (key == 'l' and Board.stepIsLegal(markedPosition, Coord{ .x = 1, .y = 0 })) {
            markedPosition = markedPosition.add(Coord{ .x = 1, .y = 0 });
        } else if (key == 'j' and Board.stepIsLegal(markedPosition, Coord{ .x = 0, .y = -1 })) {
            markedPosition = markedPosition.add(Coord{ .x = 0, .y = -1 });
        } else if (key == 'k' and Board.stepIsLegal(markedPosition, Coord{ .x = 0, .y = 1 })) {
            markedPosition = markedPosition.add(Coord{ .x = 0, .y = 1 });
        }

        if (key == ' ') {
            std.debug.print("returning\n", .{});
            return markedPosition;
        }
    }
}

pub fn main() !void {
    var player: i8 = 1;
    var markedPosition: Coord = undefined;
    //    var userMove;
    //    var moveList[64];
    var board = Board.init();

    {
        // Reset the marked position initially.
        var legalMoves = StaticList(64, Board.Move).init();
        try board.getLegalMoves(player, &legalMoves);
        markedPosition = legalMoves.items[1].position;
    }

    while (true) {
        var legalMoves = StaticList(64, Board.Move).init();
        try board.getLegalMoves(player, &legalMoves);

        if (legalMoves.length > 0) {
            if (player == 1) {
                // User input.
                // markedPosition = legalMoves.items[1].position;
                const userMove = try getUserMove(board, player, markedPosition);
                if (userMove == null) {
                    break;
                }

                if (userMove) |innerUserMove| {
                    var move: Board.Move = undefined;
                    _ = try Board.Move.init(
                        &move,
                        board,
                        innerUserMove,
                        1,
                    );
                    board.doMove(move);
                    printBoard(board, innerUserMove, player);
                    player = -player;
                }
            } else {
                // AI
                markedPosition = try board.getBestMove(player, legalMoves.items[0..legalMoves.length]);
                var move: Board.Move = undefined;
                _ = try Board.Move.init(
                    &move,
                    board,
                    markedPosition,
                    -1,
                );
                board.doMove(move);
                player = -player;
            }
        } else {
            player = -player;
            var legalMoves2 = StaticList(64, Board.Move).init();
            try board.getLegalMoves(player, &legalMoves2);
            if (legalMoves2.length == 0) {
                std.debug.print("  Game Over\n\n", .{});
                break;
            }
        }
    }
}
