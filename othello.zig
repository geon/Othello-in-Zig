const Coord = @import("coord.zig").Coord;
const StaticList = @import("static-list.zig").StaticList;
const std = @import("std");

const Player = i8;
pub const Cell = i8;

pub const Board = struct {
    cells: [64]Cell,

    pub fn init() Board {
        return Board{ .cells = [64]Cell{
            0, 0, 0, 0,  0,  0, 0, 0,
            0, 0, 0, 0,  0,  0, 0, 0,
            0, 0, 0, 0,  0,  0, 0, 0,
            0, 0, 0, -1, 1,  0, 0, 0,
            0, 0, 0, 1,  -1, 0, 0, 0,
            0, 0, 0, 0,  0,  0, 0, 0,
            0, 0, 0, 0,  0,  0, 0, 0,
            0, 0, 0, 0,  0,  0, 0, 0,
        } };
    }

    pub fn stepIsLegal(position: Coord, offSet: Coord) bool {
        // Take care of left, ...
        if (position.x == 0 and offSet.x == -1) {
            return false;
        }
        // ... right, ...
        if (position.x == 7 and offSet.x == 1) {
            return false;
        }
        // ... upper, ...
        if (position.y == 0 and offSet.y == -1) {
            return false;
        }
        // ... and lower edge.
        if (position.y == 7 and offSet.y == 1) {
            return false;
        }

        // The step is not illegal, return true.
        return true;
    }

    // Offsets for the 8 directions. upp-left, upp, upp-right, ..., down-right. The order doesn't really matter.
    const offSets = [8]Coord{
        Coord{ .x = -1, .y = -1 },
        Coord{ .x = 0, .y = -1 },
        Coord{ .x = 1, .y = -1 },
        Coord{ .x = -1, .y = 0 },
        Coord{ .x = 1, .y = 0 },
        Coord{ .x = -1, .y = 1 },
        Coord{ .x = 0, .y = 1 },
        Coord{ .x = 1, .y = 1 },
    };

    pub const Move = struct {
        position: Coord,
        player: Player,
        // 4 possible axies (left/right is shared) and max 6 flipped pieces in each (8 pieces across minus one added piece and at least one end-piece) .
        flips: StaticList(4 * 6, Coord),

        fn flipRow(move: *Move, board: Board, offSet: Coord) !bool {
            const originalLength = move.flips.length;
            var currentPosition = move.position;
            var cell: i8 = 0;
            var numFlips: i8 = 0;
            while (true) {
                if (!stepIsLegal(currentPosition, offSet)) {
                    // Failed to find a complete row, so undo the flipping.
                    try move.flips.shrink(originalLength);
                    return false;
                }

                currentPosition = Coord.add(currentPosition, offSet);
                cell = board.cells[@as(u8, @intCast(Coord.toIndex(currentPosition)))];

                // In rows, the pices belongs to opponent (-player).
                if (cell != -move.player) {
                    if (numFlips > 0 and cell == move.player) {
                        // We have found a comlete row.
                        return true;
                    }

                    // Failed to find a complete row, so undo the flipping.
                    try move.flips.shrink(originalLength);
                    return false;
                }

                // Flip pieces optimistically.
                try move.flips.push(currentPosition);
                numFlips += 1;
            }
        }

        pub fn init(
            move: *Move,
            board: Board,
            position: Coord,
            player: Player,
        ) !bool {
            // We may only put pieces in empty squares.
            if (0 != board.cells[@as(u8, @intCast(Coord.toIndex(position)))]) {
                return false;
            }

            move.position = position;
            move.player = player;
            move.flips.initExisting();

            var legal = false;
            // Test every direction.
            for (offSets) |offSet| {
                if (try move.flipRow(board, offSet)) {
                    // If a row is found in any direction, this move is legal.
                    legal = true;
                }
            }

            return legal;
        }
    };

    pub fn getLegalMoves(
        board: Board,
        player: Player,
        legalMoves: *StaticList(64, Move),
    ) !void {
        const originalLength = legalMoves.items.len;
        _ = originalLength;

        // Loop through all squares to find legal moves and add them to the list.
        for (0..64) |i| {
            const position = Coord.fromIndex(@intCast(i));
            var move = try legalMoves.add();
            if (!try move.init(board, position, player)) {
                // If the move fails to init it is illegal, so remove it.
                _ = try legalMoves.pop();
            }
        }
    }

    pub fn doMove(board: *Board, move: Move) void {
        board.cells[@intCast(move.position.toIndex())] = move.player;
        for (move.flips.items[0..move.flips.length]) |position| {
            board.cells[@intCast(position.toIndex())] = move.player;
        }
    }

    fn undoMove(board: *Board, move: Move) void {
        board.cells[@intCast(move.position.toIndex())] = 0;
        for (move.flips.items[0..move.flips.length]) |position| {
            board.cells[@intCast(position.toIndex())] = -move.player;
        }
    }

    fn pieceBalance(board: Board, player: Player) i32 {
        var score: i32 = 0;

        for (0..64) |i| {
            score += player * board.cells[i];
        }

        return score;
    }

    //  The heuristicScores-values describes how valuable the pieces on these positions are.
    const heuristicScores = [64]i8{
        8,  -4, 6, 4, 4, 6, -4, 8,
        -4, -4, 0, 0, 0, 0, -4, -4,
        6,  0,  2, 2, 2, 2, 0,  6,
        4,  0,  2, 1, 1, 2, 0,  4,
        4,  0,  2, 1, 1, 2, 0,  4,
        6,  0,  2, 2, 2, 2, 0,  6,
        -4, -4, 0, 0, 0, 0, -4, -4,
        8,  -4, 6, 4, 4, 6, -4, 8,
    };

    fn heuristicScore(board: Board, player: Player) i32 {
        var score: i32 = 0;

        // Reward the player with the most weighted pieces.
        for (0..64) |i| {
            score += heuristicScores[i] * player * board.cells[i];
        }

        return score;
    }

    const MoveScore = struct {
        position: Coord,
        score: i32,
    };

    fn getBestScore(scoredMoves: []const MoveScore) i32 {
        var score: i32 = std.math.minInt(i32);
        for (scoredMoves) |entry| {
            if (entry.score > score) {
                score = entry.score;
            }
        }
        return score;
    }

    pub fn getBestMove(
        board: *Board,
        player: Player,
        legalMoves: []const Move,
    ) !Coord {
        var bestScore: i32 = std.math.minInt(i32);
        var bestMove = legalMoves[0].position;

        for (legalMoves) |move| {
            board.doMove(move);

            var legalMovesPlayer = StaticList(64, Move).init();
            try board.getLegalMoves(player, &legalMovesPlayer);

            var legalMovesOpponent = StaticList(64, Move).init();
            try board.getLegalMoves(-player, &legalMovesOpponent);

            const score = (board.heuristicScore(player) +
                @as(i32, @intCast(legalMovesPlayer.length)) -
                @as(i32, @intCast(legalMovesOpponent.length)));

            if (score > bestScore) {
                bestScore = score;
                bestMove = move.position;
            }

            board.undoMove(move);
        }

        return bestMove;
    }
};

