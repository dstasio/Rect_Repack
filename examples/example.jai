#import,dir "..";

my_window: Window_Type;
window_width  : s32 = 1920;
window_height : s32 = 1080;

my_font: *Simp.Dynamic_Font;

atlas: Atlas;

main :: () {
    atlas = pack();

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

    my_init_fonts();

    quit := false;
    want_screenshot := false;
    while !quit {
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.

            if it.window == my_window {
                should_reinit := (it.width != window_width) || (it.height != window_height);

                window_width  = it.width;
                window_height = it.height;

                if should_reinit my_init_fonts();  // Resize the font for the new window size.
            }
        }

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            if it.type == {
              case .TOUCH;
                if it.touch_type == .PRESSED { // Touch screen to take a screenshot
                    want_screenshot = true;
                }

              case .KEYBOARD;
                if it.key_pressed && it.key_code == .ESCAPE {
                    quit = true;
                }

                if it.key_pressed && it.key_code == #char " " {  // Press spacebar to take a screenshot.
                    want_screenshot = true;
                }

                // :AndroidLifeCycle :AndroidWindowSurfaceRecreation
              case .WINDOW;
                if it.window_event_type == {
                  case .MOVED_TO_BACKGROUND;
                    Simp.disable_window(it.window);
                    my_window = WT.INVALID_WINDOW;

                  case .MOVED_TO_FOREGROUND;
                    Simp.enable_window(it.window);
                    my_window = it.window;
                }
            }
        }

        draw_one_frame();

        sleep_milliseconds(10);
        reset_temporary_storage();
    }
}

draw_one_frame :: () {
    Simp.clear_render_target(.1, .1, .1, 1);

    Simp.set_shader_for_color();

    time := seconds_since_init();

    pixel_render_size := cast(float, min(window_width, window_height)) / atlas.width;
 
    for y: 0..atlas.height-1
    for x: 0..atlas.width-1 {
        x0 := x * pixel_render_size;
        x1 := x0 + pixel_render_size - 0.3;
        y0 := y * pixel_render_size;
        y1 := y0 + pixel_render_size - 0.3;
        pixel := atlas.pixels[y * atlas.width + x];

        color := Vector4.{0.85, 0.87, 0.98, 1};
        color.x -= pixel / 256.0;
        color.y -= pixel / 512.0;
        Simp.immediate_quad(x0, y0, x1, y1, color);
    }

    Simp.immediate_flush();
    Simp.swap_buffers(my_window);
}

my_init_fonts :: () {
    pixel_height := window_height / 24;

    my_font = Simp.get_font_at_size(".", "OpenSans-BoldItalic.ttf", pixel_height);
    assert(my_font != null);
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

