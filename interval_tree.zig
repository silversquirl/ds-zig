const std = @import("std");
const AvlTree = @import("avl_tree.zig").AvlTree;

/// Stores intervals of [K..K).
/// Context should have the following function:
///
///  pub fn less(Context, a: K, b: K) bool
///     Returns a < b
///
pub fn IntervalTree(comptime K: type, comptime V: type, comptime Context: type) type {
    return struct {
        avl: Tree = .{},

        const Tree = AvlTree(Interval, V, ItContext);
        pub const Node = Tree.Node;

        const Self = @This();

        const Interval = struct {
            start: K,
            end: K,
            max: K = undefined,

            fn overlap(self: Interval, start: K, end: K, ctx: Context) bool {
                return ctx.less(self.start, end) and ctx.less(start, self.end);
            }
        };

        const ItContext = struct {
            ctx: Context,

            pub fn less(ctx: ItContext, a: Interval, b: Interval) bool {
                return ctx.ctx.less(a.start, b.start);
            }

            pub fn balance(ctx: ItContext, node: *Node) void {
                var max = node.key.end;

                if (node.left) |l| {
                    if (ctx.ctx.less(max, l.key.max)) {
                        max = l.key.max;
                    }
                }

                if (node.right) |r| {
                    if (ctx.ctx.less(max, r.key.max)) {
                        max = r.key.max;
                    }
                }

                node.key.max = max;
            }
        };

        /// Return a single node that overlaps with the specified interval
        pub fn findOne(self: Self, start: K, end: K) ?*Node {
            if (@sizeOf(Context) != 0) {
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call findOneContext instead.");
            }
            return self.findOneContext(start, end, undefined);
        }
        pub fn findOneContext(self: Self, start: K, end: K, ctx: Context) ?*Node {
            std.debug.assert(!ctx.less(end, start));

            var node_opt = self.avl.root;
            while (node_opt) |node| {
                if (!ctx.less(start, node.key.max)) {
                    return null;
                }
                if (node.key.overlap(start, end, ctx)) {
                    return node;
                }

                if (node.left != null and ctx.less(start, node.left.?.key.max)) {
                    node_opt = node.left;
                } else {
                    node_opt = node.right;
                }
            }
            return null;
        }

        pub fn add(self: *Self, node: *Node) void {
            self.avl.add(node);
        }
        pub fn addContext(self: *Self, node: *Node, ctx: Context) void {
            self.avl.addContext(node, ctx);
        }

        /// Assert that tree invariants hold.
        /// For debugging purposes.
        pub fn checkIntegrity(self: Self, ctx: Context) void {
            self.avl.checkIntegrity();
            checkNodeIntegrity(self.avl.root, ctx);
        }
        fn checkNodeIntegrity(node_opt: ?*Node, ctx: Context) void {
            const node = node_opt orelse return;
            checkNodeIntegrity(node.left, ctx);
            checkNodeIntegrity(node.right, ctx);

            if (ctx.less(node.key.max, node.key.end)) {
                @panic("Max smaller than node end");
            }

            var max = node.key.end;
            if (node.left) |l| {
                if (ctx.less(node.key.max, l.key.max)) {
                    @panic("Max smaller than left child max");
                }
                if (ctx.less(max, l.key.max)) {
                    max = l.key.max;
                }
            }
            if (node.right) |r| {
                if (ctx.less(node.key.max, r.key.max)) {
                    @panic("Max smaller than right child max");
                }
                if (ctx.less(max, r.key.max)) {
                    max = r.key.max;
                }
            }

            std.debug.assert(!ctx.less(node.key.max, max));
            if (ctx.less(max, node.key.max)) {
                @panic("Max too large");
            }
        }
    };
}

test "insert and find" {
    const Tree = IntervalTree(i32, i64, struct {
        pub fn less(_: @This(), a: i32, b: i32) bool {
            return a < b;
        }
    });

    var tree = Tree{};
    var n0 = Tree.Node{
        .key = .{ .start = 0, .end = 10 },
        .value = 3,
    };
    var n1 = Tree.Node{
        .key = .{ .start = 20, .end = 32 },
        .value = 6,
    };
    var n2 = Tree.Node{
        .key = .{ .start = 7, .end = 15 },
        .value = 1,
    };
    var n3 = Tree.Node{
        .key = .{ .start = 12, .end = 40 },
        .value = 8,
    };
    var n4 = Tree.Node{
        .key = .{ .start = 1000, .end = 1001 },
        .value = 8,
    };

    tree.add(&n0);
    tree.checkIntegrity(.{});
    tree.add(&n1);
    tree.checkIntegrity(.{});
    tree.add(&n2);
    tree.checkIntegrity(.{});
    tree.add(&n3);
    tree.checkIntegrity(.{});
    tree.add(&n4);
    tree.checkIntegrity(.{});

    try std.testing.expectEqual(&n2, tree.avl.root.?);
    try std.testing.expectEqualSlices(?*Tree.Node, &.{
        null, &n0,  &n0,  &n0,
        &n2,  &n2,  &n2,  &n2,
        &n3,  &n3,  &n3,  null,
        &n3,  &n1,  &n1,  &n1,
        &n1,  &n1,  &n1,  &n1,
        null, &n4,  null, &n4,
        null, null, null, null,
    }, &.{
        tree.findOne(0, 0),
        tree.findOne(0, 1),
        tree.findOne(5, 7),
        tree.findOne(7, 7),

        tree.findOne(7, 8),
        tree.findOne(9, 13),
        tree.findOne(12, 100),
        tree.findOne(14, 15),

        tree.findOne(15, 15),
        tree.findOne(32, 32),
        tree.findOne(39, 40),
        tree.findOne(40, 40),
        tree.findOne(20, 20),

        tree.findOne(20, 21),
        tree.findOne(24, 30),
        tree.findOne(31, 32),
        tree.findOne(17, 23),
        tree.findOne(30, 36),
        tree.findOne(31, 33),
        tree.findOne(17, 50),

        tree.findOne(1000, 1000),
        tree.findOne(1000, 1001),
        tree.findOne(1001, 1001),
        tree.findOne(500, 2000),

        tree.findOne(50, 100),
        tree.findOne(500, 1000),
        tree.findOne(1001, 10_000_000),
        tree.findOne(-10, 0),
    });
}
