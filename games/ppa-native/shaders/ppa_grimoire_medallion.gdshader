shader_type canvas_item;
render_mode unshaded;
uniform vec2 crop_fraction = vec2(0.64, 0.43);

void fragment() {
    // Sample only the round central artwork. UV is the LOCAL icon's 0..1
    // coordinates; sampling the intact full book avoids AtlasTexture UV drift.
    vec2 source_uv = vec2(0.5) + (UV - vec2(0.5)) * crop_fraction;
    vec4 pixel = texture(TEXTURE, source_uv);
    float radius = length((UV - vec2(0.5)) * 2.0);
    pixel.a *= 1.0 - smoothstep(0.92, 1.0, radius);
    COLOR = pixel;
}
