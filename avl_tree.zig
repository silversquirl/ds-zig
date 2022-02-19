const std = @import("std");

/// Context can contain any of the following functions, and must contain at least `less`:
///
///  pub fn less(Context, a: K, b: K) bool
///     Returns a < b
///  pub fn balance(Context, node: *Node) void
///     Called whenever node's children change.
///     Useful for implementing more complex tree datastructures on top of the AVL tree.
///
pub fn AvlTree(
    comptime K: type,
    comptime V: type,
    comptime Context: type,
) type {
    return struct {
        root: ?*Node = null,

        pub const Node = struct {
            key: K,
            value: V,

            balance: i2 = 0,
            left: ?*Node = null,
            right: ?*Node = null,

            pub fn kv(self: Node) KV {
                return .{ .key = self.key, .value = self.value };
            }
        };
        const Self = @This();

        pub fn buildArrayList(self: *Self, list: *std.ArrayList(KV)) !void {
            try buildArrayListInternal(self.root, list);
        }
        fn buildArrayListInternal(node_opt: ?*Node, list: *std.ArrayList(KV)) std.mem.Allocator.Error!void {
            if (node_opt) |node| {
                try buildArrayListInternal(node.left, list);
                try list.append(node.kv());
                try buildArrayListInternal(node.right, list);
            }
        }
        pub const KV = struct { key: K, value: V };

        pub fn find(self: Self, key: K) ?*Node {
            if (@sizeOf(Context) != 0) {
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call findContext instead.");
            }
            self.findContext(key, undefined);
        }
        pub fn findContext(self: Self, key: K, ctx: Context) ?*Node {
            var node_opt = self.root;
            while (node_opt) |node| {
                if (ctx.less(key, node)) {
                    node_opt = node.left;
                } else if (ctx.less(node, key)) {
                    node_opt = node.right;
                } else {
                    return node;
                }
            }
            return null;
        }

        pub fn add(self: *Self, node: *Node) void {
            if (@sizeOf(Context) != 0) {
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call addContext instead.");
            }
            self.addContext(node, undefined);
        }
        pub fn addContext(self: *Self, node: *Node, ctx: Context) void {
            node.balance = 0;
            node.left = null;
            node.right = null;

            _ = addToSubtree(&self.root, node, ctx);
        }
        fn addToSubtree(root_opt: *?*Node, node: *Node, ctx: Context) i2 {
            // Insert node
            var root = (root_opt.* orelse {
                if (comptime hasFunc(Context, "balance")) {
                    ctx.balance(node);
                }

                root_opt.* = node;
                return 1;
            });

            const side: Side = if (ctx.less(node.key, root.key))
                .left
            else if (ctx.less(root.key, node.key))
                .right
            else
                unreachable; // Can't safely replace nodes because we might lose memory

            const bal = addToSubtree(getChild(root, side), node, ctx);
            const ret = balance(bal, &root, side, ctx);

            if (comptime hasFunc(Context, "balance")) {
                ctx.balance(root);
            }

            root_opt.* = root;
            return ret;
        }

        /// Return the specified child of a node
        fn getChild(parent: *Node, side: Side) *?*Node {
            return switch (side) {
                .left => &parent.left,
                .right => &parent.right,
            };
        }

        /// Rebalance a subtree after adding a node
        fn balance(child_balance: i2, parent: **Node, child: Side, ctx: Context) i2 {
            if (child_balance == 0) return 0;
            switch (child) {
                .right => if (parent.*.balance <= 0) {
                    parent.*.balance += 1;
                } else if (child_balance >= 0) {
                    // right right violation
                    rotate(parent, .left, ctx);
                } else {
                    // right left violation
                    rotate(parent, .right_left, ctx);
                },

                .left => if (parent.*.balance >= 0) {
                    parent.*.balance -= 1;
                } else if (child_balance <= 0) {
                    // left left violation
                    rotate(parent, .right, ctx);
                } else {
                    // left right violation
                    rotate(parent, .left_right, ctx);
                },
            }
            return parent.*.balance;
        }
        const Side = enum { right, left };

        // Perform a rebalancing rotation
        fn rotate(root: **Node, rot: Rotation, ctx: Context) void {
            const x = root.*;
            switch (rot) {
                .right => {
                    const z = x.left.?;

                    x.left = z.right;
                    z.right = x;
                    root.* = z;

                    std.debug.assert(x.balance < 0);
                    std.debug.assert(z.balance <= 0);
                    if (z.balance == 0) {
                        x.balance = -1;
                        z.balance = 1;
                    } else {
                        x.balance = 0;
                        z.balance = 0;
                    }

                    if (comptime hasFunc(Context, "balance")) {
                        ctx.balance(x);
                    }
                },

                .left => {
                    const z = x.right.?;

                    x.right = z.left;
                    z.left = x;
                    root.* = z;

                    std.debug.assert(x.balance > 0);
                    std.debug.assert(z.balance >= 0);
                    if (z.balance == 0) {
                        x.balance = 1;
                        z.balance = -1;
                    } else {
                        x.balance = 0;
                        z.balance = 0;
                    }

                    if (comptime hasFunc(Context, "balance")) {
                        ctx.balance(x);
                    }
                },

                .right_left => {
                    const z = x.right.?;
                    const y = z.left.?;

                    z.left = y.right;
                    x.right = y.left;
                    y.right = z;
                    y.left = x;
                    root.* = y;

                    std.debug.assert(x.balance > 0);
                    std.debug.assert(z.balance < 0);
                    if (y.balance == 0) {
                        x.balance = 0;
                        z.balance = 0;
                    } else if (y.balance > 0) {
                        x.balance = -1;
                        z.balance = 0;
                    } else {
                        x.balance = 0;
                        z.balance = 1;
                    }

                    if (comptime hasFunc(Context, "balance")) {
                        ctx.balance(x);
                        ctx.balance(z);
                    }
                },

                .left_right => {
                    const z = x.left.?;
                    const y = z.right.?;

                    z.right = y.left;
                    x.left = y.right;
                    y.left = z;
                    y.right = x;
                    root.* = y;

                    std.debug.assert(x.balance < 0);
                    std.debug.assert(z.balance > 0);
                    if (y.balance == 0) {
                        x.balance = 0;
                        z.balance = 0;
                    } else if (y.balance > 0) {
                        x.balance = 1;
                        z.balance = 0;
                    } else {
                        x.balance = 0;
                        z.balance = -1;
                    }

                    if (comptime hasFunc(Context, "balance")) {
                        ctx.balance(x);
                        ctx.balance(z);
                    }
                },
            }
        }
        const Rotation = enum {
            right,
            left,
            right_left,
            left_right,
        };

        /// Assert that the tree is balanced, and that all balance factors are correct.
        /// For debugging purposes.
        pub fn checkIntegrity(self: Self) void {
            _ = checkNodeIntegrity(self.root);
        }
        fn checkNodeIntegrity(node_opt: ?*Node) usize {
            const node = node_opt orelse return 0;
            if (node.balance < -1 or node.balance > 1) {
                @panic("Corrupt balance factor");
            }

            const l = checkNodeIntegrity(node.left);
            const r = checkNodeIntegrity(node.right);

            if (l < r) {
                if (r - l > 1) {
                    @panic("Tree unbalanced");
                }
                if (node.balance != r - l) {
                    @panic("Incorrect balance factor");
                }
            } else {
                if (l - r > 1) {
                    @panic("Tree unbalanced");
                }
                if (-node.balance != l - r) {
                    @panic("Incorrect balance factor");
                }
            }

            return @maximum(l, r) + 1;
        }

        fn hasFunc(comptime T: type, comptime name: []const u8) bool {
            return switch (@typeInfo(T)) {
                .Pointer => |p| hasFunc(p.child, name),
                else => std.meta.trait.hasFn(name)(T),
            };
        }
    };
}

