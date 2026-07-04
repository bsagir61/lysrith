extends Node
## RandomService.gd - single seeded RNG for the whole campaign.
## Keeping randomness here makes runs reproducible from the saved seed.

var _rng := RandomNumberGenerator.new()
var current_seed: int = 0


func reseed(new_seed: int) -> void:
	current_seed = new_seed
	_rng.seed = new_seed


func randomize_seed() -> int:
	_rng.randomize()
	current_seed = int(_rng.seed)
	return current_seed


func rand_int(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func rand_float() -> float:
	return _rng.randf()


func roll_percent(chance: int) -> bool:
	return _rng.randi_range(1, 100) <= chance


func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]


func shuffled(arr: Array) -> Array:
	var copy := arr.duplicate()
	for i in range(copy.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = copy[i]
		copy[i] = copy[j]
		copy[j] = tmp
	return copy
