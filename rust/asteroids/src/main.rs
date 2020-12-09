extern crate sdl2;
extern crate specs;
extern crate glam;
#[macro_use]
extern crate specs_derive;

use asteroids::components::size::*;
use asteroids::components::time::DeltaTime;
use asteroids::systems::init_systems;
use asteroids::world::init_world;
use sdl2::event::Event;
use sdl2::event::WindowEvent::SizeChanged;
use sdl2::keyboard::Keycode;
use sdl2::pixels::Color;
use specs::WorldExt;
use std::time::Instant;

mod asteroids;

pub fn main() {
    let sdl_context = sdl2::init().unwrap();
    let video_subsystem = sdl_context.video().unwrap();

    let mut world = init_world();
    let mut dispatcher = init_systems(&mut world);

    let window = video_subsystem.window("Asteroids game", DEF_WORLD_WIDTH, DEF_WORLD_HEIGHT)
        .position_centered()
        .build()
        .unwrap();

    let mut canvas = window.into_canvas().build().unwrap();

    canvas.set_draw_color(Color::RGB(0, 0, 0));
    canvas.clear();
    canvas.present();
    let mut event_pump = sdl_context.event_pump().unwrap();
    'running: loop {
        let frame_begin = Instant::now();
        canvas.set_draw_color(Color::RGB(0, 0, 0));
        canvas.clear();
        for event in event_pump.poll_iter() {
            match event {
                Event::Quit {..} |
                Event::KeyDown { keycode: Some(Keycode::Escape), .. } => {
                    break 'running
                },
                Event::Window { win_event: SizeChanged(w, h), .. } => {
                    world.insert(WorldSize(w as u32, h as u32));
                },
                _ => {}
            }
        }
        canvas.present();

        let frame_end = Instant::now();
        world.insert(DeltaTime(frame_end.duration_since(frame_begin)));
        dispatcher.dispatch(&world);
        world.maintain();
    }
}
