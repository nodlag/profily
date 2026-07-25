extends Control
## Port of G_SafeArea: keeps the modules inside the display safe area
## (notch, rounded corners, system bars). (Graphy, MIT (c) 2018 Martin Pane.)
## Godot port (c) 2026 Javier Garrido (nodlag), MIT.
##
## It does not use anchors: the manager assigns its rect in canvas coordinates
## already compensated by ui_scale. Insets are computed as window ratios so
## they survive any stretch mode of the host project.


## Fits this control to the safe area inside a canvas of the given size.
func apply(canvas_size: Vector2) -> void:
	var rect := Rect2(Vector2.ZERO, canvas_size)
	if DisplayServer.get_name() != "headless":
		var window_size := Vector2(DisplayServer.window_get_size())
		if window_size.x > 0.0 and window_size.y > 0.0:
			var window_pos := Vector2(DisplayServer.window_get_position())
			var safe := DisplayServer.get_display_safe_area()
			var left := clampf((safe.position.x - window_pos.x) / window_size.x, 0.0, 1.0)
			var top := clampf((safe.position.y - window_pos.y) / window_size.y, 0.0, 1.0)
			var right := clampf((window_pos.x + window_size.x - safe.end.x) / window_size.x, 0.0, 1.0)
			var bottom := clampf((window_pos.y + window_size.y - safe.end.y) / window_size.y, 0.0, 1.0)
			rect.position = canvas_size * Vector2(left, top)
			rect.size = canvas_size * Vector2(
				maxf(0.0, 1.0 - left - right),
				maxf(0.0, 1.0 - top - bottom)
			)
	position = rect.position
	size = rect.size
