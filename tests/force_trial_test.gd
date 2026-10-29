extends SceneTree
const Refit = preload("res://scripts/ship_refit.gd")
const Steering = preload("res://scripts/steering_transmission.gd")
const Hydro = preload("res://scripts/hull_hydrostatics.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)
func flat(_x: float,_z: float) -> float: return 0.0
func rectangular_section(z: float) -> PackedVector3Array:
 return PackedVector3Array([Vector3(-2,-1,z),Vector3(2,-1,z),Vector3(2,1,z),Vector3(-2,1,z)])
func run() -> void:
 var box := Hydro.new()
 box.build_box(Vector3(4,2,8))
 var half := box.evaluate(Transform3D.IDENTITY,Callable(self,"flat"))
 check(absf(half.volume-32.0)<0.0001,"Box half immersion must displace exactly 32 m3")
 check(absf(half.buoyancy.y-32.0*1025.0*9.8)<0.1,"Buoyancy must equal rho*g*submerged volume")
 check(half.center.distance_to(Vector3(0,-0.5,0))<0.001,"Buoyancy must act through submerged-volume centroid")
 var dry := box.evaluate(Transform3D(Basis.IDENTITY,Vector3(0,3,0)),Callable(self,"flat"))
 check(dry.volume == 0.0 and dry.buoyancy == Vector3.ZERO,"Dry hull must produce no buoyancy")
 var submerged := box.evaluate(Transform3D(Basis.IDENTITY,Vector3(0,-3,0)),Callable(self,"flat"))
 check(absf(submerged.volume-64.0)<0.0001,"Fully submerged volume must be bounded by hull capacity")
 var other_hull := Hydro.new()
 other_hull.build_from_sections(Callable(self,"rectangular_section"),AABB(Vector3(-2,-1,-4),Vector3(4,2,8)),8,12)
 check(absf(other_hull.evaluate(Transform3D.IDENTITY,Callable(self,"flat")).volume-32.0)<0.0001,"Caller-supplied hull sections must work without APEX geometry")
 var portable_helm := Steering.new()
 var untouched_helm := Steering.new()
 portable_helm.set_helm_torque(90.0)
 for step in 120: portable_helm.step(1.0/60.0,0.0)
 check(portable_helm.rudder_angle>0.05 and absf(portable_helm.crew_hand_force)<=180.0,"Standalone steering must transmit bounded torque without a scene")
 check(untouched_helm.wheel_angle==0.0 and untouched_helm.rudder_angle==0.0,"Reusable steering instances must own independent state")
 var model := Hydro.new()
 model.build_from_sections(Refit.hull_profile,AABB(Vector3(-3.45,-2.2,-13),Vector3(6.9,3.11,26.2)))
 check(absf(model.full_volume-379.6900)/379.6900<0.01,"Column integration must match closed-hull reference within 1 percent")
 var coarse := Hydro.new()
 coarse.build_from_sections(Refit.hull_profile,model.bounds,10,20)
 check(absf(coarse.full_volume-model.full_volume)/model.full_volume < 0.02,"Hydrostatic grid refinement must converge")
 var mass := 80000.0
 var com := Vector3(0,-0.6,0)
 var height := model.equilibrium_height(mass,com)
 var pose := Transform3D(Basis.IDENTITY,Vector3(0,height,0))
 var equilibrium := model.evaluate(pose,Callable(self,"flat"),com)
 check(absf(equilibrium.buoyancy.y-mass*9.8)/(mass*9.8)<0.00001,"Equilibrium must derive from displacement and chosen mass")
 var loaded_height := model.equilibrium_height(mass+10000.0,com)
 check(loaded_height < height-0.05,"Adding cargo must increase draft without a scripted offset")
 var heel := pose
 heel.basis = Basis(Vector3.BACK,deg_to_rad(8.0))
 var rolled := model.evaluate(heel,Callable(self,"flat"),com)
 check(rolled.buoyancy_torque.z < 0.0,"Buoyancy must provide a restoring moment at the provisional CG")
 var linear := Vector3(2,1,-3)
 var angular := Vector3(0.1,0.04,-0.2)
 var resistance := model.evaluate(pose,Callable(self,"flat"),com,linear,angular)
 check(resistance.drag.dot(linear)+resistance.drag_torque.dot(angular) < 0.0,"Hydrodynamic damping must dissipate rather than inject energy")
 print("FORCE MODEL: columns=",model.columns.size()," volume=",model.full_volume," m3 equilibrium_y=",height," restoring_Mz=",rolled.buoyancy_torque.z)
 var game: Node3D = load("res://physics_trial.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.get_node("Weather").set_process(false)
 var boat: RigidBody3D = game.boat
 var player: CharacterBody3D = game.get_node("Player")
 player.set_physics_process(false)
 player.collision_layer = 0
 player.collision_mask = 0
 boat.ocean = null
 boat.wind_world = Vector3.ZERO
 boat.reef_fraction = 0.0
 await physics_frame
 await physics_frame
 boat.set_force_trial(true)
 for frame in range(10): await physics_frame
 check(not boat.freeze and not boat.axis_lock_angular_x and not boat.axis_lock_angular_z,"Force trial must release real rigid-body translation, pitch and roll")
 boat.apply_central_impulse(Vector3(0,boat.mass*0.25,0))
 var initial: Vector3 = boat.position
 var max_speed := 0.0
 for frame in range(360):
  await physics_frame
  max_speed = maxf(max_speed,boat.linear_velocity.length())
 check(max_speed > 0.1,"Physics body must respond to a real impulse")
 check(boat.position.is_finite() and boat.angular_velocity.is_finite(),"Force trial must remain finite")
 check(absf(boat.position.y-height)<0.15,"Hull must settle near its displacement-derived waterline")
 check(boat.linear_velocity.length()<0.25,"Calm-water hull motion must settle without forced transform updates")
 # Pressure acts on the actual eight sail surfaces and produces moments about the CG.
 for velocity: Vector3 in [Vector3(0,0,-3),Vector3(1,0,-3),Vector3(-2,0,1)]:
  for angle in [-0.3,0.0,0.3]:
   check(boat.rudder_water_force(velocity,angle).dot(velocity)<=0.001,"Rudder lift/drag must not inject kinetic energy into still water")
 var rigs: RefCounted = boat.rig_pressure
 var pressure: Dictionary = rigs.evaluate(boat.to_global(boat.center_of_mass),Vector3(0,0,10),Vector3.ZERO,Vector3.ZERO,1.0)
 check(pressure.force.length()>100.0 and pressure.torque.length()>100.0,"Sail pressure must transfer both force and torque to the hull")
 check(rigs.last_sail_loads.size() == 8,"Each original sail must report its own area and pressure load")
 var no_wind: Dictionary = rigs.evaluate(boat.to_global(boat.center_of_mass),Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,1.0)
 check(no_wind.force.length()<0.001,"Still air and a stationary ship must produce no sail thrust")
 var furl: Dictionary = rigs.evaluate(boat.to_global(boat.center_of_mass),Vector3(0,0,10),Vector3.ZERO,Vector3.ZERO,0.0)
 check(furl.force.length()<0.001,"Zero effective sail area must remove wind load")
 var mechanisms: Node3D = game.get_node("Boat/Mechanisms")
 mechanisms.set_helm_torque(0.0)
 mechanisms.helm.wheel_angle = 0.2
 mechanisms.helm.wheel_velocity = 0.0
 mechanisms.helm.rudder_angle = 0.0
 mechanisms.helm.rudder_velocity = 0.0
 var stored: float = mechanisms.steering_energy()
 for step in 300: mechanisms.step_loaded_steering(1.0/60.0,0.0)
 check(mechanisms.steering_energy()<stored,"Released steering must dissipate its stored rope/rotation energy")
 check(mechanisms.helm.port_line_tension>=0.0 and mechanisms.helm.starboard_line_tension>=0.0,"Steering ropes must never push")
 mechanisms.helm.wheel_angle = 0.0
 mechanisms.helm.wheel_velocity = 0.0
 mechanisms.helm.rudder_angle = 0.0
 mechanisms.helm.rudder_velocity = 0.0
 for step in 120: mechanisms.step_loaded_steering(1.0/60.0,-200.0)
 check(mechanisms.helm.wheel_angle < -0.10,"Rudder water load must backdrive a released wheel")
 mechanisms.helm.connected = false
 mechanisms.helm.rudder_angle = 0.0
 mechanisms.helm.rudder_velocity = 0.0
 mechanisms.set_helm_torque(120.0)
 for step in 120: mechanisms.step_loaded_steering(1.0/60.0,0.0)
 check(absf(mechanisms.helm.rudder_angle)<0.001,"A cut steering link must prevent wheel torque reaching the rudder")
 check(mechanisms.helm.port_line_tension==0.0 and mechanisms.helm.starboard_line_tension==0.0,"Cut lines must transmit zero tension")
 mechanisms.helm.connected = true
 mechanisms.helm.wheel_angle = 0.0
 mechanisms.helm.wheel_velocity = 0.0
 mechanisms.helm.rudder_velocity = 0.0
 mechanisms.use_button_helm()
 check(mechanisms.wheel.visible and not mechanisms.whipstaff.visible,"Preferred training configuration must retain the functional steering wheel")
 boat.rudder_input = 1.0
 for frame in range(120): await physics_frame
 mechanisms._process(0.0)
 check(mechanisms.helm.rudder_angle > deg_to_rad(5.0),"Finite crew effort must move the loaded steering transmission")
 check(absf(mechanisms.helm.crew_hand_force)<=180.0,"Crew effort must remain force limited")
 check(absf(mechanisms.helm.rudder_angle)<=mechanisms.helm.rudder_stop+0.001,"Rudder must retain the declared mechanical stops")
 check(mechanisms.wheel.position.z > 11.2 and mechanisms.wheel.position.y-0.72 > 2.36,"Wheel must clear the mizzenmast and quarterdeck")
 var staff_tip: Vector3 = mechanisms.whipstaff.to_global(Vector3(0,-Vector2(1.70*sin(mechanisms.helm.rudder_angle),1.15).length(),0))
 var tiller_tip: Vector3 = mechanisms.rudder.to_global(Vector3(0,0,-1.70))
 check(staff_tip.distance_to(tiller_tip)<0.002,"Sliding whipstaff must remain attached to its tiller tip")
 boat.set_force_trial(false)
 check(boat.freeze and boat.axis_lock_angular_x and boat.axis_lock_angular_z,"Return to prototype must restore its controlled mode")
 print("FORCE ENGINE: peak_speed=",max_speed," settled_y=",boat.position.y," initial_y=",initial.y)
 game.free()
 if failures.is_empty(): print("APEX FORCE TRIAL TEST PASS: displacement, equilibrium, stability, damping, engine response, sail pressure and loaded wheel transmission")
 quit(0 if failures.is_empty() else 1)
