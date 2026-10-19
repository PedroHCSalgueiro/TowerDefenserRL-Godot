class_name ClassBonuses
extends RefCounted
## Leitura dos bônus de classe (porte de `bonuses.ts`). Cada bônus vale só para as torres
## da própria classe: as funções percorrem as classes do tipo da torre que age e olham o
## nível ativo de cada uma (`state.classes`). Sem nível ativo, o valor é neutro.
##
## Os bônus de classe das recompensas (T24) entram aqui também: +% de dano da área, −N
## nas contagens "a cada N" e o peso das mortes de elite e chefão. Estados sem `rewards`
## (testes) valem como sem recompensas.
##
## `state` é qualquer objeto com `classes` (Dictionary id -> ClassState.ClassStatus).


## Nível ativo da classe, ou null se ainda não chegou ao primeiro.
static func active_level(data: ClassData, state: Object, class_id: String) -> ClassData.ClassLevel:
	var status: ClassState.ClassStatus = state.classes.get(class_id)
	var level := status.level if status != null else 0
	if level <= 0:
		return null
	var tower_class: ClassData.TowerClass = data.classes.get(class_id)
	if tower_class == null or level > tower_class.levels.size():
		return null
	return tower_class.levels[level - 1]


## Artilharia: multiplicador do raio da área (tiro em área e explosões de gatilho).
static func area_radius_multiplier(data: ClassData, state: Object, type: TowerData.TowerType) -> float:
	var mult := 1.0
	for id in type.classes:
		var level := active_level(data, state, id)
		mult *= level.area_radius_multiplier if level != null else 1.0
	return mult


## Artilharia: multiplicador do dano da área (tiro em área e explosões de gatilho). O bônus
## das recompensas multiplica junto: +25% duas vezes = ×1,5.
static func area_damage_multiplier(data: ClassData, state: Object, type: TowerData.TowerType) -> float:
	var extra := RewardMods.of(state).area_damage_percent
	var mult := 1.0
	for id in type.classes:
		var level := active_level(data, state, id)
		mult *= level.area_damage_multiplier if level != null else 1.0
		var percent: float = extra.get(id, 0.0)
		if percent != 0.0:
			mult *= 1.0 + percent / 100.0
	return mult


## Região (Reino de Valcoroa): % de velocidade de ataque que a torre recebe dos níveis ativos das
## classes dela. No nível "dobra com vizinhos", a torre com uma vizinha ortogonal da mesma classe recebe
## o bônus em dobro.
static func attack_speed_percent(data: ClassData, state: Object, type: TowerData.TowerType, tower: Tower) -> float:
	if not data.has_attack_speed_bonus:
		return 0.0
	var total := 0.0
	for id in type.classes:
		var level := active_level(data, state, id)
		if level != null and level.attack_speed_percent > 0.0:
			total += level.attack_speed_percent * _doubling(level, state, tower, id)
	return total


## Região: multiplicador do dano da torre (ataque normal e efeitos de gatilho), com o mesmo "dobra com vizinhos".
static func damage_multiplier(data: ClassData, state: Object, type: TowerData.TowerType, tower: Tower) -> float:
	if not data.has_damage_bonus:
		return 1.0
	var mult := 1.0
	for id in type.classes:
		var level := active_level(data, state, id)
		if level != null and level.damage_percent > 0.0:
			mult *= 1.0 + (level.damage_percent * _doubling(level, state, tower, id)) / 100.0
	return mult


static func _doubling(level: ClassData.ClassLevel, state: Object, tower: Tower, class_id: String) -> float:
	if not level.double_with_neighbors:
		return 1.0
	var towers_data := TowerData.game_data()
	for other: Tower in state.towers:
		if other != tower and absi(other.x - tower.x) + absi(other.y - tower.y) == 1 \
				and towers_data.has_type(other.type) and towers_data.types[other.type].classes.has(class_id):
			return 2.0
	return 1.0


## Mecânica: contagem de um "a cada N" depois do desconto. Arredonda para baixo, nunca
## passa de `base` e nunca cai abaixo do mínimo dos dados. O desconto é aplicado sobre o N
## da estrela; a conta é em inteiros. Depois dele, a carta da Mecânica das recompensas
## (T24) tira mais N, com o mesmo mínimo.
static func reduced_trigger_count(data: ClassData, state: Object, type: TowerData.TowerType, base: int) -> int:
	var minus := RewardMods.of(state).trigger_count_minus
	var percent := 0.0
	var extra := 0
	for id in type.classes:
		var level := active_level(data, state, id)
		if level != null:
			percent = maxf(percent, level.trigger_count_reduction_percent)
		extra += int(minus.get(id, 0))
	if percent == 0.0 and extra == 0:
		return base
	var reduced := int(floorf(float(base) * (100.0 - percent) / 100.0)) - extra
	return mini(base, maxi(data.min_trigger_count, reduced))


## Arcana: raio da vizinhança quadrada da torre (0 = vizinhança dos dados).
static func neighborhood_radius(data: ClassData, state: Object, type: TowerData.TowerType) -> int:
	var radius := 0
	for id in type.classes:
		var level := active_level(data, state, id)
		radius = maxi(radius, level.neighborhood_radius if level != null else 0)
	return radius


## Sombria: peso de uma morte nos gatilhos de uma torre que escuta abates. O multiplicador
## só vale para o ouvinte da classe do bônus, e só para mortes de torres da própria classe
## (nível 2) ou de qualquer autor (nível 4). `killer_type` é null quando a morte não foi de
## uma torre (núcleo). O resultado do bônus de classe nunca passa do teto dos dados.
##
## Carta da Sombria das recompensas (T24): a morte de elite ou chefão (`elite_or_boss`) vale
## ×3 para o ouvinte da classe, depois do teto (o teto segura o bônus de classe; a morte de
## elite vale o triplo do que valeria).
static func kill_weight(data: ClassData, state: Object, listener: TowerData.TowerType,
		killer_type: TowerData.TowerType, base: float, elite_or_boss: bool = false) -> float:
	var weight := base
	for id in listener.classes:
		var level := active_level(data, state, id)
		if level == null or level.kill_weight_multiplier == 1.0:
			continue
		if level.kill_weight_from == "sameClass" and (killer_type == null or not killer_type.classes.has(id)):
			continue
		weight *= level.kill_weight_multiplier
	if weight != base:
		weight = minf(weight, float(data.max_kill_weight))
	if elite_or_boss:
		var elite := RewardMods.of(state).elite_kill_weight
		for id in listener.classes:
			weight *= elite.get(id, 1.0)
	return weight
