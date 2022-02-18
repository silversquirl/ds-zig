const std = @import("std");

// Non-allocating, node-based, self-balancing binary min-heap
pub fn LinkedHeap(comptime T: type, comptime Context: type, lessFn: fn (Context, T, T) bool) type {
    return struct {
        context: Context = if (@bitSizeOf(Context) == 0)
            undefined
        else
            @compileError("must specify context for non-zero-bit types"),
        root: ?*Node = null,
        count: usize = 0,

        pub const Node = struct {
            v: T,
            link: NodeLink = .{},
        };
        const NodeLink = struct {
            parent: ?*Node = null,
            left: ?*Node = null,
            right: ?*Node = null,
        };
        const Self = @This();

        pub fn insert(self: *Self, node: *Node) void {
            std.debug.assert(std.meta.eql(node.link, .{}));

            // Push node
            {
                self.count += 1;
                const dest = self.findLastNode(&node.link.parent);
                dest.* = node;
            }

            // Bubble up
            while (node.link.parent) |parent| {
                if (!lessFn(self.context, node.v, parent.v)) {
                    break;
                }
                self.swapNodes(parent, node);
            }
        }

        pub fn pop(self: *Self) ?*Node {
            // Replace the root with the last node
            const old_root = self.root orelse return null;
            const node = self.findLastNode(null).*.?;
            if (old_root == node) {
                self.root = null;
            } else {
                if (node.link.parent) |p| {
                    if (p.link.left == node) {
                        p.link.left = null;
                    } else if (p.link.right == node) {
                        p.link.right = null;
                    } else {
                        unreachable;
                    }
                }
                node.link = old_root.link;
                if (node.link.left) |l| {
                    l.link.parent = node;
                }
                if (node.link.right) |r| {
                    r.link.parent = node;
                }
                std.debug.assert(node.link.parent == null);
                self.root = node;
            }
            self.count -= 1;

            // Bubble down
            while (true) {
                // Find the smallest child that's less than node
                var child = node;
                if (node.link.left) |l| {
                    if (lessFn(self.context, l.v, child.v)) {
                        child = l;
                    }
                }
                if (node.link.right) |r| {
                    if (lessFn(self.context, r.v, child.v)) {
                        child = r;
                    }
                }
                // If neither child is smaller, break
                if (child == node) break;
                // Swap with the smallest child
                self.swapNodes(node, child);
            }

            return old_root;
        }

        // If parent != null, assumes parent.?.* == null
        // Assumes self.count > 0
        fn findLastNode(self: *Self, parent: ?*?*Node) *?*Node {
            const depth = std.meta.bitCount(usize) - @clz(usize, self.count);
            var mask = @as(usize, 1) << @intCast(std.math.Log2Int(usize), depth - 1) >> 1;
            var dest = &self.root;
            while (mask > 0) : (mask >>= 1) {
                if (parent) |p| p.* = dest.*;
                if (self.count & mask == 0) {
                    // 0 bit = left
                    dest = &dest.*.?.link.left;
                } else {
                    // 1 bit = right
                    dest = &dest.*.?.link.right;
                }
            }
            return dest;
        }

        fn swapNodes(self: *Self, parent: *Node, child: *Node) void {
            // Swap links
            std.mem.swap(NodeLink, &parent.link, &child.link);

            // Fix child children <- parent
            if (parent.link.left) |l| {
                l.link.parent = parent;
            }
            if (parent.link.right) |r| {
                r.link.parent = parent;
            }

            // Fix child -> parent
            parent.link.parent = child;
            if (child.link.left == child) {
                child.link.left = parent;
            } else if (child.link.right == child) {
                child.link.right = parent;
            } else {
                unreachable;
            }

            // Fix parent children <- child
            if (child.link.left) |l| {
                l.link.parent = child;
            }
            if (child.link.right) |r| {
                r.link.parent = child;
            }

            // Fix parent parent -> child
            if (child.link.parent) |p| {
                if (p.link.left == parent) {
                    p.link.left = child;
                } else if (p.link.right == parent) {
                    p.link.right = child;
                } else {
                    unreachable;
                }
            }

            // Fix root
            if (self.root == parent) {
                self.root = child;
            }
        }

        /// For debugging
        fn dump(self: *Self, comptime fmt: []const u8) void {
            std.debug.print("\nHeap dump:\n", .{});
            if (self.root) |root| {
                dumpNode(root, 0, fmt);
            }
            std.debug.print("\n", .{});
        }
        fn dumpNode(node: *Node, indent: u32, comptime fmt: []const u8) void {
            if (node.link.right) |r| {
                dumpNode(r, indent + 1, fmt);
            }

            var i: u32 = 0;
            while (i < indent) : (i += 1) {
                std.debug.print("\t", .{});
            }
            std.debug.print(fmt ++ "\n", .{node.v});

            if (node.link.left) |l| {
                dumpNode(l, indent + 1, fmt);
            }
        }
    };
}

test "linked heap" {
    var in_data: [512]u32 = undefined;
    var rand = std.rand.DefaultPrng.init(1234);
    for (in_data) |*n| {
        n.* = rand.random().int(u32);
    }

    var out_data = in_data;
    std.sort.sort(u32, &out_data, {}, comptime std.sort.asc(u32));

    const Heap = LinkedHeap(u32, void, comptime std.sort.asc(u32));
    var heap = Heap{};
    for (in_data) |n| {
        const node = try std.testing.allocator.create(Heap.Node);
        node.* = .{ .v = n };
        heap.insert(node);
    }

    var popped_data = std.ArrayList(u32).init(std.testing.allocator);
    defer popped_data.deinit();
    while (heap.pop()) |node| {
        try popped_data.append(node.v);
        std.testing.allocator.destroy(node);
    }

    try std.testing.expectEqualSlices(u32, &out_data, popped_data.items);
}
