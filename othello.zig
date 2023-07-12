const Coord = @import("coord.zig").Coord;
const StaticList = @import("static-list.zig").StaticList;
const std = @import("std");

const Player = i8;
pub const Cell = i8;

pub const Board = struct {
    cells: [64]Cell,

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

    pub fn undoMove(board: *Board, move: Move) void {
        board.cells[@intCast(move.position.toIndex())] = 0;
        for (move.flips.items[0..move.flips.length]) |position| {
            board.cells[@intCast(position.toIndex())] = -move.player;
        }
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

    fn pieceBalance(board: Board, player: Player) i32 {
        var score: i32 = 0;

        for (0..64) |i| {
            score += player * board.cells[i];
        }

        return score;
    }

    const MoveScore = struct {
        position: Coord,
        score: i32,
    };

    fn miniMax(
        board: *Board,
        player: Player,
        legalMoves: StaticList(64, Move),
        searchDepth: u8,
        scores: *StaticList(64, MoveScore),
    ) !void {
        // Try the moves and score them.
        for (legalMoves.items[0..legalMoves.length]) |move| {
            board.doMove(move);
            try scores.push(MoveScore{
                .position = move.position,
                .score = try evaluateBoard(board, player, searchDepth),
            });
            board.undoMove(move);
        }
    }

    fn getBestScore(scoredMoves: StaticList(64, MoveScore)) i32 {
        var score: i32 = std.math.minInt(i32);
        for (scoredMoves.items[0..scoredMoves.length]) |entry| {
            if (entry.score > score) {
                score = entry.score;
            }
        }
        return score;
    }

    fn evaluateBoard(
        board: *Board,
        player: Player,
        searchDepth: u8,
    ) StaticList(64, Move).Error!i32 {
        var legalMovesOpponent = StaticList(64, Move).init();
        try board.getLegalMoves(-player, &legalMovesOpponent);

        if (searchDepth <= 1) {
            // The max depth is reached. Use simple heuristics.
            var legalMovesPlayer = StaticList(64, Move).init();
            try board.getLegalMoves(
                player,
                &legalMovesPlayer,
            );
            return (board.heuristicScore(player) +
                @as(i32, @intCast(legalMovesPlayer.length)) -
                @as(i32, @intCast(legalMovesOpponent.length)));
        }

        if (legalMovesOpponent.length > 0) {
            // Switch player.
            var scores = StaticList(64, MoveScore).init();
            try board.miniMax(-player, legalMovesOpponent, searchDepth - 1, &scores);
            return -getBestScore(scores);
        }

        {
            // The opponent has no legal moves, so don't switch player.
            var legalMovesPlayer = StaticList(64, Move).init();
            try board.getLegalMoves(
                player,
                &legalMovesPlayer,
            );
            if (legalMovesPlayer.length > 0) {
                // The player can move again.
                var scores = StaticList(64, MoveScore).init();
                try board.miniMax(player, legalMovesPlayer, searchDepth - 1, &scores);
                return getBestScore(scores);
            }
        }

        // Noone can move. Game over.

        // Count the pieces.
        const balance = board.pieceBalance(player);
        // Reward the winner.
        if (balance > 0) {
            // TODO:
            // Return high score
            // * plus the piece count, so the AI prioritizes the greatest win, not just any win.
            // * plus the opportunity count, so the AI prioritizes the smartest move, in case the opponent makes a mistake.
            return std.math.maxInt(i32);
        } else if (balance < 0) {
            return std.math.minInt(i32);
        } else {
            return 0;
        }
    }

    pub fn getBestMove(
        board: *Board,
        player: Player,
        legalMoves: StaticList(64, Move),
    ) !Coord {
        // 0 = easy, 1 = normal, 3 = hard, 4 = very hard.
        const searchDepth = 4;

        var scoredMoves = StaticList(64, MoveScore).init();
        try board.miniMax(player, legalMoves, searchDepth, &scoredMoves);

        var bestScore: i32 = std.math.minInt(i32);
        var bestMove = legalMoves.items[0].position;

        for (scoredMoves.items[0..scoredMoves.length]) |scoredMove| {
            if (scoredMove.score > bestScore) {
                bestScore = scoredMove.score;
                bestMove = scoredMove.position;
            }
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
    const board = Board{ .cells = [64]Cell{
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, -1, 1,  0, 0, 0,
        0, 0, 0, 1,  -1, 0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
    } };

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
    const board = Board{ .cells = [64]Cell{
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, -1, 1,  0, 0, 0,
        0, 0, 0, 1,  -1, 0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
    } };

    var moves = StaticList(64, Board.Move).init();
    try board.getLegalMoves(1, &moves);

    try expectEqual(@as(usize, 4), moves.length);
    try expect(Coord.equal(moves.items[0].position, Coord{ .x = 3, .y = 2 }));
    try expect(Coord.equal(moves.items[1].position, Coord{ .x = 2, .y = 3 }));
    try expect(Coord.equal(moves.items[2].position, Coord{ .x = 5, .y = 4 }));
    try expect(Coord.equal(moves.items[3].position, Coord{ .x = 4, .y = 5 }));
}

test "doMove" {
    var board = Board{ .cells = [64]Cell{
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, -1, 1,  0, 0, 0,
        0, 0, 0, 1,  -1, 0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
    } };

    var move: Board.Move = undefined;
    _ = try move.init(board, Coord{ .x = 2, .y = 3 }, 1);

    board.doMove(move);

    try expectEqual(@as(i8, 1), board.cells[@as(u8, @intCast((Coord{ .x = 2, .y = 3 }).toIndex()))]);
    try expectEqual(@as(i8, 1), board.cells[@as(u8, @intCast((Coord{ .x = 3, .y = 3 }).toIndex()))]);
}

test "undoMove" {
    var board = Board{ .cells = [64]Cell{
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, -1, 1,  0, 0, 0,
        0, 0, 0, 1,  -1, 0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
        0, 0, 0, 0,  0,  0, 0, 0,
    } };

    var move: Board.Move = undefined;
    _ = try move.init(board, Coord{ .x = 2, .y = 3 }, 1);

    board.doMove(move);
    board.undoMove(move);

    try expectEqual(@as(i8, 0), board.cells[@as(u8, @intCast((Coord{ .x = 2, .y = 3 }).toIndex()))]);
    try expectEqual(@as(i8, -1), board.cells[@as(u8, @intCast((Coord{ .x = 3, .y = 3 }).toIndex()))]);
}
