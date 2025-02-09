package sam_app

import "fps_manager"
import "renderer"
import "window"

@(private)
App :: struct {}

@(private)
app: App

init :: proc() {
	window.init(WINDOW_WIDTH, WINDOW_HEIGHT, "Sam")
	renderer.init()
	fps_manager.init(TARGET_FPS)
}

run :: proc() {
	for !window.window_should_close() {
		window.poll_events()

		renderer.start_drawing()
		renderer.finish_drawing()
	}
}

destroy :: proc() {
	renderer.destroy()
	window.destroy()
}

