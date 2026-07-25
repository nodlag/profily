shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

// Light variant of graph_full.gdshader with a 128-entry array, for GPUs with
// tight uniform limits (parity with Graphy's GraphMobile.shader, which only
// differs from GraphStandard in the array size). See graph_full.gdshader for
// the algorithm documentation. MIT License.
// Copyright (c) 2018 Martin Pane (original Unity shader)
// Copyright (c) 2026 Javier Garrido (nodlag) (Godot port)

uniform float graph_values[128];
uniform int graph_values_length = 128;
uniform float average = 0.0;
uniform float good_threshold = 0.5;
uniform float caution_threshold = 0.25;
uniform vec4 good_color : source_color = vec4(1.0);
uniform vec4 caution_color : source_color = vec4(1.0);
uniform vec4 critical_color : source_color = vec4(1.0);

void fragment() {
	vec4 color = COLOR;
	float x_coord = UV.x;
	float y_coord = 1.0 - UV.y;

	int index = clamp(int(x_coord * float(graph_values_length)), 0, min(graph_values_length - 1, 127));
	float graph_value = graph_values[index];

	float increment = 1.0 / (float(graph_values_length) - 1.0);

	if (graph_value > good_threshold) {
		color *= good_color;
	} else if (graph_value > caution_threshold) {
		color *= caution_color;
	} else {
		color *= critical_color;
	}

	if (graph_value - y_coord > increment * 4.0) {
		color.a *= y_coord * 0.3 / graph_value;
	}

	if (y_coord > graph_value) {
		color.a = 0.0;
	}

	if (y_coord < average && y_coord > average - 0.02) {
		color = vec4(1.0);
	}

	if (y_coord < caution_threshold && y_coord > caution_threshold - 0.02) {
		color = caution_color;
	}

	if (y_coord < good_threshold && y_coord > good_threshold - 0.02) {
		color = good_color;
	}

	if (x_coord < 0.03) {
		color.a *= 1.0 - (0.03 - x_coord) / 0.03;
	} else if (x_coord > 0.97) {
		color.a *= (1.0 - x_coord) / 0.03;
	}

	color.rgb *= color.a;
	COLOR = color;
}
