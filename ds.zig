pub const AvlTree = @import("avl_tree.zig").AvlTree;
pub const IntervalTree = @import("interval_tree.zig").IntervalTree;
pub const LinkedHeap = @import("linked_heap.zig").LinkedHeap;

comptime {
    _ = AvlTree;
    _ = IntervalTree;
    _ = LinkedHeap;
}
