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
## Cripta: +% a cada 10 almas da onda (`RunState.souls`), até o teto do nível.
static func damage_multiplier(data: ClassData, state: Object, type: TowerData.TowerType, tower: Tower) -> float:
	if not data.has_damage_bonus:
		return 1.0
	var mult := 1.0
	for id in type.classes:
		var level := active_level(data, state, id)
		if level == null:
			continue
		if level.damage_percent > 0.0:
			mult *= 1.0 + (level.damage_percent * _doubling(level, state, tower, id)) / 100.0
		if level.soul_damage_percent > 0.0 and "souls" in state:
			var tens := floorf(float(state.souls) / 10.0)
			mult *= 1.0 + minf(level.soul_damage_max_percent, level.soul_damage_percent * tens) / 100.0
	return mult


## Forjaferro: eco das habilidades da torre: {"every": int, "chance": float} (0 e 0 = sem eco). Com chance,
## a contagem não vale.
static func echo(data: ClassData, state: Object, type: TowerData.TowerType) -> Dictionary:
	var every := 0
	var chance := 0.0
	for id in type.classes:
		var level := active_level(data, state, id)
		if level != null:
			chance = maxf(chance, level.echo_chance_percent)
			if level.echo_every > 0:
				every = level.echo_every if every == 0 else mini(every, level.echo_every)
	return {"every": every, "chance": chance}


## Panteão: fração da armadura (0 a 1) que a torre ignora.
static func armor_pierce(data: ClassData, state: Object, type: TowerData.TowerType) -> float:
	var percent := 0.0
	for id in type.classes:
		var level := active_level(data, state, id)
		if level != null:
			percent = maxf(percent, level.armor_pierce_percent)
	return percent / 100.0


## Cripta: explosão de quem morre, {"percent": % da vida máxima do morto, "radius": casas} (percent 0 = nenhuma).
static func death_blast(data: ClassData, state: Object) -> Dictionary:
	var out := {"percent": 0.0, "radius": 0.0}
	for level in _active_levels(data, state):
		if level.death_blast_percent > out["percent"]:
			out = {"percent": level.death_blast_percent, "radius": level.death_blast_radius}
	return out


## Cripta: esqueleto aliado de quem morre, {"chance": %, "damage": % da vida máxima do morto} (chance 0 = nenhum).
static func skeleton_rise(data: ClassData, state: Object) -> Dictionary:
	var out := {"chance": 0.0, "damage": 0.0}
	for level in _active_levels(data, state):
		if level.skeleton_chance_percent > out["chance"]:
			out = {"chance": level.skeleton_chance_percent, "damage": level.skeleton_damage_percent}
	return out


## Panteão: quantos inimigos um deus destrói antes do núcleo, por onda.
static func nexus_saves(data: ClassData, state: Object) -> int:
	var saves := 0
	for level in _active_levels(data, state):
		saves = maxi(saves, level.nexus_saves_per_wave)
	return saves


static func _doubling(level: ClassData.ClassLevel, state: Object, tower: Tower, class_id: String) -> float:
	if not level.double_with_neighbors:
		return 1.0
	var towers_data := TowerData.game_data()
	for other: Tower in state.towers:
		if other != tower and absi(other.x - tower.x) + absi(other.y - tower.y) == 1 \
				and towers_data.has_type(other.type) and towers_data.types[other.type].classes.has(class_id):
			return 2.0
	return 1.0


## Alcance da torre agora: o dos dados, mais o bônus do Atirador e, com `tower`, as auras de alcance das
## vizinhas (Sacerdotisa Amunet). Sem bônus de alcance nos dados, é sempre o dos dados (não custa nada).
static func tower_range(data: ClassData, state: Object, type: TowerData.TowerType, tower: Tower = null) -> float:
	var reach := type.range
	if data != null and data.has_range_bonus:
		for id in type.classes:
			var level := active_level(data, state, id)
			if level != null:
				reach += level.range_bonus
	if tower != null and state != null and "towers" in state:
		var towers := TowerData.game_data()
		if towers.has_range_auras:
			reach += Auras.range_bonus(state, towers, tower)
	return reach


