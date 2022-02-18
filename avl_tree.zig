//! Array-backed AVL tree
const std = @import("std");

pub fn AvlTree(
    comptime K: type,
    comptime V: type,
    comptime Context: type,
    comptime lessThan: fn (context: Context, lhs: K, rhs: K) bool,
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
        pub fn buildArrayListInternal(node_opt: ?*Node, list: *std.ArrayList(KV)) std.mem.Allocator.Error!void {
            if (node_opt) |node| {
                try buildArrayListInternal(node.left, list);
                try list.append(node.kv());
                try buildArrayListInternal(node.right, list);
            }
        }
        pub const KV = struct { key: K, value: V };

        pub fn find(self: *Self, key: K) ?*Node {
            if (@sizeOf(Context) != 0) {
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call findContext instead.");
            }
            self.findContext(key, undefined);
        }
        pub fn findContext(self: *Self, key: K, ctx: Context) ?*Node {
            var node_opt = self.root;
            while (node_opt) |node| {
                if (lessThan(ctx, key, node)) {
                    node_opt = node.left;
                } else if (lessThan(ctx, node, key)) {
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
                root_opt.* = node;
                return 1;
            });
            if (lessThan(ctx, node.key, root.key)) {
                const bal = addToSubtree(&root.left, node, ctx);
                const ret = balance(bal, &root, .left);
                root_opt.* = root;
                return ret;
            } else if (lessThan(ctx, root.key, node.key)) {
                const bal = addToSubtree(&root.right, node, ctx);
                const ret = balance(bal, &root, .right);
                root_opt.* = root;
                return ret;
            } else {
                // Replace root
                node.balance = root.balance;
                node.left = root.left;
                node.right = root.right;
                root_opt.* = node;
                return 0;
            }
        }

        // Rebalance a subtree after adding a node
        fn balance(child_balance: i2, parent: **Node, child: Side) i2 {
            if (child_balance == 0) return 0;
            switch (child) {
                .right => if (parent.*.balance <= 0) {
                    parent.*.balance += 1;
                } else if (child_balance >= 0) {
                    // right right violation
                    rotate(parent, .left);
                } else {
                    // right left violation
                    rotate(parent, .right_left);
                },

                .left => if (parent.*.balance >= 0) {
                    parent.*.balance -= 1;
                } else if (child_balance <= 0) {
                    // left left violation
                    rotate(parent, .right);
                } else {
                    // left right violation
                    rotate(parent, .left_right);
                },
            }
            return parent.*.balance;
        }
        const Side = enum { right, left };

        // Perform a rebalancing rotation
        fn rotate(x: **Node, rot: Rotation) void {
            switch (rot) {
                .right => {
                    const z = x.*.left.?;
                    x.*.left = z.right;
                    z.right = x.*;
                    x.* = z;
                },

                .left => {
                    const z = x.*.right.?;
                    x.*.right = z.left;
                    z.left = x.*;
                    x.* = z;
                },

                .right_left => {
                    const z = x.*.right.?;
                    const y = z.left.?;
                    z.left = y.right;
                    x.*.right = y.left;
                    y.right = z;
                    y.left = x.*;
                    x.* = y;
                },

                .left_right => {
                    const z = x.*.left.?;
                    const y = z.right.?;
                    z.right = y.left;
                    x.*.left = y.right;
                    y.left = z;
                    y.right = x.*;
                    x.* = y;
                },
            }
        }
        const Rotation = enum {
            right,
            left,
            right_left,
            left_right,
        };
    };
}

test "insertion and array list building" {
    const Tree = AvlTree(i32, i64, void, comptime std.sort.asc(i32));
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
    tree.add(&n1);
    tree.add(&n2);
    tree.add(&n3);
    tree.add(&n4);

    var list = std.ArrayList(Tree.KV).init(std.testing.allocator);
    defer list.deinit();
    try tree.buildArrayList(&list);

    try std.testing.expectEqualSlices(Tree.KV, &.{
        n4.kv(), n1.kv(),
        n2.kv(), n0.kv(),
        n3.kv(),
    }, list.items);
}
