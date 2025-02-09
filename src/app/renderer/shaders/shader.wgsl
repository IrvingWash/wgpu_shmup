struct VertexOut {
	@builtin(position) position: vec4f,
	@location(0) color: vec4f,
	@location(1) texCoords: vec2f,
}

@vertex
fn vsMain(
	@location(0) position: vec2f,
	@location(1) color: vec3f,
	@location(2) texCoords: vec2f
) -> VertexOut {
	var out: VertexOut;

	out.position = vec4f(position, 0, 1);
	out.color = vec4f(color, 1);
	out.texCoords = texCoords;

	return out;
}

@group(0) @binding(0)
var textureSampler: sampler;
@group(0) @binding(1)
var texture: texture_2d<f32>;

@fragment
fn fsMain(data: VertexOut) -> @location(0) vec4f {
	var textureColor = textureSample(texture, textureSampler, data.texCoords);

	return data.color * textureColor;
}
