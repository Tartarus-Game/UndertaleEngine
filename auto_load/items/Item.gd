class_name Item extends Resource

var id: String = ""
var item_name: String = ""
var use_callable: Callable = Callable()

func _init(_id: String = "", _name: String = "", _use_callable: Callable = Callable()) -> void:
	self.id = _id
	self.item_name = _name
	self.use_callable = _use_callable

func use() -> void:
	if use_callable.is_valid():
		use_callable.call()

func drop() -> void:
	pass

func name() -> String:
	return item_name

func info() -> String:
	return "这是一个物品。"
