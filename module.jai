

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

    return atlas;
}

#import "Basic";