const expect = @import("std").testing.expect;
const expectEqual = @import("std").testing.expectEqual;

test "stepIsLegal" {
    try expect(!Board.stepIsLegal(Coord{ .x = 0, .y = 0 }, Coord{ .x = -1, .y = 0 }));
    try expect(!Board.stepIsLegal(Coord{ .x = 7, .y = 0 }, Coord{ .x = 1, .y = 0 }));
    try expect(!Board.stepIsLegal(Coord{ .x = 0, .y = 0 }, Coord{ .x = 0, .y = -1 }));
    try expect(!Board.stepIsLegal(Coord{ .x = 0, .y = 7 }, Coord{ .x = 0, .y = 1 }));
}

test "flipRow" {
    const board = Board.init();

    var move = Board.Move{
        .position = Coord{ .x = 2, .y = 3 },
        .player = 1,
        .flips = undefined,
    };
    move.flips.initExisting();

    try expect(try move.flipRow(board, Coord{ .x = 1, .y = 0 }));
    try expect(1 == move.flips.length);
    try expect(Coord.equal(move.flips.items[0], Coord{ .x = 3, .y = 3 }));
}

test "getLegalMoves" {
    const board = Board.init();

    var moves = StaticList(64, Board.Move).init();
    try board.getLegalMoves(1, &moves);

    try expectEqual(@as(usize, 4), moves.length);
    try expect(Coord.equal(moves.items[0].position, Coord{ .x = 3, .y = 2 }));
    try expect(Coord.equal(moves.items[1].position, Coord{ .x = 2, .y = 3 }));
    try expect(Coord.equal(moves.items[2].position, Coord{ .x = 5, .y = 4 }));
    try expect(Coord.equal(moves.items[3].position, Coord{ .x = 4, .y = 5 }));
}

test "doMove" {
    var board = Board.init();

    var move: Board.Move = undefined;
    _ = try move.init(board, Coord{ .x = 2, .y = 3 }, 1);

    board.doMove(move);

    try expectEqual(@as(i8, 1), board.cells[@as(u8, @intCast((Coord{ .x = 2, .y = 3 }).toIndex()))]);
    try expectEqual(@as(i8, 1), board.cells[@as(u8, @intCast((Coord{ .x = 3, .y = 3 }).toIndex()))]);
}

test "undoMove" {
    var board = Board.init();

    var move: Board.Move = undefined;
    _ = try move.init(board, Coord{ .x = 2, .y = 3 }, 1);

    board.doMove(move);
    board.undoMove(move);

    try expectEqual(@as(i8, 0), board.cells[@as(u8, @intCast((Coord{ .x = 2, .y = 3 }).toIndex()))]);
    try expectEqual(@as(i8, -1), board.cells[@as(u8, @intCast((Coord{ .x = 3, .y = 3 }).toIndex()))]);
}

test "pieceBalance" {
    try expectEqual(@as(i32, 0), (Board{ .cells = [64]Cell{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    } }).pieceBalance(1));

    try expectEqual(@as(i32, 64), (Board{ .cells = [64]Cell{
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
    } }).pieceBalance(1));

    try expectEqual(@as(i32, -64), (Board{ .cells = [64]Cell{
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
    } }).pieceBalance(-1));
}

test "heuristicScore" {
    try expectEqual(@as(i32, 0), (Board{ .cells = [64]Cell{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    } }).heuristicScore(1));

    try expectEqual(@as(i32, 92), (Board{ .cells = [64]Cell{
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
    } }).heuristicScore(1));
}

test "getBestScore" {
    const moveScores = [_]Board.MoveScore{
        Board.MoveScore{ .position = undefined, .score = 1 },
        Board.MoveScore{ .position = undefined, .score = 3 },
        Board.MoveScore{ .position = undefined, .score = 2 },
    };
    try expectEqual(@as(i32, 3), Board.getBestScore(&moveScores));
}
