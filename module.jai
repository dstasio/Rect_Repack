

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


    Mask_Bucket_Type     :: u32;
    BITS_PER_MASK_BUCKET :: size_of(Mask_Bucket_Type) * 8;
    rect_w := 20;
    rect_h := 25;

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

    print("Masks for a rect of width %\n", rect_w);
    push_context {
        context.print_style.default_format_int.base           = 2;
        context.print_style.default_format_int.minimum_digits = BITS_PER_MASK_BUCKET;
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
