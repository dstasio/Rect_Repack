

Atlas :: struct {
    width:       s32;
    height:      s32;
    pixels:    []u8;

    fill_matrix: Spatial_Matrix(s32, Region_Fill, Uninitialized_Value = Region_Fill.Uninitialized);
}

make_atlas :: (width_: s32, height_: s32) -> Atlas {
    using atlas: Atlas;

    width  = width_;
    height = height_;

    pixels = NewArray( atlas.width * atlas.height, u8);
    reserve(*fill_matrix, width / 2, height / 2);
    add_at(*fill_matrix, 0, 0, .Empty);
    add_at(*fill_matrix, width, height, .Full);

    return atlas;
}

Iter_Window :: struct {
    x, y, w, h: int;
}
Iter_State__ :: struct {
    can_advance  := false;
    can_complete := false;
    searched_this_frame := false;
    restarting   := false;
    draw_fill_mask := false;

    region: Region;
    cursor: Cursor;

    Region :: struct {
        x0, y0: s32;
        x1, y1: s32;
    }
    Cursor :: struct {
        row , col  : int;
        rows, cols := 0;
    }
}

add_rect :: (using atlas: *Atlas, rect_w: int, rect_h: int, using iteration_state: *Iter_State__) -> success := false, x := 0, y := 0 #no_abc {
    Tolerance :: 5;

    //region: Region;
    //cursor: Cursor;

    while outermost := true {
        if !can_advance break;
        defer {
            if !can_complete
                can_advance = false;
        }
        searched_this_frame = false;

        if restarting {
            restarting = false;
            cursor.col += cursor.cols;

            region = .{};

            cursor.rows = 0;
            cursor.cols = 0;
            if cursor.col >= fill_matrix.columns.count {
                cursor.col = 0;
                cursor.row += 1;
                if cursor.row >= fill_matrix.rows.count {
                    cursor = .{};
                    return;
                }
            }
        }

        region.x0 = fill_matrix.columns[cursor.col];
        region.y0 = fill_matrix.rows   [cursor.row];

        cursor_pre_resize := cursor;

        minimum_y1 := region.y0 + rect_h;
        while region.y1 < minimum_y1 {
            defer { searched_this_frame = true; if !can_complete break; }
            cursor.rows += 1;

            if (cursor.row + cursor.rows) >= fill_matrix.rows.count
                break outermost;

            region.y1 = fill_matrix.rows[cursor.row + cursor.rows];

            for 0..cursor.cols-1
            if fill_matrix[cursor.row + cursor.rows - 1][cursor.col + it] == .Full {
                restarting = true;
                continue outermost;
            }

            delta := (minimum_y1 - region.y1);
            if delta > 0 && delta <= Tolerance {
                //restarting = true;
                //continue outermost;
            }
        }

        minimum_x1 := region.x0 + rect_w;
        while region.x1 < minimum_x1 {
            defer { searched_this_frame = true; if !can_complete break; }
            cursor.cols += 1;

            if (cursor.col + cursor.cols) >= fill_matrix.columns.count {
                restarting = true;
                continue outermost;
            }

            region.x1 = fill_matrix.columns[cursor.col + cursor.cols];

            for 0..cursor.rows-1
            if fill_matrix[cursor.row + it][cursor.col + cursor.cols - 1] == .Full {
                restarting = true;
                continue outermost;
            }
        }

        if region.y1 < minimum_y1 || region.x1 < minimum_x1 {
            return;
        }
        if searched_this_frame continue;

        // We add the rect here.
        add_at(*fill_matrix, xx (region.y0 + rect_h), xx (region.x0 + rect_w), .Empty, allow_replacing = false);

        for cx: 0..cursor.cols-1 for cy: 0..cursor.rows-1 {
            fill_matrix[cursor.row + cy][cursor.col + cx] = .Full;
        }

        defer {
            region = .{};
            cursor = .{};
        }

        can_complete = false;
        return true, region.x0, region.y0;
    }

    return;
}

#scope_file
Region_Fill :: enum s8 {
    Empty :: 0;
    Full  :: 1;

    Uninitialized :: -1;
}

#load "spatial_matrix.jai";

#import "Basic";
#import "Math";
