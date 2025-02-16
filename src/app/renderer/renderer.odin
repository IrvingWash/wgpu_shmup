package sam_renderer

import "../window"
import "camera"
import "core:math/linalg"
import "geometry"
import "texture"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

@(private)
Renderer :: struct {
	surface:                           wgpu.Surface,
	clear_color:                       wgpu.Color,
	device:                            wgpu.Device,
	queue:                             wgpu.Queue,
	texture_format:                    wgpu.TextureFormat,
	render_pipeline:                   wgpu.RenderPipeline,
	draw_ctx:                          Maybe(Draw_Context),
	vertex_buffer:                     wgpu.Buffer,
	index_buffer:                      wgpu.Buffer,
	projection_view_matrix_buffer:     wgpu.Buffer,
	texture_bind_group:                wgpu.BindGroup,
	proejection_view_matrix_bind_grup: wgpu.BindGroup,
	test_texture:                      texture.Texture,
	camera:                            camera.Camera,
}

@(private)
Draw_Context :: struct {
	command_encoder:     wgpu.CommandEncoder,
	texture_view:        wgpu.TextureView,
	render_pass_encoder: wgpu.RenderPassEncoder,
}

@(private)
renderer: Renderer

init :: proc(target_window: window.Window, clear_color := [4]f64{0, 0, 1, 1}) {
	renderer.clear_color = clear_color

	// Instance
	instance := wgpu.CreateInstance()
	defer wgpu.InstanceRelease(instance)

	// Surface
	renderer.surface = glfwglue.GetSurface(instance, target_window)

	// Adapter
	adapter := request_adapter(instance)
	defer wgpu.AdapterRelease(adapter)

	// Device
	renderer.device = request_device(adapter)

	// Queue
	renderer.queue = wgpu.DeviceGetQueue(renderer.device)

	// Surface Configuration
	renderer.texture_format = wgpu.TextureFormat.BGRA8Unorm
	window_size := window.get_size()
	configure_surface(window_size.width, window_size.height)

	window.set_resize_callback(resize)

	// Texture
	renderer.test_texture = texture.create(
		renderer.device,
		renderer.queue,
		"src/app/textures/ship_blue.png",
		.RGBA8Unorm,
	)

	// Camera
	renderer.camera = camera.create_camera(window_size.width, window_size.height)
	projection_view_matrix_data := linalg.matrix_flatten(renderer.camera.projectionViewMatrix)

	// Geometry
	quad := geometry.create_quad()

	// Buffers
	renderer.vertex_buffer = create_buffer(quad.vertices[:])
	renderer.index_buffer = create_index_buffer(quad.indices[:])
	renderer.projection_view_matrix_buffer = create_uniform_buffer(projection_view_matrix_data[:])

	// Render Pipeline
	renderer.render_pipeline = create_render_pipeline()
}

start_drawing :: proc() {
	current_texture := wgpu.SurfaceGetCurrentTexture(renderer.surface)

	texture_view := wgpu.TextureCreateView(
		current_texture.texture,
		&wgpu.TextureViewDescriptor {
			format = wgpu.TextureGetFormat(current_texture.texture),
			aspect = .All,
			dimension = ._2D,
			mipLevelCount = 1,
			arrayLayerCount = 1,
		},
	)

	command_encoder := wgpu.DeviceCreateCommandEncoder(renderer.device)

	render_pass_encoder := wgpu.CommandEncoderBeginRenderPass(
		command_encoder,
		&wgpu.RenderPassDescriptor {
			colorAttachmentCount = 1,
			colorAttachments = &wgpu.RenderPassColorAttachment {
				view = texture_view,
				loadOp = .Clear,
				storeOp = .Store,
				clearValue = renderer.clear_color,
			},
		},
	)

	renderer.draw_ctx = Draw_Context {
		command_encoder     = command_encoder,
		texture_view        = texture_view,
		render_pass_encoder = render_pass_encoder,
	}
}

draw :: proc() {
	draw_ctx, ok := &renderer.draw_ctx.?
	if !ok {
		panic("Drawing without starting")
	}

	wgpu.RenderPassEncoderSetPipeline(draw_ctx.render_pass_encoder, renderer.render_pipeline)
	wgpu.RenderPassEncoderSetVertexBuffer(
		draw_ctx.render_pass_encoder,
		0,
		renderer.vertex_buffer,
		0,
		wgpu.BufferGetSize(renderer.vertex_buffer),
	)
	wgpu.RenderPassEncoderSetBindGroup(
		draw_ctx.render_pass_encoder,
		0,
		renderer.proejection_view_matrix_bind_grup,
	)
	wgpu.RenderPassEncoderSetBindGroup(
		draw_ctx.render_pass_encoder,
		1,
		renderer.texture_bind_group,
	)
	wgpu.RenderPassEncoderSetIndexBuffer(
		draw_ctx.render_pass_encoder,
		renderer.index_buffer,
		.Uint16,
		0,
		wgpu.BufferGetSize(renderer.index_buffer),
	)

	wgpu.RenderPassEncoderDrawIndexed(draw_ctx.render_pass_encoder, 6, 1, 0, 0, 0)
}

finish_drawing :: proc() {
	draw_ctx, ok := &renderer.draw_ctx.?
	if !ok {
		panic("Finished drawing without starting")
	}

	wgpu.RenderPassEncoderEnd(draw_ctx.render_pass_encoder)
	wgpu.RenderPassEncoderRelease(draw_ctx.render_pass_encoder)

	command_buffer := wgpu.CommandEncoderFinish(draw_ctx.command_encoder)

	wgpu.CommandEncoderRelease(draw_ctx.command_encoder)

	wgpu.QueueSubmit(renderer.queue, {command_buffer})

	wgpu.CommandBufferRelease(command_buffer)
	wgpu.TextureViewRelease(draw_ctx.texture_view)

	renderer.draw_ctx = nil

	wgpu.SurfacePresent(renderer.surface)
}

destroy :: proc() {
	wgpu.BufferRelease(renderer.projection_view_matrix_buffer)
	wgpu.BindGroupRelease(renderer.proejection_view_matrix_bind_grup)
	texture.destroy(renderer.test_texture)
	wgpu.BindGroupRelease(renderer.texture_bind_group)
	wgpu.BufferRelease(renderer.vertex_buffer)
	wgpu.RenderPipelineRelease(renderer.render_pipeline)
	wgpu.SurfaceUnconfigure(renderer.surface)
	wgpu.QueueRelease(renderer.queue)
	wgpu.DeviceRelease(renderer.device)
	wgpu.SurfaceRelease(renderer.surface)
}

