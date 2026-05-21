extends RefCounted
class_name InventorySlotData

var item_definition: InventoryItemDefinition = null
var quantity: int = 0

func setup(new_item_definition: InventoryItemDefinition, new_quantity: int) -> InventorySlotData:
	item_definition = new_item_definition
	quantity = max(new_quantity, 0)
	return self

func is_empty() -> bool:
	return item_definition == null or quantity <= 0
