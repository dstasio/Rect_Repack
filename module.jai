

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

    return atlas;
}

Iter_Window :: struct {
    x, y, w, h: int;
}
Iter_State__ :: struct {
    x := 0;
    y := 0;
    can_advance  := true;
    can_complete := false;

    candidate_x := 0;
    candidate_y := 0;

    current_window_x: int;
    current_window_y: int;
    current_window_w: int;
    current_window_h: int;

    windows     : [8]Iter_Window;
    prev_windows: [8]Iter_Window;
    is_good     : [8]bool;
}

add_rect :: (atlas: *Atlas, rect_w: int, rect_h: int, iteration_state: *Iter_State__) -> success := false, x := 0, y := 0 {
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
    candidate_x := iteration_state.candidate_x;
    candidate_y := iteration_state.candidate_y;
    while y < atlas.height {
        if !iteration_state.can_advance break;
        defer {
            iteration_state.x = x;
            iteration_state.y = y;
            iteration_state.can_advance = iteration_state.can_complete;
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

            if (x + mask_bucket_index) * BITS_PER_MASK_BUCKET > atlas.width-1 {
                row_is_free = false;
                break mask_bucket;
            }
            occupancy_mask := atlas.fill_mask[y * atlas.width / BITS_PER_MASK_BUCKET + x + mask_bucket_index];

            iteration_state.is_good[mask_bucket_index] = ((~occupancy_mask) & mask_bucket) == mask_bucket;
            if ((~occupancy_mask) & mask_bucket) != mask_bucket {
                row_is_free = false;
                break mask_bucket;
            }
        }

        if row_is_free {
            iteration_state.prev_windows = iteration_state.windows;
            
            if (y - candidate_y) == rect_h {
                // Done. We can put the rectangle here.
                iteration_state.* = .{};

                for yy: candidate_y..y-1
                for mask_bucket, mask_bucket_index: row_mask {
                    if mask_bucket == 0 continue;
                    atlas.fill_mask[yy * atlas.width / BITS_PER_MASK_BUCKET + x + mask_bucket_index] |= mask_bucket;
                }

                x = 0;
                y = 0;

                return true, candidate_x * BITS_PER_MASK_BUCKET, candidate_y;
            } else {
                y += 1;
            }
        } else {
            x += 1;
            y  = candidate_y;
            if x * BITS_PER_MASK_BUCKET > atlas.width {
                x = 0;
                y += 1;
            }
            candidate_x = x;
            candidate_y = y;

            iteration_state.candidate_x = candidate_x;
            iteration_state.candidate_y = candidate_y;
        }

        for mask_bucket, mask_bucket_index: row_mask {
            if mask_bucket == 0 continue;
            iteration_state.windows[mask_bucket_index].x = (x + mask_bucket_index) * BITS_PER_MASK_BUCKET;
            iteration_state.windows[mask_bucket_index].y = y;
            iteration_state.windows[mask_bucket_index].w = BITS_PER_MASK_BUCKET;
            iteration_state.windows[mask_bucket_index].h = 1;
        }
    }

    return;
}

#import "Basic";
#import "Math";
