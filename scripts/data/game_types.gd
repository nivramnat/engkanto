class_name GameTypes
extends RefCounted
## Shared enums for the creature/move data system. Never instantiated; used
## only as a namespace (GameTypes.Element.EARTH, GameTypes.SpawnTime.NIGHT).

enum Element { NEUTRAL, EARTH, FIRE, WATER, WIND, DARK, LIGHT, SPIRIT }

enum SpawnTime { DAY, NIGHT, BOTH }


## Placeholder tint used to tell elements apart until real art exists.
static func element_color(element: Element) -> Color:
	match element:
		Element.EARTH:
			return Color("8d6e3c")
		Element.FIRE:
			return Color("c0392b")
		Element.WATER:
			return Color("2980b9")
		Element.WIND:
			return Color("7fcdbb")
		Element.DARK:
			return Color("3b2d4a")
		Element.LIGHT:
			return Color("f1c40f")
		Element.SPIRIT:
			return Color("9b59b6")
		_:
			return Color("bdc3c7")
