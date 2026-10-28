extends GutTest
## Regras de apresentação da carta da loja: comum é cinza e não leva etiqueta de raridade; as outras
## mostram o nome da raridade; o medalhão usa a inicial do nome.


func _slot(rarity: String, label: String, slot_name: String = "Ruby, Duas-Pistolas") -> ShopModel.SlotModel:
	var slot := ShopModel.SlotModel.new()
	slot.tower_type = "ruby"
	slot.name = slot_name
	slot.rarity = rarity
	slot.rarity_label = label
	return slot


func test_common_card_has_no_rarity_tag() -> void:
	assert_eq(_slot("common", "Comum").rarity_tag(), "")


func test_other_rarities_show_their_label() -> void:
	assert_eq(_slot("uncommon", "Incomum").rarity_tag(), "Incomum")
	assert_eq(_slot("rare", "Rara").rarity_tag(), "Rara")
	assert_eq(_slot("legendary", "Lendária").rarity_tag(), "Lendária")


func test_initial_is_the_first_letter_in_upper_case() -> void:
	assert_eq(_slot("common", "Comum", "ruby").initial(), "R")
	assert_eq(_slot("common", "Comum", "Sir Aldric").initial(), "S")


func test_every_rarity_has_a_card_color() -> void:
	for rarity: String in ["common", "uncommon", "rare", "legendary"]:
		assert_true(ShopCard.RARITY_COLORS.has(rarity), rarity)
