

Atlas :: struct {
    width:       s32;
    height:      s32;
    pixels:    []u8;
    fill_mask: []u8;
}

pack :: () -> Atlas {
    atlas: Atlas;
    //atlas.width  = 2048;
    //atlas.height = 2048;
    atlas.width  = 128;
    atlas.height = 128;

    using atlas;

    pixels    = NewArray( atlas.width * atlas.height         , u8);
    fill_mask = NewArray((atlas.width * atlas.height) / (8*8), u8);

    print("pixels: %\nfill_mask: %\n", pixels.count, fill_mask.count);

    pixels[500 + 50] = 85;
    pixels[500 + 51] = 90;
    pixels[500 + 52] = 128;
    pixels[500 + 53] = 128;
    pixels[500 + 54] = 128;


    Mask_Type             :: u8;
    Bigger_Than_Mask_Type :: u16;
    BITS_PER_MASK_PIXEL :: 8;
    rect_w := 20;
    rect_h := 25;

    rect_row_mask_slots   := cast(int, ceil(rect_w / cast(float, BITS_PER_MASK_PIXEL)) + 1); // 1 extra so that we can spill over when offsetting.
    rect_row_masks_buffer := NewArray(rect_row_mask_slots * BITS_PER_MASK_PIXEL, u8,, temp);

    rect_row_masks: [BITS_PER_MASK_PIXEL][]u8;
    for *mask, mask_index: rect_row_masks {
        mask.data  = rect_row_masks_buffer.data + rect_row_mask_slots * mask_index;
        mask.count = rect_row_mask_slots;

        mask_shift := mask_index;

        remaining_width  := rect_w;
        mask_pixel_index := 0;
        while remaining_width > 0 {
            defer mask_pixel_index += 1;

            bits_to_set := min(remaining_width, BITS_PER_MASK_PIXEL);
            if mask_pixel_index == 0
                then bits_to_set -= mask_shift;
            remaining_width -= bits_to_set;

            mask_pixel := cast(Mask_Type, (1 << bits_to_set) - 1);
            if remaining_width == 0 {
                // If this is the last mask byte, then we want to set the high bits, so we shift.
                mask_pixel <<= BITS_PER_MASK_PIXEL - bits_to_set;
            }
            mask.*[mask_pixel_index] = mask_pixel;
        }
    }

    print("Masks for a rect of width %\n", rect_w);
    push_context {
        context.print_style.default_format_int.base           = 2;
        context.print_style.default_format_int.minimum_digits = 8;
        for mask: rect_row_masks {
            print("mask % -> %\n", FormatInt.{value = it_index, base = 10, minimum_digits = 2}, mask);
        }
    }

    x := 0;
    y := 0;
    while x < atlas.width && y < atlas.height {
        break;
    }

    return atlas;
}

#import "Basic";
#import "Math";
