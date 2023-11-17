const Board = @import("othello.zig").Board;
const Coord = @import("coord.zig").Coord;
const std = @import("std");
const forceNotNull = @import("force-not-null.zig").forceNotNull;

pub const Client = struct {
    child: std.ChildProcess,

    pub fn init(path: []const u8, allocator: std.mem.Allocator) !Client {
        // Set up bot IPC.
        var child = std.ChildProcess.init(&[_][]const u8{path}, allocator);
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        try child.spawn();

        return Client{
            .child = child,
        };
    }

    pub fn deinit(client: *Client) void {
        client.child.stdin.?.close();
        client.child.stdin = null;
        client.child.stdout.?.close();
        client.child.stdout = null;
        _ = client.child.wait() catch unreachable;
    }

    pub fn requestMove(client: *Client, board: Board) !Board.Move {
        const childStdin = client.child.stdin.?.writer();
        for (board.cells) |cell| {
            try childStdin.writeByte(@bitCast(cell));
        }
        try childStdin.writeByte(@bitCast(board.player));

        const childStdout = client.child.stdout.?.reader();
        const index = try childStdout.readByte();
        return try forceNotNull(Board.Move, Board.Move.init(
            board,
            Coord.fromIndex(@bitCast(index)),
            board.player,
        ));
    }
};
