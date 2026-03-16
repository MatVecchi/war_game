shader_type canvas_item;

void fragment() {
	// Called for every vertex the material is visible on.
	vec4 t = texture(TEXTURE, UV);
	t.a -= t.r;
	COLOR = t;
}
