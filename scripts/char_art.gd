class_name CharArt
## Bits of character art made at runtime (0.18).
##
## Walking: every character sprite is a single picture standing still. To
## walk, walk_frames() makes two more from it, one with each leg lifted a
## pixel (the bottom of the sprite, split down the middle), and walk() picks
## between the three as they bob along: left foot up, both down, right foot
## up, both down. Sprites without legs to lift (ghosts float, crawlers
## crawl) just bob.
##
## Emotes: the little bubbles over a shopper's head (heart, angry, ?...).

const LEG_ROWS := 9  # how far up from the feet the legs go
const SOLID := 0.4  # alpha: anything fainter is the shadow on the ground, which stays put
const LIFT_AT := 0.35  # sin(the walk's phase) past this: a foot's up
const EMOTES := {
	"heart": preload("res://assets/sprites/emote_heart.png"),
	"angry": preload("res://assets/sprites/emote_angry.png"),
	"question": preload("res://assets/sprites/emote_question.png"),
	"money": preload("res://assets/sprites/emote_money.png"),
	"zzz": preload("res://assets/sprites/emote_zzz.png"),
	"star": preload("res://assets/sprites/emote_star.png"),
}

static var _frames := {}  # texture rid -> [left foot up, right foot up] (or [] if it has no legs to lift)


## The two walking frames for `tex` (or [] if it can't walk on legs).
static func walk_frames(tex: Texture2D) -> Array:
	if tex == null:
		return []
	var key := tex.get_rid()
	if _frames.has(key):
		return _frames[key]
	var made: Array = []
	if tex.get_height() >= 30 and not tex.resource_path.contains("ghost"):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var feet := _feet(img)
		if feet >= LEG_ROWS:
			made = [ImageTexture.create_from_image(_lift(img, feet, true)), ImageTexture.create_from_image(_lift(img, feet, false))]
	_frames[key] = made
	return made


## The lowest row with something solid in it (the soles of their feet).
static func _feet(img: Image) -> int:
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > SOLID:
				return y
	return -1


## `img` with one leg (the left half of the bottom LEG_ROWS rows, or the
## right) a pixel higher.
static func _lift(img: Image, feet: int, left: bool) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var mid := floori(w / 2.0)
	var top := feet - LEG_ROWS
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:  # the shadow (faint) stays where it is; the body's drawn over it
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a <= SOLID:
				out.set_pixel(x, y, c)
			else:
				var leg := y > top and ((x < mid) if left else (x >= mid))
				if not leg:
					body.set_pixel(x, y, c)
	for y in range(top + 1, h):
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > SOLID and ((x < mid) if left else (x >= mid)):
				body.set_pixel(x, y - 1, c)
	out.blend_rect(body, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return out


## Puts the right frame of `base` on `sprite` for the walk's `phase` (the
## same phase as the bob, so a foot's up at the top of each step), or `base`
## itself while `walking` is false.
static func walk(sprite: Sprite2D, base: Texture2D, phase: float, walking: bool) -> void:
	var tex := base
	if walking:
		var frames := walk_frames(base)
		if not frames.is_empty():
			var s := sin(phase)
			if s > LIFT_AT:
				tex = frames[0]
			elif s < -LIFT_AT:
				tex = frames[1]
	if sprite.texture != tex:
		sprite.texture = tex
