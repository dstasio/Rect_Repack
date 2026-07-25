Rect_Pack :: struct {
    width:       s32;
    height:      s32;

    rows: [..]Rect_Row;

    minimum_row_height := 0;
}

Rect_Row :: struct {
    // Maybe we don't need to store y.
    y          : u16;
    height     : u16;
    used_width : u16;
}

init_rect_pack :: (width_: s32, height_: s32, minimum_row_height_ := 0) -> Rect_Pack {
    using pack: Rect_Pack;

    width  = width_;
    height = height_;
    minimum_row_height = minimum_row_height_;

    array_reserve(*rows, height / max(minimum_row_height, 32));

    return pack;
}

add_rect :: (using pack: *Rect_Pack, rect_w: int, rect_h: int) -> success := false, x := 0, y := 0, row_index := 0 {
    assert(rect_w < width);

    maximum_used_y: u16;

    maximum_used_width := width - rect_w;
    selected_row: *Rect_Row;
    for *row, row_index: rows {
        maximum_used_y = max(row.y + row.height, maximum_used_y);

        if row.height < rect_h                 continue;
        if row.used_width > maximum_used_width continue;

        if !selected_row || row.height < selected_row.height {
            selected_row = row;
        }
    }

    if !selected_row {
        if (maximum_used_y + rect_h) > height
            return false;
            
        selected_row = array_add(*rows);
        selected_row.y          = maximum_used_y;
        selected_row.height     = max(rect_h, minimum_row_height).(u16);
        selected_row.used_width = 0;
    }

    x : int = selected_row.used_width;
    y : int = selected_row.y;

    selected_row.used_width += xx rect_w;

    return true, x, y, selected_row - rows.data;
}

clear_row :: (using pack: Rect_Pack, row_index: int) {
    rows.rows[row_index].used_width = 0;
}

#scope_file
#import "Basic";
