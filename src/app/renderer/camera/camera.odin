package sam_renderer_camera

import "core:math/linalg"

Camera :: struct {
	projectionViewMatrix: linalg.Matrix4x4f32,
}

create_camera :: proc(width, height: u32) -> Camera {
	projection := linalg.matrix_ortho3d_f32(
		left = 0,
		right = f32(width),
		bottom = f32(height),
		top = 0,
		near = -1,
		far = 1,
		flip_z_axis = true,
	)

	view := linalg.matrix4_look_at(
		linalg.Vector3f32{0, 0, 1}, // eye
		linalg.Vector3f32{0, 0, 0}, // centre
		linalg.Vector3f32{0, 1, 0}, // up
		flip_z_axis = true,
	)

	return Camera{projectionViewMatrix = linalg.matrix_mul(projection, view)}
}

update_camera :: proc(camera: Camera) {}