test "insertion and array list building" {
    const Tree = AvlTree(i32, i64, struct {
        pub fn less(_: @This(), a: i32, b: i32) bool {
            return a < b;
        }
    });

    {
        var tree = Tree{};
        var n0 = Tree.Node{
            .key = 7,
            .value = 7 * 4 - 1,
        };
        var n1 = Tree.Node{
            .key = 3,
            .value = 3 * 4 - 1,
        };
        var n2 = Tree.Node{
            .key = 5,
            .value = 5 * 4 - 1,
        };
        var n3 = Tree.Node{
            .key = 10,
            .value = 10 * 4 - 1,
        };
        var n4 = Tree.Node{
            .key = 2,
            .value = 2 * 4 - 1,
        };

        tree.add(&n0);
        tree.checkIntegrity();
        tree.add(&n1);
        tree.checkIntegrity();
        tree.add(&n2);
        tree.checkIntegrity();
        tree.add(&n3);
        tree.checkIntegrity();
        tree.add(&n4);
        tree.checkIntegrity();

        var list = std.ArrayList(Tree.KV).init(std.testing.allocator);
        defer list.deinit();
        try tree.buildArrayList(&list);

        try std.testing.expectEqualSlices(Tree.KV, &.{
            n4.kv(), n1.kv(),
            n2.kv(), n0.kv(),
            n3.kv(),
        }, list.items);
    }

    {
        var tree = Tree{};
        var n0 = Tree.Node{
            .key = 0,
            .value = 7 * 4 - 1,
        };
        var n1 = Tree.Node{
            .key = 20,
            .value = 3 * 4 - 1,
        };
        var n2 = Tree.Node{
            .key = 7,
            .value = 5 * 4 - 1,
        };
        var n3 = Tree.Node{
            .key = 12,
            .value = 10 * 4 - 1,
        };
        var n4 = Tree.Node{
            .key = 1000,
            .value = 2 * 4 - 1,
        };

        tree.add(&n0);
        tree.checkIntegrity();
        tree.add(&n1);
        tree.checkIntegrity();
        tree.add(&n2);
        tree.checkIntegrity();
        tree.add(&n3);
        tree.checkIntegrity();
        tree.add(&n4);
        tree.checkIntegrity();

        var list = std.ArrayList(Tree.KV).init(std.testing.allocator);
        defer list.deinit();
        try tree.buildArrayList(&list);

        try std.testing.expectEqualSlices(Tree.KV, &.{
            n0.kv(), n2.kv(),
            n3.kv(), n1.kv(),
            n4.kv(),
        }, list.items);
    }
}
