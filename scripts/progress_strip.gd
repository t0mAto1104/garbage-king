class_name StompProgress
extends Control

var value := 0.0:
	set(next):
		value = clampf(next,0,100)
		queue_redraw()
var fill_color := Color("c7d597")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("504f48"))
	draw_rect(Rect2(Vector2.ZERO,Vector2(size.x*value/100,size.y)),fill_color)
