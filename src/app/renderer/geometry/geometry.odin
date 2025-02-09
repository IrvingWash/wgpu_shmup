package sam_renderer_geometry

Quad_Geometry :: struct {
	vertices: [28]f32,
	indices:  [6]u16,
}

create_quad :: proc() -> Quad_Geometry {
	quad: Quad_Geometry
	
	// odinfmt: disable
	quad.vertices = {
		// x, y,		r, g, b,	u, v
		-0.5, -0.5,		1, 1, 1,	0, 1,
		+0.5, -0.5,		1, 1, 1,	1, 1,
		+0.5, +0.5,		1, 1, 1,	1, 0,
		-0.5, +0.5,		1, 1, 1,	0, 0,
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

