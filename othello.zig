const Coord = @import("coord.zig").Coord;
const std = @import("std");

const Player = i8;
const Cell = i8;

const Board = struct {
    cells: [64]Cell,

    const RowIterator = struct {
        board: *const Board,
        position: Coord,
        offSet: Coord,

        fn stepIsLegal(position: Coord, offSet: Coord) bool {
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

        pub fn next(self: *RowIterator) ?Cell {
            // Take a step in the direction as long as it is legal (we may not step out of the board).
            if (!stepIsLegal(self.position, self.offSet)) return null;
            self.position = Coord.add(self.position, self.offSet);
            return self.board.cells[@as(u8, @intCast(self.position.toIndex()))];
        }
    };

    fn iterateRow(board: Board, position: Coord, offSet: Coord) RowIterator {
        return RowIterator{ .board = &board, .position = position, .offSet = offSet };
    }

    fn rowExists(board: Board, position: Coord, offSet: Coord, player: Player) bool {
        var iterator = board.iterateRow(position, offSet);
        var stepsMoved: i8 = 0;

        while (iterator.next()) |cell| {
            // In rows, the pices belongs to opponent (-player).
            if (cell != -player) {
                if (stepsMoved > 0 and cell == player) {
                    // We have found a comlete row.
                    return true;
                }

                return false;
            }

            stepsMoved += 1;
        }

        return false;
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

    fn moveIsLegal(
        board: Board,
        position: Coord,
        player: Player,
    ) bool {
        // We may only put pieces in empty squares.
        if (0 != board.cells[@as(u8, @intCast(Coord.toIndex(position)))]) {
            return false;
        }

        // Test every direction.
        for (offSets) |offSet| {
            if (board.rowExists(position, offSet, player)) {
                return true;
            }
        }

        // If no legal move is found in either direction, this move is illegal.
        return false;
    }

    fn getLegalMoves(
        board: Board,
        player: Player,
    ) !std.ArrayList(Coord) {
        // Loop through all squares to find legal moves and add them to the list.
        var legalMoves = std.ArrayList(Coord).init(std.heap.page_allocator);
        for (0..63) |i| {
            const position = Coord.fromIndex(@intCast(i));
            if (board.moveIsLegal(position, player)) {
                try legalMoves.append(position);
            }
        }

        return legalMoves;
    }
};

const expect = @import("std").testing.expect;
const expectEqual = @import("std").testing.expectEqual;

test "stepIsLegal" {
    try expect(!Board.RowIterator.stepIsLegal(Coord{ .x = 0, .y = 0 }, Coord{ .x = -1, .y = 0 }));
    try expect(!Board.RowIterator.stepIsLegal(Coord{ .x = 7, .y = 0 }, Coord{ .x = 1, .y = 0 }));
    try expect(!Board.RowIterator.stepIsLegal(Coord{ .x = 0, .y = 0 }, Coord{ .x = 0, .y = -1 }));
    try expect(!Board.RowIterator.stepIsLegal(Coord{ .x = 0, .y = 7 }, Coord{ .x = 0, .y = 1 }));
}

test "iterateRow" {
    const board = Board{ .cells = [64]Cell{
        0, 0, 0, 0, 0, 0,  0, 0,
        0, 0, 0, 0, 0, -1, 1, 0,
        0, 0, 0, 0, 0, 0,  0, 0,
        0, 0, 0, 0, 0, 0,  0, 0,
        0, 0, 0, 0, 0, 0,  0, 0,
        0, 0, 0, 0, 0, 0,  0, 0,
        0, 0, 0, 0, 0, 0,  0, 0,
        0, 0, 0, 0, 0, 0,  0, 0,
    } };
    var iterator = board.iterateRow(Coord{ .x = 4, .y = 1 }, Coord{ .x = 1, .y = 0 });

    const a = iterator.next();
    const b = iterator.next();
    const c = iterator.next();
    const d = iterator.next();

    try expectEqual(@as(?i8, -1), a);
    try expectEqual(@as(?i8, 1), b);
    try expectEqual(@as(?i8, 0), c);
    try expectEqual(@as(?i8, null), d);
}

test "rowExists" {
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
    try expect(!board.rowExists(Coord{ .x = 0, .y = 0 }, Coord{ .x = 1, .y = 0 }, 1));
    try expect(board.rowExists(Coord{ .x = 2, .y = 3 }, Coord{ .x = 1, .y = 0 }, 1));
    try expect(!board.rowExists(Coord{ .x = 0, .y = 3 }, Coord{ .x = 1, .y = 0 }, 1));
}

test "moveIsLegal" {
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
    try expect(!board.moveIsLegal(Coord{ .x = 0, .y = 0 }, 1));
    try expect(!board.moveIsLegal(Coord{ .x = 3, .y = 3 }, 1));
    try expect(board.moveIsLegal(Coord{ .x = 2, .y = 3 }, 1));
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
    const moves = try board.getLegalMoves(1);
    defer moves.deinit();

    try expectEqual(@as(usize, 4), moves.items.len);
    try expect(Coord.equal(moves.items[0], Coord{ .x = 3, .y = 2 }));
    try expect(Coord.equal(moves.items[1], Coord{ .x = 2, .y = 3 }));
    try expect(Coord.equal(moves.items[2], Coord{ .x = 5, .y = 4 }));
    try expect(Coord.equal(moves.items[3], Coord{ .x = 4, .y = 5 }));
}
