class_name RewardScreenModel
extends RefCounted
## Modelo da tela de recompensa (T24): transforma a tela aberta no estado em cartas prontas para
## mostrar (nome, frase, categoria e cor), o custo do reroll e o tempo restante (porte de
## `rewardScreenModel.ts`). Sem nós.

class Card:
	extends RefCounted
	var index := 0
	## Tecla da carta ("1", "2", "3").
	var key := ""
	var reward_id := ""
	var name := ""
	var text := ""
	## "Classe · Arcana", "Economia"...
	var category := ""
	## Cor da classe (cartas de classe) ou da categoria, "#rrggbb".
	var color := "#ffffff"
	var repeatable := false

var title := ""
## "+1 na fila" ou vazio.
var queued := ""
var cards: Array[Card] = []
var reroll_cost := 0
var can_reroll := false
## Segundos restantes, arredondados para cima.
var seconds := 0
## Fração do tempo que ainda resta (1 = cheio, 0 = acabou).
var time_left := 0.0


## Substitui `{nome}` pelos valores do Dictionary (chaves sem valor ficam como estão).
static func fill_text(template: String, values: Dictionary) -> String:
	var out := template
	for key in values:
		out = out.replace("{%s}" % key, str(values[key]))
	return out


## Uma carta: o coringa ganha o nome e a cor da classe sorteada. `option`: {"id", "classId"}.
static func reward_card(option: Dictionary, index: int, data: RewardData, classes: ClassData) -> Card:
	var texts: Dictionary = DataLoader.load_json("ui.json")["rewardScreen"]
	var class_colors: Dictionary = DataLoader.load_json("render.json")["towers"]["classColors"]
	var category_colors: Dictionary = texts["categoryColors"]
	var reward := data.get_reward(option["id"])
	var class_id: Variant = option["classId"] if option["classId"] != null else reward.class_id
	var class_name_text := ""
	if class_id != null:
		class_name_text = classes.classes[class_id].name if classes.classes.has(class_id) else str(class_id)
	var category_name: String = texts["categories"][reward.category]
	var card := Card.new()
	card.index = index
	card.key = str(index + 1)
	card.reward_id = reward.id
	card.name = fill_text(texts["wildcardName"], {"classe": class_name_text}) if option["classId"] != null else reward.name
	card.text = fill_text(reward.text, {"classe": class_name_text})
	card.category = "%s · %s" % [category_name, class_name_text] if class_id != null else category_name
	if class_id != null:
		card.color = class_colors.get(class_id, "#ffffff")
	else:
		card.color = category_colors.get(reward.category, "#ffffff")
	card.repeatable = reward.repeatable
	return card


## null sem tela aberta.
static func build(state: Object, data: RewardData, classes: ClassData, ticks_per_second: float) -> RewardScreenModel:
	var screen: RewardsState.RewardScreen = state.rewards.screen
	if screen == null:
		return null
	var texts: Dictionary = DataLoader.load_json("ui.json")["rewardScreen"]
	var total := maxi(1, roundi(data.choose_seconds * ticks_per_second))
	var cost := Rewards.reward_reroll_cost(data, screen)
	var queued_count: int = state.rewards.queue.size()
	var model := RewardScreenModel.new()
	model.title = fill_text(texts["title"], {"wave": screen.wave}) if data.waves.has(screen.wave) else texts["extraTitle"]
	model.queued = fill_text(texts["queued"], {"n": queued_count}) if queued_count > 0 else ""
	for i in screen.options.size():
		model.cards.append(reward_card(screen.options[i], i, data, classes))
	model.reroll_cost = cost
	model.can_reroll = state.gold >= cost
	model.seconds = int(ceilf(float(screen.ticks_left) / ticks_per_second))
	model.time_left = minf(1.0, float(screen.ticks_left) / float(total))
	return model


## Assinatura das cartas e do reroll (o tempo muda a cada tick e é desenhado à parte).
static func key(model: RewardScreenModel) -> String:
	if model == null:
		return "-"
	var card_keys: Array[String] = []
	for c in model.cards:
		card_keys.append("%s:%s" % [c.reward_id, c.name])
	return "|".join([model.title, model.queued, ",".join(card_keys), str(model.reroll_cost), "1" if model.can_reroll else "0"])
