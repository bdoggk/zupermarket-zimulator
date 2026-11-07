class_name StarBar
extends HBoxContainer
## The store's rating as five stars (full, half or empty), for the top bar
## and the Goals app (0.18). Point at it for the number and what it does.

const FULL := preload("res://assets/sprites/star_full.png")
const HALF := preload("res://assets/sprites/star_half.png")
const EMPTY := preload("res://assets/sprites/star_empty.png")

var stars: Array[TextureRect] = []
var _shown := -1.0


func _init(px := 16) -> void:
	add_theme_constant_override("separation", 1)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in 5:
		var t := UI.icon(EMPTY, Vector2(px, px))
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(t)
		stars.append(t)


func _process(_delta: float) -> void:
	show_rating(Game.rating.shown())


func show_rating(v: float) -> void:
	if is_equal_approx(v, _shown):
		return
	_shown = v
	for i in 5:
		stars[i].texture = FULL if v >= i + 1.0 else (HALF if v >= i + 0.5 else EMPTY)
	tooltip_text = "Store rating: %s (the last %d shoppers). Above 3 stars brings more shoppers, below 3 fewer. The computer's Goals app says why." % [StoreRating.words(v), StoreRating.WINDOW]
