class_name OnlineChat
extends RefCounted
## The only things players can say to each other online (D29): six emotes and eight
## phrases, sent as numbers. No free typing, so nothing needs moderating.
## Keep the order: ids are shared with the server (OnlineLobby.CHAT_IDS).

const ITEMS := [
	["emote", "thumb-up"], ["emote", "mood-happy"], ["emote", "mood-wink"],
	["emote", "mood-surprised"], ["emote", "mood-sad"], ["emote", "heart"],
	["text", "Hello!"], ["text", "Good move!"], ["text", "Nice try"], ["text", "Oops!"],
	["text", "Thinking…"], ["text", "Well played"], ["text", "Good game"], ["text", "Rematch?"],
]


static func is_emote(id: int) -> bool:
	return id >= 0 and id < ITEMS.size() and ITEMS[id][0] == "emote"


static func value(id: int) -> String:
	return ITEMS[id][1] if id >= 0 and id < ITEMS.size() else ""
