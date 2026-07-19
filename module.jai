

Atlas :: struct {
    width:       s32;
    height:      s32;
    pixels:    []u8;
    fill_mask: []u8;
}

make_atlas :: (width_: s32, height_: s32) -> Atlas {
    atlas: Atlas;
    assert((width_ % 8) == 0);
    //assert((height % 8) == 0);
    atlas.width  = width_;
    atlas.height = height_;

    using atlas;

    pixels    = NewArray( atlas.width * atlas.height     , u8);
    fill_mask = NewArray((atlas.width * atlas.height) / 8, u8); // Only the width is compressed

    print("pixels: %\nfill_mask: %\n", pixels.count, fill_mask.count);

    pixels[500 + 50] = 85;
    pixels[500 + 51] = 90;
    pixels[500 + 52] = 128;
    pixels[500 + 53] = 128;
    pixels[500 + 54] = 128;
    fill_mask[atlas.width / 8] = 0xF0;

    return atlas;
}

Iter_Window :: struct {
    x, y, w, h: int;
}
Iter_State__ :: struct {
    x := 0;
    y := 0;
    can_advance := true;

    current_window_x: int;
    current_window_y: int;
    current_window_w: int;
    current_window_h: int;

    windows     : [8]Iter_Window;
    prev_windows: [8]Iter_Window;
    is_good     : [8]bool;
}

add_rect :: (atlas: *Atlas, rect_w: int, rect_h: int, iteration_state: *Iter_State__) {
    Mask_Bucket_Type     :: u8;
    BITS_PER_MASK_BUCKET :: size_of(Mask_Bucket_Type) * 8;

    rect_row_mask_slots   := cast(int, ceil(rect_w / cast(float, BITS_PER_MASK_BUCKET)) + 1); // 1 extra so that we can spill over when offsetting.
    rect_row_masks_buffer := NewArray(rect_row_mask_slots * BITS_PER_MASK_BUCKET, Mask_Bucket_Type,, temp);

    rect_row_masks: [BITS_PER_MASK_BUCKET][]Mask_Bucket_Type;
    for *mask, mask_index: rect_row_masks {
        mask.data  = rect_row_masks_buffer.data + rect_row_mask_slots * mask_index;
        mask.count = rect_row_mask_slots;

        mask_shift := mask_index;

        remaining_width  := rect_w;
        mask_bucket_index := 0;

        // start_bit is the leftmost bit. Indexed left-to-right.
        // Maybe this is confusing.
        start_bit := mask_shift;
        end_bit   := start_bit + rect_w;
        while remaining_width > 0 {
            defer {
                mask_bucket_index += 1;
                start_bit = max(0, start_bit - BITS_PER_MASK_BUCKET);
                end_bit   = max(0,   end_bit - BITS_PER_MASK_BUCKET);

                if start_bit == end_bit break;
            }

            bits_to_set := min(end_bit, BITS_PER_MASK_BUCKET) - start_bit;

            mask_pixel := cast,no_check(Mask_Bucket_Type, (1 << bits_to_set) - 1);
            if end_bit <= BITS_PER_MASK_BUCKET
                mask_pixel <<= BITS_PER_MASK_BUCKET - end_bit;
            mask.*[mask_bucket_index] = mask_pixel;
        }
    }

    /*
    print("Masks for a rect of width %\n", rect_w);
    push_context {
        context.print_style.default_format_int.base           = 2;
        context.print_style.default_format_int.minimum_digits = BITS_PER_MASK_BUCKET;
        for mask: rect_row_masks {
            print("mask % -> %\n", FormatInt.{value = it_index, base = 10, minimum_digits = 2}, mask);
        }
    }
    */

    x := iteration_state.x;
    y := iteration_state.y;
    while x < atlas.width && y < atlas.height {
        if !iteration_state.can_advance break;
        defer {
            iteration_state.x = x;
            iteration_state.y = y;
            iteration_state.can_advance = false;
        }

        row_mask := rect_row_masks[0];

        row_is_free := true;
        for mask_bucket, mask_bucket_index: row_mask {
            if mask_bucket == 0 {
                iteration_state.windows[mask_bucket_index].w = 0;
                iteration_state.windows[mask_bucket_index].h = 0;
                continue;
            }
            iteration_state.windows[mask_bucket_index].x = (x + mask_bucket_index) * BITS_PER_MASK_BUCKET;
            iteration_state.windows[mask_bucket_index].y = y;
            iteration_state.windows[mask_bucket_index].w = BITS_PER_MASK_BUCKET;
            iteration_state.windows[mask_bucket_index].h = 1;

            occupancy_mask := atlas.fill_mask[y * atlas.width / BITS_PER_MASK_BUCKET + x + mask_bucket_index];

            iteration_state.is_good[mask_bucket_index] = ((~occupancy_mask) & mask_bucket) == mask_bucket;
            if ((~occupancy_mask) & mask_bucket) != mask_bucket {
                row_is_free = false;
                break mask_bucket;
            }
        }

        if row_is_free {
            iteration_state.prev_windows = iteration_state.windows;
            y += 1;
        } else {
            x += 1;
            y  = 0;
        }

        for mask_bucket, mask_bucket_index: row_mask {
            if mask_bucket == 0 continue;
            iteration_state.windows[mask_bucket_index].x = (x + mask_bucket_index) * BITS_PER_MASK_BUCKET;
            iteration_state.windows[mask_bucket_index].y = y;
            iteration_state.windows[mask_bucket_index].w = BITS_PER_MASK_BUCKET;
            iteration_state.windows[mask_bucket_index].h = 1;
        }
    }

}

#import "Basic";
#import "Math";
