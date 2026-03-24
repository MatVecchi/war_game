shader_type canvas_item;

uniform vec4 color_background : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform vec4 color_big : source_color = vec4(0.0, 0.0, 0.0, 0.3);
uniform vec4 color_small : source_color = vec4(0.0, 0.0, 0.0, 0.0);

uniform int circle_count = 0;
uniform vec2 pos[64];
uniform float small_radius[64];
uniform float big_radius_multiplier;

void fragment() {
    vec2 p = UV * vec2(textureSize(TEXTURE, 0));

    bool inside_big = false;
    bool inside_small = false;

    for (int i = 0; i < circle_count; i++) {
        float d = distance(p, pos[i]);
        if (d < small_radius[i]) {
            inside_small = true;
        }
    }

    for (int i = 0; i < circle_count; i++) {
        float d = distance(p, pos[i]);
        if (d < small_radius[i] * big_radius_multiplier) {
            inside_big = true;
        }
    }

    vec4 col = color_background;

    if (inside_small) {
        col = color_small; 
    } else if (inside_big) {
        col = color_big;
    }

    COLOR = col;
}


