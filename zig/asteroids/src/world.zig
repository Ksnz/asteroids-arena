const c = @import("sdl.zig").c;
const r = @import("render.zig");
const std = @import("std");

const entity = @import("entity.zig");
const Entity = entity.Entity;
const input = @import("input.zig");
const storage = @import("storage.zig");
const Vec2 = @import("v2.zig").Vec2;
const Component = @import("component.zig").Component;

const asteroid = @import("component/asteroid.zig");
const bullet = @import("component/bullet.zig");
const mass = @import("component/mass.zig");
const player = @import("component/player.zig");
const position = @import("component/position.zig");
const radius = @import("component/radius.zig");
const rotation = @import("component/rotation.zig");
const size = @import("component/size.zig");
const velocity = @import("component/velocity.zig");

const player_sys = @import("system/player.zig");
const physics_sys = @import("system/physics.zig");

/// Initial world width in pixels
pub const width = size.initial_width;
/// Initial world height in pixels
pub const height = size.initial_height;

/// The game uses Entity-Component-System (ECS) design where all game entities
/// are decomposed into data pieces called Components. Components are stored
/// in structure-of-arrays style and an entity is a simple integer that points
/// to the arrays.
pub const World = struct {
    rng: std.rand.DefaultPrng,
    entities: entity.Entities,
    position: position.Storage,
    velocity: velocity.Storage,
    rotation: rotation.Storage,
    mass: mass.Storage,
    radius: radius.Storage,
    player: player.Storage,
    size: size.Storage,
    asteroid: asteroid.Storage,
    bullet: bullet.Storage,

    /// Initialize internal storages, allocates memory for them. Return non zero
    /// result on error.
    pub fn init() !World {
        // Init random number generator
        var buf: [8]u8 = undefined;
        try std.crypto.randomBytes(buf[0..]);
        const seed = std.mem.readIntLittle(u64, buf[0..8]);

        var w = World {
            .rng = std.rand.DefaultPrng.init(seed),
            .entities = entity.Entities.init(),
            .position = position.Storage.init(),
            .velocity = velocity.Storage.init(),
            .rotation = rotation.Storage.init(),
            .mass = mass.Storage.init(),
            .radius = radius.Storage.init(),
            .player = player.Storage.init(),
            .size = size.Storage.init(),
            .asteroid = asteroid.Storage.init(),
            .bullet = bullet.Storage.init(),
        };
        _ = try w.spawn_player();
        _ = try w.spawn_asteroids();
        return w;
    }

    /// Deallocate internal storages and free memory.
    pub fn deinit(self: *World) void {
        self.entities.deinit();
        self.position.deinit();
        self.velocity.deinit();
        self.rotation.deinit();
        self.mass.deinit();
        self.radius.deinit();
        self.player.deinit();
        self.size.deinit();
        self.asteroid.deinit();
        self.bullet.deinit();
    }

    ///  Make one tick of world simulation with given inputs. Return non zero if failed.
    pub fn step(self: *World, dt: f64, events: *const input.Events) !void {
        player_sys.step(&self.player, &self.rotation, &self.velocity, &self.mass, dt);
        try physics_sys.step(&self.entities, &self.position, &self.velocity,
            &self.asteroid, &self.player, &self.radius, &self.rotation, self.size.global, dt);
        try self.apply_events(dt, events);
    }

    /// Render world in current frame
    pub fn render(self: *const World, renderer: *c.SDL_Renderer) !void {
        if (self.player.unique) |p| {
            const pos = self.position.get(self.player.owner) orelse unreachable;
            const rot = self.rotation.get(self.player.owner) orelse unreachable;
            r.render_player(renderer, p, pos, rot);
        }

        var i: usize = 0;
        while (i < self.entities.alive.items.len) {
            const e = self.entities.alive.items[i];

            const ac = Component.combine(.{
                Component.asteroid,
                Component.position,
                Component.rotation,
                Component.radius });
            if (try self.entities.has(e, ac)) {
                const ast = self.asteroid.get(e) orelse unreachable;
                const pos = self.position.get(e) orelse unreachable;
                const rot = self.rotation.get(e) orelse unreachable;
                const rad = self.radius.get(e) orelse unreachable;
                r.render_asteroid(renderer, ast, pos, rot, rad);
            }
            i += 1;
        }
    }

    /// Apply input events to simulation
    fn apply_events(self: *World, dt: f64, events: *const input.Events) !void {
        if (self.player.unique) |p| {
            const e = self.player.owner;
            if (events.ship_left) {
                var rot = self.rotation.get_ptr(e) orelse unreachable;
                rot.* -= player.rotation_speed * @floatCast(f32, dt);
            }
            if (events.ship_right) {
                var rot = self.rotation.get_ptr(e) orelse unreachable;
                rot.* += player.rotation_speed * @floatCast(f32, dt);
            }
            if (events.ship_thrust) {
                self.player.unique.?.thrust = true;
            }
            if (events.ship_fire and p.fire_cooldown <= 0) {

            }
        }
    }

    /// Create entity for player and fill it with initial values
    pub fn spawn_player(self: *World) !Entity {
        const x = @intToFloat(f32, self.size.global.width) * 0.5;
        const y = @intToFloat(f32, self.size.global.height) * 0.5;
        const e = try self.entities.new();
        self.player.insert(e, player.Player { .thrust = false, .fire_cooldown = 0 });
        try self.position.insert(e, Vec2 { .x = x, .y = y });
        try self.velocity.insert(e, Vec2 { .x = 0, .y = 0 });
        try self.rotation.insert(e, 0);
        try self.mass.insert(e, player.mass);
        try self.radius.insert(e, player.collision_radius);
        const components = Component.combine(.{Component.player,
            Component.position,
            Component.velocity,
            Component.rotation,
            Component.mass,
            Component.radius });
        try self.entities.add_component(e, components);
        return e;
    }

    /// Spawn all asteroids
    fn spawn_asteroids(self: *World) !void {
        var i : usize = 0;
        while (i < asteroid.amount) {
            _ = try spawn_asteroid(self);
            i += 1;
        }
    }

    /// Create entity for asteroid with random values
    fn spawn_asteroid(self: *World) !Entity {
        const mkint = self.rng.random.intRangeLessThan;
        const edges = mkint(i32, asteroid.edges_min, asteroid.edges_max);
        const x = @intToFloat(f32, mkint(i32, 0, self.size.global.width));
        const y = @intToFloat(f32, mkint(i32, 0, self.size.global.height));
        const vx = @intToFloat(f32, mkint(i32, asteroid.velocity_min, asteroid.velocity_max));
        const vy = @intToFloat(f32, mkint(i32, asteroid.velocity_min, asteroid.velocity_max));
        const rad = @intToFloat(f32, mkint(i32, asteroid.size_min, asteroid.size_max));
        const rot = @intToFloat(f32, mkint(i32, 0, 3141)) * 0.001;
        const m = std.math.pi * rad * rad * asteroid.density;

        const e = try self.entities.new();
        try self.asteroid.insert(e, asteroid.Asteroid { .edges = edges });
        try self.position.insert(e, Vec2 { .x = x, .y = y });
        try self.velocity.insert(e, Vec2 { .x = vx, .y = vy });
        try self.rotation.insert(e, rot);
        try self.mass.insert(e, m);
        try self.radius.insert(e, rad);
        const components = Component.combine(.{Component.asteroid,
            Component.position,
            Component.velocity,
            Component.rotation,
            Component.mass,
            Component.radius });

        try self.entities.add_component(e, components);
        return e;
    }
};
