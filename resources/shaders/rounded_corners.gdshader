shader_type canvas_item;

// Reproduit les corner_radius_* (en pixels) d'un StyleBoxFlat pour une TextureRect.
uniform vec2 rect_size = vec2(135.0, 187.0);
uniform float radius_top_left = 0.0;
uniform float radius_top_right = 0.0;
uniform float radius_bottom_right = 0.0;
uniform float radius_bottom_left = 0.0;

void fragment() {
	vec2 pixel_pos = UV * rect_size;
	float max_radius = min(rect_size.x, rect_size.y) * 0.5;

	float tl = min(radius_top_left, max_radius);
	float tr = min(radius_top_right, max_radius);
	float br = min(radius_bottom_right, max_radius);
	float bl = min(radius_bottom_left, max_radius);

	bool outside_corner = false;

	if (pixel_pos.x < tl && pixel_pos.y < tl) {
		outside_corner = distance(pixel_pos, vec2(tl, tl)) > tl;
	} else if (pixel_pos.x > rect_size.x - tr && pixel_pos.y < tr) {
		outside_corner = distance(pixel_pos, vec2(rect_size.x - tr, tr)) > tr;
	} else if (pixel_pos.x > rect_size.x - br && pixel_pos.y > rect_size.y - br) {
		outside_corner = distance(pixel_pos, vec2(rect_size.x - br, rect_size.y - br)) > br;
	} else if (pixel_pos.x < bl && pixel_pos.y > rect_size.y - bl) {
		outside_corner = distance(pixel_pos, vec2(bl, rect_size.y - bl)) > bl;
	}

	if (outside_corner) {
		discard;
	}

	COLOR = texture(TEXTURE, UV);
}
