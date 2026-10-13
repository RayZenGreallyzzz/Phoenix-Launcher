shader_type canvas_item;
render_mode unshaded;

void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    // Only the round middle emblem of the original grimoire cover.
    // Antialiased edge prevents squared-off book art on small skill buttons.
    float radius = length((UV - vec2(0.5)) * 2.0);
    pixel.a *= 1.0 - smoothstep(0.92, 1.0, radius);
    COLOR = pixel;
}
