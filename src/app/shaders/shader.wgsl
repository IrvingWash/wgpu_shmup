struct VertexOut {
    @builtin(position) position: vec4f,
    @location(0) color: vec4f,
}

@vertex
fn vsMain(@location(0) position: vec2f, @location(1) color: vec3f) -> VertexOut {
    var out: VertexOut;

    out.position = vec4f(position, 0, 1);
    out.color = vec4f(color, 1);

    return out;
}

@fragment
fn fsMain(@location(0) color: vec4f) -> @location(0) vec4f {
    return color;
}