## Soma de um campo % dos níveis ativos das classes da torre, como multiplicador (+25% = ×1,25).
static func _percent_multiplier(data: ClassData, state: Object, type: TowerData.TowerType, field: String) -> float:
	if data == null:
		return 1.0
	var percent := 0.0
	for id in type.classes:
		var level := active_level(data, state, id)
		if level != null:
			percent += float(level.get(field))
	return 1.0 + percent / 100.0


## Controlador: multiplicador da duração dos efeitos de estado que a torre aplica.
static func status_duration_multiplier(data: ClassData, state: Object, type: TowerData.TowerType) -> float:
	return _percent_multiplier(data, state, type, "status_duration_percent")


## Invocador: multiplicadores da duração e do dano das invocações da torre.
static func summon_duration_multiplier(data: ClassData, state: Object, type: TowerData.TowerType) -> float:
	return _percent_multiplier(data, state, type, "summon_duration_percent")


static func summon_damage_multiplier(data: ClassData, state: Object, type: TowerData.TowerType) -> float:
	return _percent_multiplier(data, state, type, "summon_damage_percent")


## Suporte: multiplicador da força da aura da torre.
static func aura_multiplier(data: ClassData, state: Object, type: TowerData.TowerType) -> float:
	return _percent_multiplier(data, state, type, "aura_bonus_percent")


## Controlador: % de dano a mais que um inimigo Lento ou Atordoado recebe (bônus da run inteira).
static func afflicted_damage_percent(data: ClassData, state: Object) -> float:
	var percent := 0.0
	for level in _active_levels(data, state):
		percent += level.afflicted_damage_percent
	return percent


## Guardião: multiplicador da intensidade do Lento que a torre aplica (+20% = ×1,2).
static func slow_multiplier(data: ClassData, state: Object, type: TowerData.TowerType) -> float:
	var mult := 1.0
	for id in type.classes:
		var level := active_level(data, state, id)
		if level != null and level.slow_bonus_percent > 0.0:
			mult *= 1.0 + level.slow_bonus_percent / 100.0
	return mult


## Guardião: casas a mais no Empurrado que a torre aplica.
static func push_bonus_cells(data: ClassData, state: Object, type: TowerData.TowerType) -> float:
	var cells := 0.0
	for id in type.classes:
		var level := active_level(data, state, id)
		if level != null:
			cells += level.push_bonus_cells
	return cells


## Caçador: multiplicador do dano do tiro da torre contra um inimigo com `marks` marcas (só para as torres
## da classe com o bônus ativo; sem nível ativo, ×1 mesmo com o alvo marcado).
static func mark_damage_multiplier(data: ClassData, state: Object, type: TowerData.TowerType, marks: int) -> float:
	if marks <= 0:
		return 1.0
	var percent := 0.0
	for id in type.classes:
		var level := active_level(data, state, id)
		if level != null:
			percent += level.mark_damage_percent
	return 1.0 + percent * float(marks) / 100.0


## Níveis ativos de todas as classes (bônus que valem para a run inteira, não para uma torre).
static func _active_levels(data: ClassData, state: Object) -> Array[ClassData.ClassLevel]:
	var out: Array[ClassData.ClassLevel] = []
	for id: String in data.ids:
		var level := active_level(data, state, id)
		if level != null:
			out.append(level)
	return out


## Guardião (nível 4): multiplicador do dano que o núcleo recebe de quem chega nele.
static func nexus_damage_multiplier(data: ClassData, state: Object) -> float:
	var mult := 1.0
	for level in _active_levels(data, state):
		if level.nexus_damage_reduction_percent > 0.0:
			mult *= 1.0 - level.nexus_damage_reduction_percent / 100.0
	return mult


## Região (Costa Rubra): ouro a mais no teto dos juros.
static func interest_cap_bonus(data: ClassData, state: Object) -> int:
	var bonus := 0
	for level in _active_levels(data, state):
		bonus += level.interest_cap_bonus
	return bonus


## Região (Costa Rubra): ouro do baú no fim de cada onda.
static func wave_end_gold(data: ClassData, state: Object) -> int:
	var gold := 0
	for level in _active_levels(data, state):
		gold += level.wave_end_gold
	return gold


## Região (Costa Rubra): vagas a mais na loja.
static func shop_extra_slots(data: ClassData, state: Object) -> int:
	var slots := 0
	for level in _active_levels(data, state):
		slots += level.shop_extra_slots
	return slots


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
