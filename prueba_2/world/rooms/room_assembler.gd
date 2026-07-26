extends RefCounted

const RoomScene := preload("res://world/rooms/procedural_room.tscn")


static func build(room_data: Dictionary) -> Node2D:
	var room: Node2D = RoomScene.instantiate()
	room.call("configure", room_data)
	return room
