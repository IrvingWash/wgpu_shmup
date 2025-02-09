package sam_window

import "core:strings"
import "vendor:glfw"

Window :: glfw.WindowHandle

@(private)
window: Window

init :: proc(width, height: u32, title: string, fullscreen := false) {
	is_initialized := glfw.Init()
	if !is_initialized {
		panic("Failed to initialize GLFW")
	}

	glfw.WindowHint(glfw.RESIZABLE, false)
	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)

	raw_title := strings.clone_to_cstring(title)
	defer delete(raw_title)

	if !fullscreen {
		window = glfw.CreateWindow(i32(width), i32(height), raw_title, nil, nil)
	} else {
		monitor := glfw.GetPrimaryMonitor()

		window = glfw.CreateWindow(i32(width), i32(height), raw_title, monitor, nil)
	}
}

get_window :: proc() -> Window {
	return window
}

get_size :: proc() -> struct {
		width:  u32,
		height: u32,
	} {
	width, height := glfw.GetWindowSize(window)

	return {width = u32(width), height = u32(height)}
}

poll_events :: proc() {
	glfw.PollEvents()
}

window_should_close :: proc() -> bool {
	return bool(glfw.WindowShouldClose(window))
}

destroy :: proc() {
	glfw.DestroyWindow(window)
	glfw.Terminate()
}

