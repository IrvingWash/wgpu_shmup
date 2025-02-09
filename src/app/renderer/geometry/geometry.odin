package sam_renderer_geometry

Quad_Geometry :: struct {
	positions:  [8]f32,
	colors:     [12]f32,
	tex_coords: [8]f32,
	indices:    [6]u16,
}

create_quad :: proc() -> Quad_Geometry {
	quad: Quad_Geometry
	
	// odinfmt: disable
	quad.positions = {
		-0.5, -0.5,
		0.5, -0.5,
		0.5, 0.5,
		-0.5, 0.5,
	}
	// odinfmt: enable

	
	// odinfmt: disable
	quad.colors = {
		1, 1, 1,
		1, 1, 1,
		1, 1, 1,
		1, 1, 1,
	}
	// odinfmt: enable

	
	// odinfmt: disable
	quad.tex_coords = {
		0, 1,
		1, 1,
		1, 0,
		0, 0,
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
