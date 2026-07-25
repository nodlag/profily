shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

// Port of Graphy's GraphStandard.shader — MIT License.
// Copyright (c) 2018 Martin Pane (original Unity shader)
// Copyright (c) 2026 Javier Garrido (nodlag) (Godot port)
// Differences vs the Unity original:
//  - UV.y is flipped (Godot has y=0 at the top).
//  - The array index is clamped (Unity reads out of bounds at x=1).
//  - Premultiplied alpha is declared via render_mode instead of
//    "Blend One OneMinusSrcAlpha".
// The array size is fixed at compile time; graph_light.gdshader is the same
// shader with a 128-entry array for old/mobile GPUs (like Graphy's "Mobile").

uniform float graph_values[512];
uniform int graph_values_length = 512;
uniform float average = 0.0;
uniform float good_threshold = 0.5;
uniform float caution_threshold = 0.25;
uniform vec4 good_color : source_color = vec4(1.0);
uniform vec4 caution_color : source_color = vec4(1.0);
uniform vec4 critical_color : source_color = vec4(1.0);

void fragment() {
	vec4 color = COLOR; // ColorRect tint (white by default), like IN.color * _Color.
	float x_coord = UV.x;
	float y_coord = 1.0 - UV.y; // Unity: y=0 at the bottom.

	int index = clamp(int(x_coord * float(graph_values_length)), 0, min(graph_values_length - 1, 511));
	float graph_value = graph_values[index];

	// Width of each element of the graph.
	float increment = 1.0 / (float(graph_values_length) - 1.0);

	// Assign the corresponding color by threshold.
	if (graph_value > good_threshold) {
		color *= good_color;
	} else if (graph_value > caution_threshold) {
		color *= caution_color;
	} else {
		color *= critical_color;
	}

	// Point coloring: fill gradient below the line.
	if (graph_value - y_coord > increment * 4.0) {
		color.a *= y_coord * 0.3 / graph_value;
	}

	// Transparent above the current point value.
	if (y_coord > graph_value) {
		color.a = 0.0;
	}

	// Average white bar.
	if (y_coord < average && y_coord > average - 0.02) {
		color = vec4(1.0);
	}

	// Caution threshold bar.
	if (y_coord < caution_threshold && y_coord > caution_threshold - 0.02) {
		color = caution_color;
	}

	// Good threshold bar.
	if (y_coord < good_threshold && y_coord > good_threshold - 0.02) {
		color = good_color;
	}

	// Fade the alpha at the sides of the graph.
	if (x_coord < 0.03) {
		color.a *= 1.0 - (0.03 - x_coord) / 0.03;
	} else if (x_coord > 0.97) {
		color.a *= (1.0 - x_coord) / 0.03;
	}

	color.rgb *= color.a; // Premultiplied alpha, parity with the original.
	COLOR = color;
}
