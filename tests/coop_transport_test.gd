extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)
func run() -> void:
 var session: Node = load("res://scripts/crew_session.gd").new()
 root.add_child(session)
 session.set_physics_process(false)
 var host := WebSocketMultiplayerPeer.new()
 check(host.create_server(19081,"127.0.0.1")==OK,"Transport fixture must bind")
 root.multiplayer.multiplayer_peer = host
 session.active = true
 session.is_host = true
 var client := WebSocketMultiplayerPeer.new()
 check(client.create_client("ws://127.0.0.1:19081")==OK,"Transport fixture must connect")
 for frame in 180:
  client.poll()
  await physics_frame
  if root.multiplayer.get_peers().size()==1 and client.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED: break
 check(root.multiplayer.get_peers().size()==1,"Transport fixture must have one actual peer")
 if root.multiplayer.get_peers().size()==1:
  var id: int = root.multiplayer.get_peers()[0]
  check(session._transport_open(id),"Open transport must allow RPCs")
  session.pending_snapshots[id] = -1
  host.get_peer(id).close()
  check(root.multiplayer.get_peers().has(id),"Closing regression must retain its ID before the next poll")
  check(not session._transport_open(id),"Retained peer ID must not authorize a closing transport")
  # No game is installed: attempting capture/send here would itself fail.
  session._physics_process(0.2)
  session._deny(id,"Closing fixture")
  check(session.pending_snapshots[id]==-1,"Closing socket must not be assigned an in-flight snapshot")
 client.close()
 host.close()
 root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
 session.active = false
 session.queue_free()
 await process_frame
 if failures.is_empty(): print("APEX COOP TRANSPORT TEST PASS: actual closing peer retains ID without snapshot or feedback send")
 quit(0 if failures.is_empty() else 1)
