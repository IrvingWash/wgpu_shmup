package main

import "app"

main :: proc() {
	app.init()

	app.run()

	app.destroy()
}

