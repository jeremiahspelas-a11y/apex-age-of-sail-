extends Node
## Compartment flooding model, intentionally a first step toward a structural ship.
## Water mass and reserve buoyancy are coupled to the parent sailing controller.
signal hull_state_changed
const WATER_DENSITY := 1025.0
const MAX_VOLUME_M3 := 18.0
var water_m3 := 0.0
var compartments := [
 {"name":"Bow","integrity":1.0,"leak_area":0.0,"water":0.0,"capacity":6.0,"x":0.0,"z":-4.0},
 {"name":"Midships","integrity":1.0,"leak_area":0.0,"water":0.0,"capacity":6.0,"x":0.0,"z":0.0},
 {"name":"Stern","integrity":1.0,"leak_area":0.0,"water":0.0,"capacity":6.0,"x":0.0,"z":4.0}
]
func _physics_process(delta: float) -> void:
 var boat := get_parent() as Node3D
 var sea := get_node_or_null("/root/Ocean")
 if boat == null or sea == null:
  return
 water_m3 = 0.0
 for c in compartments:
  var position_world: Vector3 = boat.to_global(Vector3(float(c["x"]), -0.8, float(c["z"])))
  var outside_height: float = sea.get_height(position_world.x,position_world.z)
  var head: float = maxf(0.0,outside_height - position_world.y)
  var leak_area: float = float(c["leak_area"])
  var inflow: float = 0.62 * leak_area * sqrt(2.0 * 9.81 * head) * delta
  c["water"] = minf(float(c["capacity"]),float(c["water"])+inflow)
  water_m3 += float(c["water"])
 hull_state_changed.emit()
func breach(index: int, damage: float = 0.35) -> void:
 if index < 0 or index >= compartments.size():
  return
 var c: Dictionary = compartments[index]
 c["integrity"] = maxf(0.0,float(c["integrity"])-damage)
 c["leak_area"] = minf(0.50,float(c["leak_area"])+0.055*damage/0.35)
func patch(index: int) -> void:
 if index < 0 or index >= compartments.size():
  return
 var c: Dictionary = compartments[index]
 c["leak_area"] = maxf(0.0,float(c["leak_area"])-0.06)
func pump(delta: float) -> void:
 for c in compartments:
  c["water"] = maxf(0.0,float(c["water"])-0.55*delta)
func flooded_fraction() -> float:
 return clampf(water_m3/MAX_VOLUME_M3,0.0,1.0)
func total_water_tonnes() -> float:
 return water_m3*WATER_DENSITY/1000.0
