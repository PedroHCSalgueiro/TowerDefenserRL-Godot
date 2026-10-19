class_name EnemyPool
extends RefCounted
## Pool de inimigos dentro do RunState (porte de `pool.ts`).
##
## Os objetos nunca são destruídos: um inimigo morto ou que chegou ao núcleo
## volta para a lista livre e é reaproveitado no próximo spawn. Como `slots` e
## `free` fazem parte do estado salvo, restaurar uma run reproduz exatamente o
## mesmo reaproveitamento.

var slots: Array[Enemy] = []
## Pilha de slots livres; o próximo spawn usa o último.
var free: Array[int] = []
var active_count := 0


static func create(capacity: int) -> EnemyPool:
	var pool := EnemyPool.new()
	for i in capacity:
		pool.slots.append(Enemy.new(i))
	# Ordem decrescente para que os primeiros spawns usem os slots 0, 1, 2...
	for i in range(capacity - 1, -1, -1):
		pool.free.append(i)
	return pool


## Marca um slot livre como ativo e o devolve. Se não houver, o pool cresce.
## Quem chama preenche os campos do inimigo.
func acquire() -> Enemy:
	var slot: int
	if free.is_empty():
		slot = slots.size()
		slots.append(Enemy.new(slot))
	else:
		slot = free.pop_back()
	var enemy := slots[slot]
	enemy.active = true
	active_count += 1
	return enemy


## Devolve o inimigo ao pool. Devolver duas vezes: push_error e não faz nada.
func release(enemy: Enemy) -> void:
	if not enemy.active:
		push_error("Inimigo %d (slot %d) já foi devolvido ao pool" % [enemy.id, enemy.slot])
		return
	enemy.active = false
	free.append(enemy.slot)
	active_count -= 1


## Devolve todos os inimigos ativos ao pool, sem eventos (limpeza de debug).
func release_all() -> void:
	for enemy in slots:
		if enemy.active:
			release(enemy)
