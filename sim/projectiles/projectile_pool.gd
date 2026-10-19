class_name ProjectilePool
extends RefCounted
## Pool de projéteis dentro do RunState, no mesmo padrão do pool de inimigos:
## objetos reaproveitados, nunca destruídos, e salvos junto com a run.

var slots: Array[Projectile] = []
## Pilha de slots livres; o próximo disparo usa o último.
var free: Array[int] = []
var active_count := 0


static func create(capacity: int) -> ProjectilePool:
	var pool := ProjectilePool.new()
	for i in capacity:
		pool.slots.append(Projectile.new(i))
	for i in range(capacity - 1, -1, -1):
		pool.free.append(i)
	return pool


## Marca um slot livre como ativo e o devolve. Se não houver, o pool cresce.
func acquire() -> Projectile:
	var slot: int
	if free.is_empty():
		slot = slots.size()
		slots.append(Projectile.new(slot))
	else:
		slot = free.pop_back()
	var projectile := slots[slot]
	projectile.active = true
	active_count += 1
	return projectile


## Devolve o projétil ao pool. Devolver duas vezes: push_error e não faz nada.
func release(projectile: Projectile) -> void:
	if not projectile.active:
		push_error("Projétil %d (slot %d) já foi devolvido ao pool" % [projectile.id, projectile.slot])
		return
	projectile.active = false
	free.append(projectile.slot)
	active_count -= 1


## Devolve todos os projéteis ativos ao pool.
func release_all() -> void:
	for projectile in slots:
		if projectile.active:
			release(projectile)
