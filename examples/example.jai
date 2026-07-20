#import,dir "..";

my_window: Window_Type;
window_width  : s32 = 1920;
window_height : s32 = 1920;

atlas: Atlas;

main :: () {
    //atlas = make_atlas(128, 128);
    atlas = make_atlas(1024, 1024);

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
                if it.key_pressed && it.key_code == .ENTER {
                    iter.can_complete = true;
                    iter.can_advance  = true;
                }
                if it.key_pressed && it.key_code == #char "F" {
                    iter.draw_fill_mask = !iter.draw_fill_mask;
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
Rect :: struct {
    x, y: int;
    w, h: int;
}

current_rect: Rect;
placed_rects: [..]Rect;

draw_one_frame :: () {
    Simp.clear_render_target(.9, .9, .9, 1);

    Simp.set_shader_for_color(true);

    time := seconds_since_init();

    if current_rect.w == 0 {
        current_rect.w = get_test_number();
        current_rect.h = get_test_number();
        print("Packing a rectangle of size %x%\n", current_rect.w, current_rect.h);
    }
    success:, current_rect.x, current_rect.y = add_rect(*atlas, current_rect.w, current_rect.h, *iter);

    if success {
        array_add(*placed_rects, current_rect);
        current_rect.w = get_test_number();
        current_rect.h = get_test_number();
        print("Packing a rectangle of size %x%\n", current_rect.w, current_rect.h);
    }

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
    for atlas.fill_matrix.columns {
        p0 := Vector2.{it * pixel_render_size, 0};
        p1 := p0 + Vector2.{0, pixel_render_size * atlas.height};
        draw_line(p0, p1, grid_color, 2);
    }
    for atlas.fill_matrix.rows {
        p0 := Vector2.{0, it * pixel_render_size};
        p1 := p0 + Vector2.{pixel_render_size * atlas.width, 0};
        draw_line(p0, p1, grid_color, 2);
    }

    for placed_rects {
        color := test_colors[it_index % test_colors.count];
        draw_pixels(it.x, it.y, it.w, it.h, color, 0.5);
    }

    if iter.draw_fill_mask for row: 0..atlas.fill_matrix.rows.count-2 {
        for col: 0..atlas.fill_matrix.columns.count-2 {
            v := atlas.fill_matrix[row][col];

            if v != .Full
                continue;

            color := Vector4.{0.2, 0.1, .1, 0.5};
            
            x0 := atlas.fill_matrix.columns[col];
            y0 := atlas.fill_matrix.rows   [row];
            x1 := atlas.fill_matrix.columns[col + 1];
            y1 := atlas.fill_matrix.rows   [row + 1];

            draw_pixels(x0, y0, x1 - x0, y1 - y0, color);
        }
    }

    {
        using iter;
        color := Vector4.{0.741, 0.243, 0.204, 1};
        if !iter.restarting swap(*color.x, *color.z);
        draw_quad_outline(region.x0, region.y0, region.x1, region.y1, color);
    }


    Simp.immediate_flush();
    Simp.swap_buffers(my_window);
}

#run main();
//#run set_build_options_dc(.{do_output = false});

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

draw_quad_outline :: (x0: int, y0: int, x1: int, y1: int, color: Vector4, thickness := 2.0) {
    _x0 := cast(float) x0 * pixel_render_size;
    _x1 := cast(float) x1 * pixel_render_size;
    _y0 := cast(float) y0 * pixel_render_size;
    _y1 := cast(float) y1 * pixel_render_size;
    draw_line(.{_x0, _y0}, .{_x1, _y0}, color, thickness);
    draw_line(.{_x1, _y0}, .{_x1, _y1}, color, thickness);
    draw_line(.{_x1, _y1}, .{_x0, _y1}, color, thickness);
    draw_line(.{_x0, _y1}, .{_x0, _y0}, color, thickness);
}

test_colors := Vector4.[
    .{219./255, 254./255, 135./255, 1},
    .{255./255, 227./255, 129./255, 1},
    .{206./255, 194./255, 136./255, 1},
    .{111./255, 134./255, 149./255, 1},
    .{ 28./255,  68./255, 142./255, 1},
    .{239./255, 118./255, 122./255, 1},
    .{ 69./255, 105./255, 144./255, 1},
    .{ 73./255, 190./255, 170./255, 1},
    .{ 73./255, 220./255, 177./255, 1},
    .{238./255, 184./255, 104./255, 1},
];

/*
test_numbers :: int.[
    37, 13,   16, 45,   29,  9,   43, 31,   43, 37,
    25, 14,   38, 45,    5, 17,   38, 17,   45,  8,
    15, 25,   40, 39,   34, 35,   20, 13,    7, 43,
    19, 18,   47,  6,   25, 27,   10, 11,   29, 44,
    35, 47,   36, 48,   48, 27,    8, 39,   48, 14,
    21, 14,   38, 10,   39, 15,   22, 38,   34,  6,
    37, 13,   27, 44,   12, 40,   34, 26,   47, 29,
    50, 12,   31, 13,   21, 27,    7,  8,   32, 25,
    44, 44,   22, 46,   40, 12,   19, 50,   34, 17,
    42, 46,   10, 32,   50, 43,   33, 36,   12, 37,
    21, 47,   29,  8,   28, 49,   13, 17,   49, 14,
    17, 45,   36, 13,   45, 46,   41, 42,   13, 40,
    42, 49,   34, 35,   27, 47,   17, 40,
];
*/

test_numbers :: int.[
    34, 30,   36, 32,   31, 30,   33, 34,   35, 30,  
    31, 31,   33, 36,   34, 30,   36, 30,   35, 30,  
    35, 30,   31, 31,   32, 36,   31, 30,   35, 36,  
    32, 33,   34, 33,   35, 31,   33, 32,   36, 36,  
    32, 32,   36, 30,   33, 34,   31, 36,   30, 31,  
    36, 31,   36, 34,   33, 33,   34, 32,   34, 35,  
    30, 30,   32, 35,   34, 32,   32, 34,   33, 32,  
    35, 31,   30, 33,   34, 35,   31, 33,   34, 30,  
    35, 30,   30, 32,   36, 30,   31, 35,   31, 35,  
    34, 33,   34, 30,   32, 34,   31, 33,   31, 36,  
    36, 32,   34, 35,   31, 35,   34, 33,   30, 35,  
    30, 34,   32, 30,   35, 30,   33, 36,   36, 32,  
    34, 36,   34, 34,   31, 36,   35, 30,   30, 35,  
    35, 34,   31, 35,   35, 30,   32, 33,   35, 31,  
    34, 36,   34, 34,   32, 33,   32, 34,   34, 33,  
    30, 34,   36, 33,   36, 36,   34, 36,   30, 33,  
    34, 35,   34, 34,   35, 35,   30, 35,   32, 32,  
    35, 36,   35, 34,   36, 34,   34, 31,   35, 33,  
    36, 34,   34, 34,   30, 32,   30, 32,   33, 31,  
    31, 30,   35, 32,   30, 33,   32, 36,   32, 34,  
    31, 30,   36, 30,   30, 35,   36, 35,   30, 32,  
    30, 33,   34, 34,   31, 33,   31, 36,   33, 35,  
    33, 33,   34, 32,   36, 31,   34, 35,   30, 35,  
    36, 34,   34, 36,   34, 34,   33, 34,   34, 35,  
    35, 35,   36, 34,   34, 32,   34, 36,   31, 35,  
    32, 32,   36, 35,   36, 32,   31, 32,   32, 35,  
    33, 34,   31, 32,   35, 36,   36, 32,   32, 34,  
    35, 36,   36, 34,   36, 30,   34, 33,   32, 34,  
    33, 32,   34, 34,   32, 35,   33, 34,   30, 32,  
    36, 31,   36, 31,   34, 32,   34, 33,   34, 33,  
    30, 30,   36, 31,   36, 31,   34, 30,   32, 31,  
    32, 30,   33, 33,   30, 35,   34, 30,   36, 34,  
    36, 30,   31, 35,   30, 34,   33, 30,   30, 31,  
    35, 32,   32, 30,   32, 36,   35, 33,   31, 32,  
    34, 30,   32, 36,   31, 35,   36, 31,   35, 31,  
    33, 34,   31, 34,   32, 34,   34, 30,   33, 34,  
    35, 32,   32, 33,   31, 30,   30, 34,   33, 30,  
    33, 30,   36, 35,   32, 33,   30, 36,   32, 32,  
    30, 35,   30, 34,   32, 33,   30, 33,   34, 30,  
    33, 32,   36, 34,   36, 34,   32, 35,   31, 30,  
    36, 35,   34, 31,   30, 32,   34, 32,   30, 31,  
    33, 36,   31, 32,   34, 35,   35, 31,   32, 35,  
    33, 34,   35, 34,   30, 35,   34, 31,   35, 36,  
    35, 34,   30, 33,   33, 32,   36, 31,   32, 36,  
    35, 36,   31, 35,   30, 30,   36, 34,   30, 35,  
    32, 36,   30, 30,   35, 32,   33, 30,   31, 36,  
    31, 36,   30, 30,   31, 32,   30, 34,   36, 31,  
    30, 35,   34, 36,   32, 30,   32, 34,   35, 35,  
    33, 34,   33, 32,   31, 32,   30, 35,   34, 32,  
    34, 36,   30, 31,   34, 31,   35, 31,   32, 31,  
];



test_number_index := 0;
get_test_number :: () -> int {
    defer test_number_index += 1;
    return test_numbers[test_number_index];
}
