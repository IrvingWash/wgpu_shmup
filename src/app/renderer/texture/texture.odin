package sam_renderer_texture

import "core:fmt"
import img "core:image"
import "core:image/png"
import "core:slice"
import "vendor:wgpu"

Texture :: struct {
	texture: wgpu.Texture,
	sampler: wgpu.Sampler,
}

create :: proc(
	device: wgpu.Device,
	queue: wgpu.Queue,
	image_path: string,
	format: wgpu.TextureFormat,
	antialias := false,
	origin := [3]u32{0, 0, 0},
) -> Texture {
	image := load_image(image_path)
	defer img.destroy(image)

	texture_descriptor := wgpu.TextureDescriptor {
		size = wgpu.Extent3D {
			width = u32(image.width),
			height = u32(image.height),
			depthOrArrayLayers = 1,
		},
		format = format,
		usage = {.CopyDst, .TextureBinding},
		dimension = ._2D,
		sampleCount = 1,
		mipLevelCount = 1,
	}

	texture := wgpu.DeviceCreateTexture(device, &texture_descriptor)

	wgpu.QueueWriteTexture(
		queue,
		destination = &wgpu.ImageCopyTexture {
			texture = texture,
			mipLevel = 0,
			origin = wgpu.Origin3D{origin.x, origin.y, origin.z},
			aspect = .All,
		},
		data = raw_data(image.pixels.buf),
		dataSize = uint(slice.size(image.pixels.buf[:])),
		dataLayout = &wgpu.TextureDataLayout {
			offset       = 0,
			bytesPerRow  = 4 * texture_descriptor.size.width, // TODO: Why 4?
			rowsPerImage = texture_descriptor.size.height,
		},
		writeSize = &texture_descriptor.size,
	)

	sampler := wgpu.DeviceCreateSampler(
		device,
		&wgpu.SamplerDescriptor {
			addressModeU = .ClampToEdge,
			addressModeV = .ClampToEdge,
			addressModeW = .ClampToEdge,
			magFilter = antialias ? .Linear : .Nearest,
			minFilter = .Linear,
			mipmapFilter = .Linear,
			lodMinClamp = 0,
			lodMaxClamp = 1,
			compare = .Undefined,
			maxAnisotropy = 1,
		},
	)

	return Texture{texture = texture, sampler = sampler}
}

destroy :: proc(texture: Texture) {
	wgpu.TextureRelease(texture.texture)
	wgpu.SamplerRelease(texture.sampler)
}

@(private)
load_image :: proc(path: string) -> ^img.Image {
	image, error := png.load_from_file(path)

	if error != nil {
		fmt.panicf("Failed to load image at: %", path)
	}

	return image
}
