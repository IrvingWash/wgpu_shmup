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

start_drawing :: proc() {}

finish_drawing :: proc() {}

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

