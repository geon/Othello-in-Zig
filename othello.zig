const Coord = @import("coord.zig").Coord;

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
            }

            stepsMoved += 1;
        }

        return false;
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
}
