package sam_renderer_geometry

Quad_Geometry :: struct {
	vertices: [28]f32,
	indices:  [6]u16,
}

create_quad :: proc() -> Quad_Geometry {
	quad: Quad_Geometry

	x :: 100
	y :: 100
	w :: 112
	h :: 75
	
	// odinfmt: disable
	quad.vertices = {
		// x, y,		r, g, b,	u, v
		x, y + h,		1, 1, 1,	0, 1,
		x + w, y + h,	1, 1, 1,	1, 1,
		x + w, y,		1, 1, 1,	1, 0,
		x, y,   		1, 1, 1,	0, 0,
	}
	// odinfmt: enable

	
	// odinfmt: disable
	quad.indices = {
		0, 1, 2,
		2, 3, 0,
	}
	// odinfmt: enable

	return quad
}

