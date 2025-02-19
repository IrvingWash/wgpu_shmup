package sam_renderer

import "../window"
import "base:runtime"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "math"
import "vendor:wgpu"

@(private)
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

@(private)
create_index_buffer :: proc(data: []u16) -> wgpu.Buffer {
	buffer := wgpu.DeviceCreateBuffer(
		renderer.device,
		&wgpu.BufferDescriptor {
			size = u64(math.ceil_to_multiple(slice.size(data), 4)),
			usage = {.CopyDst, .Index},
		},
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

@(private)
create_uniform_buffer :: proc(data: []f32) -> wgpu.Buffer {
	buffer := wgpu.DeviceCreateBuffer(
		renderer.device,
		&wgpu.BufferDescriptor{size = u64(slice.size(data[:])), usage = {.CopyDst, .Uniform}},
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

@(private)
// TODO: prepare_model?
create_render_pipeline :: proc() -> wgpu.RenderPipeline {
	shader_path := "src/app/renderer/shaders/shader.wgsl"

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

	texture_bind_group_layout_entries := [?]wgpu.BindGroupLayoutEntry {
		// Sampler
		wgpu.BindGroupLayoutEntry {
			binding = 0,
			visibility = {.Fragment},
			sampler = wgpu.SamplerBindingLayout{type = .Filtering},
		},
		// Texture
		wgpu.BindGroupLayoutEntry {
			binding = 1,
			visibility = {.Fragment},
			texture = wgpu.TextureBindingLayout {
				sampleType = .Float,
				multisampled = false,
				viewDimension = ._2D,
			},
		},
	}

	texture_bind_group_layout := wgpu.DeviceCreateBindGroupLayout(
		renderer.device,
		&wgpu.BindGroupLayoutDescriptor {
			entryCount = len(texture_bind_group_layout_entries),
			entries = raw_data(texture_bind_group_layout_entries[:]),
		},
	)
	defer wgpu.BindGroupLayoutRelease(texture_bind_group_layout)

	texture_bind_group_entries := [?]wgpu.BindGroupEntry {
		wgpu.BindGroupEntry{binding = 0, sampler = renderer.test_texture.sampler},
		wgpu.BindGroupEntry {
			binding     = 1,
			textureView = wgpu.TextureCreateView(renderer.test_texture.texture), // TODO: Release
		},
	}

	renderer.texture_bind_group = wgpu.DeviceCreateBindGroup(
		renderer.device,
		&wgpu.BindGroupDescriptor {
			layout = texture_bind_group_layout,
			entryCount = len(texture_bind_group_entries),
			entries = raw_data(texture_bind_group_entries[:]),
		},
	)

	projection_view_matrix_bind_group_layout := wgpu.DeviceCreateBindGroupLayout(
		renderer.device,
		&wgpu.BindGroupLayoutDescriptor {
			entryCount = 1,
			entries = &wgpu.BindGroupLayoutEntry {
				binding = 0,
				visibility = {.Vertex},
				buffer = wgpu.BufferBindingLayout {
					type = .Uniform,
					hasDynamicOffset = false,
					minBindingSize = size_of(f32) * 16,
				},
			},
		},
	)
	defer wgpu.BindGroupLayoutRelease(projection_view_matrix_bind_group_layout)

	renderer.proejection_view_matrix_bind_grup = wgpu.DeviceCreateBindGroup(
		renderer.device,
		&wgpu.BindGroupDescriptor {
			layout = projection_view_matrix_bind_group_layout,
			entryCount = 1,
			entries = &wgpu.BindGroupEntry {
				binding = 0,
				buffer = renderer.projection_view_matrix_buffer,
				offset = 0,
				size = wgpu.BufferGetSize(renderer.projection_view_matrix_buffer),
			},
		},
	)

	bind_group_layouts := [?]wgpu.BindGroupLayout {
		projection_view_matrix_bind_group_layout,
		texture_bind_group_layout,
	}

	pipeline_layout := wgpu.DeviceCreatePipelineLayout(
		renderer.device,
		&wgpu.PipelineLayoutDescriptor {
			bindGroupLayoutCount = len(bind_group_layouts),
			bindGroupLayouts = raw_data(bind_group_layouts[:]),
		},
	)
	defer wgpu.PipelineLayoutRelease(pipeline_layout)

	vertex_attributes := [?]wgpu.VertexAttribute {
		wgpu.VertexAttribute{format = .Float32x2, offset = 0, shaderLocation = 0},
		wgpu.VertexAttribute{format = .Float32x3, offset = 2 * size_of(f32), shaderLocation = 1},
		wgpu.VertexAttribute{format = .Float32x2, offset = 5 * size_of(f32), shaderLocation = 2},
	}

	return wgpu.DeviceCreateRenderPipeline(
		renderer.device,
		&wgpu.RenderPipelineDescriptor {
			vertex = wgpu.VertexState {
				module = shader_module,
				entryPoint = "vsMain",
				bufferCount = 1,
				buffers = &wgpu.VertexBufferLayout {
					arrayStride = 7 * size_of(f32),
					stepMode = .Vertex,
					attributeCount = len(vertex_attributes),
					attributes = raw_data(vertex_attributes[:]),
				},
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
			layout = pipeline_layout,
		},
	)
}

@(private)
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

@(private)
resize :: proc "c" (window: window.Window, width: i32, height: i32) {
	configure_surface(u32(width), u32(height))
}

@(private)
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

@(private)
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

