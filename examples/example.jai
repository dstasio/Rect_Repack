#import,dir "..";

my_window: Window_Type;
window_width  : s32 = 1920;
window_height : s32 = 1920;

atlas: Atlas;

main :: () {
    atlas = make_atlas(128, 128);

    context.input_handler.window_proc = Input.MyWindowProc;

    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    WANTED_MSAA :: 8;
    my_window = create_window(window_width, window_height, "A Window", wanted_msaa = WANTED_MSAA);
    msaa := Simp.prepare_window(my_window, wanted_msaa = WANTED_MSAA);
    log("Wanted MSAA: %\nChosen MSAA: %", WANTED_MSAA, msaa);

    window_width, window_height = Simp.get_render_dimensions(my_window);

    Simp.set_render_target(my_window, .LEFT_HANDED);

    quit := false;
    while !quit {
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.

            if it.window == my_window {
                should_reinit := (it.width != window_width) || (it.height != window_height);

                window_width  = it.width;
                window_height = it.height;
            }
        }

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            if it.type == {
              case .KEYBOARD;
                if it.key_pressed && it.key_code == .ESCAPE {
                    quit = true;
                }
                if it.key_pressed && it.key_code == .SPACEBAR {
                    iter.can_advance = true;
                }
            }
        }

        draw_one_frame();

        sleep_milliseconds(10);
        reset_temporary_storage();
    }
}

iter: Iter_State__;
pixel_render_size: float;

draw_one_frame :: () {
    Simp.clear_render_target(.9, .9, .9, 1);

    Simp.set_shader_for_color(true);

    time := seconds_since_init();

    add_rect(*atlas, 20, 25, *iter);

    pixel_render_size = cast(float, min(window_width, window_height)) / atlas.width;

    draw_pixels :: (x: int, y: int, w := 1, h := 1, color := Vector4.{0.2, 0.5, 0.8, 0.3}, alpha_multiplier := 1.0) {
        x0 := x  * pixel_render_size;
        x1 := x0 + pixel_render_size * w;
        y0 := y  * pixel_render_size;
        y1 := y0 + pixel_render_size * h;

        pixel := atlas.pixels[y * atlas.width + x];

        c := color;
        c.x -= pixel / 256.0;
        c.y -= pixel / 512.0;
        c.w *= alpha_multiplier;
        Simp.immediate_quad(x0, y0, x1, y1, c);
    }
 
    grid_color := Vector4.{0.2, 0.2, 0.2, 0.1};

    for 0..max(atlas.width, atlas.height)-1 {
        p0 := Vector2.{it * pixel_render_size, 0};
        p1 := p0 + Vector2.{0, pixel_render_size * atlas.height};
        draw_line(p0, p1, grid_color, 1);

        p0.x, p0.y = p0.y, p0.x;
        p1.x, p1.y = p1.y, p1.x;
        draw_line(p0, p1, grid_color, 1);
    }

    for window: iter.windows {
        color_current := Vector4.{0.2, 0.5, 0.8, 0.2};

        color := color_current;
        if it_index % 2
            then color.w *= 0.5;
        draw_pixels(window.x, window.y, window.w, window.h, color);
    }
    for window: iter.prev_windows {
        color_good := Vector4.{0.2, 0.9, 0.78, 0.2};
        color_bad  := Vector4.{0.9, 0.3, 0.4, 0.2};

        color := ifx iter.is_good[it_index] then color_good else color_bad;
        if it_index % 2
            then color.w *= 0.5;
        draw_pixels(window.x, window.y, window.w, window.h, color);
    }

    Simp.immediate_flush();
    Simp.swap_buffers(my_window);
}

#run main();
#run set_build_options_dc(.{do_output = false});

#import "Compiler";

#import "Window_Creation";

Simp  :: #import "Simp";
Input :: #import "Input";
#import "Basic";
#import "Math";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.

draw_line :: (p0: Vector2, p1: Vector2, color: Vector4, thickness := 3.0) {
    dir := normalize(p1 - p0);
    normal := Vector2.{-dir.y, dir.x};

    tn := normal * thickness;
    a := p0 - tn;
    b := p0 + tn;
    c := p1 + tn;
    d := p1 - tn;

    Simp.immediate_quad(a, b, c, d, color);
}
