extends Node
## APEX assembly registry: one hull body with named mechanical subassemblies.
## Does not pretend the scene has real joints/constraints yet.
signal assembly_changed(assembly_name: String, connected: bool)
var assemblies: Dictionary = {}
func _ready() -> void:
 var boat := get_parent()
 for name in ["ShipStructure", "ShipIntegrity", "Mechanisms", "HullVisual", "Wetness"]:
  var part := boat.get_node_or_null(name)
  if part != null:
   assemblies[name] = {"node": part, "connected": true, "parent": "Boat"}
 verify_assembly()
func verify_assembly() -> bool:
 var good := true
 for name in ["ShipStructure", "ShipIntegrity", "Mechanisms", "HullVisual"]:
  if not assemblies.has(name):
   push_error("APEX master assembly missing required subassembly: " + name)
   good = false
 return good
func is_connected(name: String) -> bool:
 return assemblies.has(name) and bool(assemblies[name]["connected"])
func set_connected(name: String, connected: bool) -> void:
 if not assemblies.has(name):
  push_warning("Unknown APEX subassembly: " + name)
  return
 assemblies[name]["connected"] = connected
 assembly_changed.emit(name, connected)
func assembly_report() -> Dictionary:
 var report := {}
 for name in assemblies:
  report[name] = {"connected": assemblies[name]["connected"], "parent": assemblies[name]["parent"]}
 return report
