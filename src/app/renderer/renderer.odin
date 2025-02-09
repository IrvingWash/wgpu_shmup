package sam_renderer

import "../window"
import "base:runtime"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "geometry"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

@(private)
Renderer :: struct {
	surface:           wgpu.Surface,
	clear_color:       wgpu.Color,
	device:            wgpu.Device,
	queue:             wgpu.Queue,
	texture_format:    wgpu.TextureFormat,
	render_pipeline:   wgpu.RenderPipeline,
	draw_ctx:          Maybe(Draw_Context),
	positions_buffer:  wgpu.Buffer,
	colors_buffer:     wgpu.Buffer,
	tex_coords_buffer: wgpu.Buffer,
}

@(private = "file")
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

	// Render Pipeline
	renderer.render_pipeline = create_render_pipeline()

	// Geometry
	quad := geometry.create_quad()

	renderer.positions_buffer = create_buffer(quad.positions[:])
	renderer.colors_buffer = create_buffer(quad.colors[:])
	renderer.tex_coords_buffer = create_buffer(quad.tex_coords[:])
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
		renderer.positions_buffer,
		0,
		wgpu.BufferGetSize(renderer.positions_buffer),
	)
	wgpu.RenderPassEncoderSetVertexBuffer(
		draw_ctx.render_pass_encoder,
		1,
		renderer.colors_buffer,
		0,
		wgpu.BufferGetSize(renderer.colors_buffer),
	)

	wgpu.RenderPassEncoderDraw(draw_ctx.render_pass_encoder, 6, 1, 0, 0)
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
	wgpu.RenderPipelineRelease(renderer.render_pipeline)
	wgpu.SurfaceUnconfigure(renderer.surface)
	wgpu.QueueRelease(renderer.queue)
	wgpu.DeviceRelease(renderer.device)
	wgpu.SurfaceRelease(renderer.surface)
}

@(private = "file")
create_buffer :: proc(data: []f32) -> wgpu.Buffer {
	buffer := wgpu.DeviceCreateBuffer(
		renderer.device,
		&wgpu.BufferDescriptor{size = u64(slice.size(data)), usage = {.CopyDst, .Vertex}},
	)

	wgpu.QueueWriteBuffer(
		renderer.queue,
		buffer,
		0,
		raw_data(data),
		uint(wgpu.BufferGetSize(buffer)),
	)

	return buffer
}

@(private = "file")
configure_surface :: proc "c" (width, height: u32) {
	wgpu.SurfaceConfigure(
		renderer.surface,
		&wgpu.SurfaceConfiguration {
			device = renderer.device,
			usage = {.RenderAttachment},
			width = width,
			height = height,
			format = renderer.texture_format,
			alphaMode = .Auto,
			presentMode = .Fifo,
		},
	)
}

@(private = "file")
resize :: proc "c" (window: window.Window, width: i32, height: i32) {
	configure_surface(u32(width), u32(height))
}

@(private = "file")
// TODO: prepare_model?
create_render_pipeline :: proc() -> wgpu.RenderPipeline {
	shader_path := "src/app/shaders/shader.wgsl"

	shader_source_bytes, ok := os.read_entire_file(shader_path)
	if !ok {
		fmt.panicf("Failed to read file at %", shader_path)
	}

	shader_source := strings.clone_to_cstring(string(shader_source_bytes))
	delete(shader_source_bytes)
	defer delete(shader_source)

	shader_module := wgpu.DeviceCreateShaderModule(
		renderer.device,
		&wgpu.ShaderModuleDescriptor {
			nextInChain = &wgpu.ShaderModuleWGSLDescriptor {
				sType = .ShaderModuleWGSLDescriptor,
				code = shader_source,
			},
		},
	)
	defer wgpu.ShaderModuleRelease(shader_module)

	buffer_layouts := [?]wgpu.VertexBufferLayout {
		wgpu.VertexBufferLayout {
			arrayStride = 2 * size_of(f32),
			stepMode = .Vertex,
			attributeCount = 1,
			attributes = &wgpu.VertexAttribute {
				format = .Float32x2,
				offset = 0,
				shaderLocation = 0,
			},
		},
		wgpu.VertexBufferLayout {
			arrayStride = 3 * size_of(f32),
			stepMode = .Vertex,
			attributeCount = 1,
			attributes = &wgpu.VertexAttribute {
				format = .Float32x3,
				offset = 0,
				shaderLocation = 1,
			},
		},
	}

	return wgpu.DeviceCreateRenderPipeline(
		renderer.device,
		&wgpu.RenderPipelineDescriptor {
			vertex = wgpu.VertexState {
				module = shader_module,
				entryPoint = "vsMain",
				bufferCount = len(buffer_layouts),
				buffers = raw_data(buffer_layouts[:]),
			},
			primitive = wgpu.PrimitiveState {
				topology = .TriangleList,
				cullMode = .Back,
				frontFace = .CCW,
				stripIndexFormat = .Undefined,
			},
			fragment = &wgpu.FragmentState {
				module = shader_module,
				entryPoint = "fsMain",
				targetCount = 1,
				targets = &wgpu.ColorTargetState {
					format = renderer.texture_format,
					writeMask = wgpu.ColorWriteMaskFlags_All,
					blend = &wgpu.BlendState {
						color = wgpu.BlendComponent {
							srcFactor = .SrcAlpha,
							dstFactor = .OneMinusSrcAlpha,
							operation = .Add,
						},
						alpha = wgpu.BlendComponent {
							srcFactor = .Zero,
							dstFactor = .One,
							operation = .Add,
						},
					},
				},
			},
			multisample = wgpu.MultisampleState{count = 1, mask = ~u32(0)},
		},
	)
}

@(private = "file")
request_adapter :: proc(instance: wgpu.Instance) -> wgpu.Adapter {
	Out :: struct {
		ctx:     runtime.Context,
		adapter: wgpu.Adapter,
	}

	out := Out {
		ctx = context,
	}

	wgpu.InstanceRequestAdapter(
		instance,
		&wgpu.RequestAdapterOptions {
			compatibleSurface = renderer.surface,
			powerPreference = .HighPerformance,
			forceFallbackAdapter = false,
		},
		proc "c" (
			status: wgpu.RequestAdapterStatus,
			adapter: wgpu.Adapter,
			message: cstring,
			userdata: rawptr,
		) {
			data := cast(^Out)userdata
			context = data.ctx

			if status != .Success {
				fmt.panicf("Failed to request WGPU Adapter: %", message)
			}

			data.adapter = adapter
		},
		&out,
	)

	return out.adapter
}

@(private = "file")
request_device :: proc(adapter: wgpu.Adapter) -> wgpu.Device {
	Out :: struct {
		ctx:    runtime.Context,
		device: wgpu.Device,
	}

	out := Out {
		ctx = context,
	}

	wgpu.AdapterRequestDevice(
		adapter,
		&wgpu.DeviceDescriptor{},
		proc "c" (
			status: wgpu.RequestDeviceStatus,
			device: wgpu.Device,
			message: cstring,
			userdata: rawptr,
		) {
			data := cast(^Out)userdata
			context = data.ctx

			if status != .Success {
				fmt.panicf("Failed to request WGPU Device: %", message)
			}

			data.device = device
		},
		&out,
	)

	return out.device
}

