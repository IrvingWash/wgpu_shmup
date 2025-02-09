struct VertexOut {
    @builtin(position) position: vec4f,
    @location(0) color: vec4f,
}

@vertex
fn vsMain(@builtin(vertex_index) vertexIndex: u32) -> VertexOut {
    var out: VertexOut;

    var pos = array(
        vec2f(-0.5, -0.5), // bottom left
        vec2f(0.5, -0.5), // bottom right
        vec2f(0.5, 0.5), // top right
    );

    out.position = vec4f(pos[vertexIndex], 0, 1);
    out.color = vec4f(1, 0, 0, 1);

    return out;
}

@fragment
fn fsMain(@location(0) color: vec4f) -> @location(0) vec4f {
    return color;
}
