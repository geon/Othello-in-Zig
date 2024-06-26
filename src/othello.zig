const Coord = @import("coord.zig").Coord;
const std = @import("std");

const Player = i8;
pub const Cell = i8;

pub const Board = struct {
    cells: [64]Cell,
    player: i8,
    legalMoves: MovesList,
    gameOver: bool,

    pub fn initScenario(cells: [64]Cell, player: Player) Board {
        var board = Board{
            .cells = cells,
            .player = player,
            .legalMoves = undefined,
            .gameOver = false,
        };
        board.legalMoves = board.getLegalMoves(board.player);
        return board;
    }

    pub fn init() Board {
        return Board.initScenario([64]Cell{
            0, 0, 0, 0,  0,  0, 0, 0,
            0, 0, 0, 0,  0,  0, 0, 0,
            0, 0, 0, 0,  0,  0, 0, 0,
            0, 0, 0, -1, 1,  0, 0, 0,
            0, 0, 0, 1,  -1, 0, 0, 0,
            0, 0, 0, 0,  0,  0, 0, 0,
            0, 0, 0, 0,  0,  0, 0, 0,
            0, 0, 0, 0,  0,  0, 0, 0,
        }, 1);
    }

    pub fn equal(a: *Board, b: *Board) bool {
        for (0..64) |index| {
            if (a.cells[index] != b.cells[index]) {
                return false;
            }
        }

        if (a.player != b.player) {
            return false;
        }

        if (a.legalMoves.len != b.legalMoves.len) {
            return false;
        }
        for (a.legalMoves.slice(), b.legalMoves.slice()) |moveA, moveB| {
            if (!Move.equal(&moveA, &moveB)) {
                return false;
            }
        }

        if (a.gameOver != b.gameOver) {
            return false;
        }

        return true;
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

    const FlipList = std.BoundedArray(Coord, 4 * 6);

    pub const Move = struct {
        position: Coord,
        player: Player,
        // 4 possible axies (left/right is shared) and max 6 flipped pieces in each (8 pieces across minus one added piece and at least one end-piece) .
        flips: FlipList,

        pub fn equal(a: *const Move, b: *const Move) bool {
            if (!Coord.equal(a.position, b.position)) {
                return false;
            }

            if (a.player != b.player) {
                return false;
            }

            if (a.flips.len != b.flips.len) {
                return false;
            }
            for (a.flips.slice(), b.flips.slice()) |flipA, flipB| {
                if (!Coord.equal(flipA, flipB)) {
                    return false;
                }
            }

            return true;
        }

        fn flipRow(move: *Move, board: Board, offSet: Coord) !void {
            const originalLength = move.flips.len;
            var currentPosition = move.position;
            var cell: i8 = 0;
            var numFlips: i8 = 0;
            while (true) {
                if (!stepIsLegal(currentPosition, offSet)) {
                    // Failed to find a complete row, so undo the flipping.
                    try move.flips.resize(originalLength);
                    return;
                }

                currentPosition = Coord.add(currentPosition, offSet);
                cell = board.cells[@as(u8, @intCast(Coord.toIndex(currentPosition)))];

                // In rows, the pices belongs to opponent (-player).
                if (cell != -move.player) {
                    if (numFlips > 0 and cell == move.player) {
                        // We have found a comlete row.
                        return;
                    }

                    // Failed to find a complete row, so undo the flipping.
                    try move.flips.resize(originalLength);
                    return;
                }

                // Flip pieces optimistically.
                try move.flips.append(currentPosition);
                numFlips += 1;
            }
        }

        pub fn init(
            board: Board,
            position: Coord,
            player: Player,
        ) ?Move {
            // We may only put pieces in empty squares.
            if (0 != board.cells[@as(u8, @intCast(Coord.toIndex(position)))]) {
                return null;
            }

            var move = Move{
                .position = position,
                .player = player,
                // Can't fail with zero size.
                .flips = FlipList.init(0) catch unreachable,
            };

            // Try flipping in every direction.
            for (offSets) |offSet| {
                // Shoud never fail since the capacity is the max possible number of flips.
                move.flipRow(board, offSet) catch unreachable;
            }

            // If a row is found in any direction, this move is legal.
            return if (move.flips.len > 0) move else null;
        }
    };

    pub const MovesList = std.BoundedArray(Board.Move, 64);

    pub fn getLegalMoves(
        board: Board,
        player: Player,
    ) MovesList {
        // Can't fail with zero len.
        var legalMoves = MovesList.init(0) catch unreachable;

        // Loop through all squares to find legal moves and add them to the list.
        for (0..64) |i| {
            const position = Coord.fromIndex(@intCast(i));
            const move = Move.init(board, position, player);
            if (move) |validMove| {
                // Shoud never fail since the capacity is the same as the board size.
                legalMoves.append(validMove) catch unreachable;
            }
        }

        return legalMoves;
    }

    pub fn doMove(board: *Board, move: Move) Player {
        const lastPlayer = board.player;

        board.cells[@intCast(move.position.toIndex())] = move.player;
        for (move.flips.slice()) |position| {
            board.cells[@intCast(position.toIndex())] = move.player;
        }

        // After making a move, it is the opponent's turn.
        board.player = -board.player;
        board.legalMoves = board.getLegalMoves(board.player);

        // If the opponent can't make a move, the turn goes back to the player.
        if (board.legalMoves.len < 1) {
            board.player = -board.player;
            board.legalMoves = board.getLegalMoves(board.player);

            // If neither player can move, the game is over.
            if (board.legalMoves.len < 1) {
                board.gameOver = true;
            }
        }

        return lastPlayer;
    }

    fn undoMove(board: *Board, move: Move, lastPlayer: Player) void {
        board.cells[@intCast(move.position.toIndex())] = 0;
        for (move.flips.slice()) |position| {
            board.cells[@intCast(position.toIndex())] = -move.player;
        }
        board.player = lastPlayer;
        board.gameOver = false;
        board.legalMoves = board.getLegalMoves(board.player);
    }

    pub fn pieceBalance(board: Board, player: Player) i32 {
        var score: i32 = 0;

        for (0..64) |i| {
            score += board.cells[i];
        }

        return player * score;
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

    fn evaluateMove(
        board: *Board,
        move: Board.Move,
        depth: u8,
    ) i32 {
        const lastPlayer = board.doMove(move);
        defer board.undoMove(move, lastPlayer);

        if (board.gameOver) {
            const balance = board.pieceBalance(board.player);
            return if (balance > 0)
                std.math.maxInt(i32)
            else
                // Not +std.math.minInt(i32), since that would be one less.
                -std.math.maxInt(i32);
        }

        if (depth > 0) {
            var maxScore: i32 = std.math.minInt(i32);
            for (board.legalMoves.slice()) |innerMove| {
                const score = board.evaluateMove(innerMove, depth - 1);
                if (score > maxScore) {
                    maxScore = score;
                }
            }

            return if (board.player == lastPlayer) maxScore else -maxScore;
        }

        const legalMovesPlayer = board.getLegalMoves(move.player);

        const legalMovesOpponent = board.getLegalMoves(-move.player);

        return board.heuristicScore(move.player) +
            @as(i32, @intCast(legalMovesPlayer.len)) -
            @as(i32, @intCast(legalMovesOpponent.len));
    }

    pub fn getBestMove(
        board: *Board,
        prng: *std.rand.Random,
    ) !?Board.Move {
        if (board.legalMoves.len == 0) {
            return null;
        }

        var bestScore: i32 = std.math.minInt(i32);
        var bestMoves = MovesList.init(0) catch unreachable;

        for (board.legalMoves.slice()) |move| {
            const score = board.evaluateMove(move, 3);

            if (score == bestScore) {
                try bestMoves.append(move);
            }

            if (score > bestScore) {
                bestScore = score;
                try bestMoves.resize(0);
                try bestMoves.append(move);
            }
        }

        return bestMoves.buffer[prng.uintLessThan(usize, bestMoves.len)];
    }
};

const expect = @import("std").testing.expect;
const expectEqual = @import("std").testing.expectEqual;
const forceNotNull = @import("force-not-null.zig").forceNotNull;

test "stepIsLegal" {
    try expect(!Board.stepIsLegal(Coord{ .x = 0, .y = 0 }, Coord{ .x = -1, .y = 0 }));
    try expect(!Board.stepIsLegal(Coord{ .x = 7, .y = 0 }, Coord{ .x = 1, .y = 0 }));
    try expect(!Board.stepIsLegal(Coord{ .x = 0, .y = 0 }, Coord{ .x = 0, .y = -1 }));
    try expect(!Board.stepIsLegal(Coord{ .x = 0, .y = 7 }, Coord{ .x = 0, .y = 1 }));
}

test "move equal" {
    const board = Board.init();

    const a = try forceNotNull(Board.Move, Board.Move.init(board, Coord{ .x = 2, .y = 3 }, 1));
    const b = try forceNotNull(Board.Move, Board.Move.init(board, Coord{ .x = 2, .y = 3 }, 1));
    const c = try forceNotNull(Board.Move, Board.Move.init(board, Coord{ .x = 3, .y = 2 }, 1));

    try expect(Board.Move.equal(&a, &b));
    try expect(!Board.Move.equal(&a, &c));
}

test "flipRow" {
    const board = Board.init();

    var move = try forceNotNull(Board.Move, Board.Move.init(
        board,
        Coord{ .x = 2, .y = 3 },
        1,
    ));

    try expect(1 == move.flips.len);
    try expect(Coord.equal(move.flips.buffer[0], Coord{ .x = 3, .y = 3 }));
}

test "board equal" {
    var a = Board.init();
    var b = Board.init();
    var c = Board.init();
    _ = c.doMove(c.legalMoves.buffer[0]);

    try expect(Board.equal(&a, &b));
    try expect(!Board.equal(&a, &c));
}

test "getLegalMoves" {
    const board = Board.init();

    const moves = board.getLegalMoves(1);

    try expectEqual(@as(usize, 4), moves.len);
    try expect(Coord.equal(moves.buffer[0].position, Coord{ .x = 3, .y = 2 }));
    try expect(Coord.equal(moves.buffer[1].position, Coord{ .x = 2, .y = 3 }));
    try expect(Coord.equal(moves.buffer[2].position, Coord{ .x = 5, .y = 4 }));
    try expect(Coord.equal(moves.buffer[3].position, Coord{ .x = 4, .y = 5 }));
}

test "doMove" {
    var board = Board.init();

    var move = Board.Move.init(board, Coord{ .x = 2, .y = 3 }, 1);
    if (move) |validMove| {
        _ = board.doMove(validMove);
    }

    try expectEqual(@as(i8, 1), board.cells[@as(u8, @intCast((Coord{ .x = 2, .y = 3 }).toIndex()))]);
    try expectEqual(@as(i8, 1), board.cells[@as(u8, @intCast((Coord{ .x = 3, .y = 3 }).toIndex()))]);
    try expectEqual(@as(i8, -1), board.player);
}

test "undoMove" {
    var board = Board.init();

    var move = Board.Move.init(board, Coord{ .x = 2, .y = 3 }, 1);
    if (move) |validMove| {
        const lastPlayer = board.doMove(validMove);
        board.undoMove(validMove, lastPlayer);
    } else {
        return error{NoMove}.NoMove;
    }

    var newBoard = Board.init();
    try expect(Board.equal(&board, &newBoard));
}

test "undoMove twice" {
    var board = Board.init();

    const move = board.legalMoves.buffer[0];
    const lastPlayer = board.doMove(move);

    const move2 = board.legalMoves.buffer[0];
    const lastPlayer2 = board.doMove(move2);

    board.undoMove(move2, lastPlayer2);

    board.undoMove(move, lastPlayer);

    var newBoard = Board.init();
    try expect(Board.equal(&board, &newBoard));
}

test "pieceBalance" {
    try expectEqual(@as(i32, 0), Board.initScenario([64]Cell{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    }, 1).pieceBalance(1));

    try expectEqual(@as(i32, 64), Board.initScenario([64]Cell{
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
    }, 1).pieceBalance(1));

    try expectEqual(@as(i32, -64), Board.initScenario([64]Cell{
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
    }, 1).pieceBalance(-1));
}

test "heuristicScore" {
    try expectEqual(@as(i32, 0), Board.initScenario([64]Cell{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    }, 1).heuristicScore(1));

    try expectEqual(@as(i32, 92), Board.initScenario([64]Cell{
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
    }, 1).heuristicScore(1));
}

test "legal moves" {
    var board = Board.initScenario([64]Cell{
        0, 0, 0,  0,  0,  0, 0, 0,
        0, 0, 0,  0,  0,  0, 0, 0,
        0, 0, 1,  -1, 0,  0, 0, 0,
        0, 0, -1, -1, -1, 0, 0, 0,
        0, 0, 0,  -1, 1,  0, 0, 0,
        0, 0, 0,  0,  0,  0, 0, 0,
        0, 0, 0,  0,  0,  0, 0, 0,
        0, 0, 0,  0,  0,  0, 0, 0,
    }, 1);

    try expectEqual(@as(usize, 2), board.legalMoves.len);
    try expectEqual(Coord{ .x = 4, .y = 2 }, board.legalMoves.buffer[0].position);
    try expectEqual(@as(Player, 1), board.legalMoves.buffer[0].player);
    try expectEqual(@as(usize, 2), board.legalMoves.buffer[0].flips.len);
    try expectEqual(Coord{ .x = 3, .y = 2 }, board.legalMoves.buffer[0].flips.buffer[0]);
    try expectEqual(Coord{ .x = 4, .y = 3 }, board.legalMoves.buffer[0].flips.buffer[1]);

    try expectEqual(Coord{ .x = 2, .y = 4 }, board.legalMoves.buffer[1].position);
    try expectEqual(@as(Player, 1), board.legalMoves.buffer[1].player);
    try expectEqual(@as(Player, 1), board.legalMoves.buffer[1].player);
    try expectEqual(@as(usize, 2), board.legalMoves.buffer[1].flips.len);
    try expectEqual(Coord{ .x = 2, .y = 3 }, board.legalMoves.buffer[1].flips.buffer[0]);
    try expectEqual(Coord{ .x = 3, .y = 4 }, board.legalMoves.buffer[1].flips.buffer[1]);
}

test "skip player" {
    var board = Board.initScenario([64]Cell{
        1,  0, 0, 0, 0, 0, 0, 1,
        -1, 0, 0, 0, 0, 0, 0, -1,
        0,  0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0, 0, 0, 0,
    }, 1);

    try expectEqual(@as(Player, 1), board.player);
    try expectEqual(@as(usize, 2), board.legalMoves.len);

    const move1 = board.legalMoves.buffer[0];
    const undo1 = board.doMove(move1);

    try expectEqual(@as(Player, 1), board.player);
    try expectEqual(@as(usize, 1), board.legalMoves.len);

    const move2 = board.legalMoves.buffer[0];
    const undo2 = board.doMove(move2);

    try expectEqual(true, board.gameOver);
    try expectEqual(@as(usize, 0), board.legalMoves.len);

    board.undoMove(move2, undo2);
    board.undoMove(move1, undo1);

    var newBoard = Board.initScenario([64]Cell{
        1,  0, 0, 0, 0, 0, 0, 1,
        -1, 0, 0, 0, 0, 0, 0, -1,
        0,  0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0, 0, 0, 0,
    }, 1);
    try expect(Board.equal(&board, &newBoard));
}
