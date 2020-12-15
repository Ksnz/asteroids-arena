const std = @import("std");
const Component = @import("component.zig").Component;

/// Entity is simple ID that has associated components
pub const Entity = u32;

/// Special shortcut to context where there is only one meaningfull value
/// for entity ID.
pub const global : Entity = 0;

/// Special storage of world that tracks alive entities and their components.
pub const Entities = struct {
    /// Next free entity ID
    entity_counter: usize,
    /// Collection of alive entities
    alive: std.ArrayList(Entity),
    /// Component tags for iteration
    tags: std.ArrayList(Component),

    /// Initialize the storage with 0 entities
    pub fn init() Entities {
        const allocator = std.heap.page_allocator;
        return Entities {
            .entity_counter = 0,
            .alive = std.ArrayList(Entity).init(allocator),
            .tags = std.ArrayList(Component).init(allocator),
        };
    }

    /// Deallocate memory of the storage
    pub fn deinit(self: *Entities) void {
        self.alive.deinit();
        self.tags.deinit();
    }
};