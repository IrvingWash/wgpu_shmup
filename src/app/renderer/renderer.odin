package sam_renderer

import "../window"
import "base:runtime"
import "core:fmt"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

@(private)
Renderer :: struct {
	surface:     wgpu.Surface,
	clear_color: wgpu.Color,
	device:      wgpu.Device,
	queue:       wgpu.Queue,
	draw_ctx:    Maybe(Draw_Context),
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
	window_size := window.get_size()
	wgpu.SurfaceConfigure(
		renderer.surface,
		&wgpu.SurfaceConfiguration {
			device = renderer.device,
			usage = {.RenderAttachment},
			width = window_size.width,
			height = window_size.height,
			format = .BGRA8Unorm,
			alphaMode = .Auto,
			presentMode = .Fifo,
		},
	)
}

start_drawing :: proc() {
	texture_view := wgpu.TextureCreateView(
		wgpu.SurfaceGetCurrentTexture(renderer.surface).texture,
		&wgpu.TextureViewDescriptor {
			format = .BGRA8Unorm,
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
	wgpu.SurfaceUnconfigure(renderer.surface)
	wgpu.QueueRelease(renderer.queue)
	wgpu.DeviceRelease(renderer.device)
	wgpu.SurfaceRelease(renderer.surface)
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

