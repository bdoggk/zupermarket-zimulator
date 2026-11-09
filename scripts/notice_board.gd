class_name NoticeBoard
extends Prop
## The notice board in the town square (0.20): today's special orders
## (SpecialOrders). Use it to see them and take some (ui/orders_panel.gd).

const TEXTURE := preload("res://assets/sprites/prop_notice_board.png")


func _init() -> void:
	super._init([TEXTURE], "")


func get_prompt(_p: Player) -> String:
	var n := Game.orders.list.filter(func(o): return not o.taken).size()
	if Game.level < SpecialOrders.FROM_LEVEL:
		return "The notice board (special orders from store level %d)" % SpecialOrders.FROM_LEVEL
	return "Notice board: %d special order%s" % [n, "" if n == 1 else "s"] if n > 0 else "Notice board (nothing new today)"


func can_interact(_p: Player) -> bool:
	return Game.level >= SpecialOrders.FROM_LEVEL and not Game.orders.list.is_empty()


func interact(_p: Player) -> void:
	Game.orders_requested.emit()
