class_name GameTypes
extends RefCounted
## Shared enums and the elemental type chart for the creature/battle system.
## Never instantiated; used only as a namespace.

enum Element { NEUTRAL, EARTH, FIRE, WATER, WIND, DARK, LIGHT, BLOOD }

enum SpawnTime { DAY, NIGHT, BOTH }


## Human-readable element name, e.g. Element.EARTH -> "Earth".
static func element_name(element: Element) -> String:
	return String(Element.keys()[element]).capitalize()


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
		Element.BLOOD:
			return Color("7a1f1f")
		_:
			return Color("bdc3c7")


## Damage multiplier when a move of `attacking` element hits a `defending`
## creature. 2.0 = strong, 0.5 = weak, 1.0 = neutral. Folklore-flavoured:
## light banishes dark and blood (dawn vs aswang), water douses fire, etc.
static func type_multiplier(attacking: Element, defending: Element) -> float:
	match attacking:
		Element.EARTH:
			if defending in [Element.WATER, Element.FIRE]:
				return 2.0
			if defending in [Element.WIND, Element.LIGHT]:
				return 0.5
		Element.FIRE:
			if defending in [Element.WIND, Element.DARK]:
				return 2.0
			if defending in [Element.WATER, Element.EARTH]:
				return 0.5
		Element.WATER:
			if defending in [Element.FIRE, Element.BLOOD]:
				return 2.0
			if defending in [Element.EARTH, Element.WIND]:
				return 0.5
		Element.WIND:
			if defending in [Element.EARTH, Element.WATER]:
				return 2.0
			if defending in [Element.FIRE, Element.BLOOD]:
				return 0.5
		Element.DARK:
			if defending in [Element.EARTH, Element.WIND]:
				return 2.0
			if defending in [Element.LIGHT, Element.FIRE]:
				return 0.5
		Element.LIGHT:
			if defending in [Element.DARK, Element.BLOOD]:
				return 2.0
			if defending == Element.EARTH:
				return 0.5
		Element.BLOOD:
			if defending in [Element.WATER, Element.EARTH]:
				return 2.0
			if defending in [Element.LIGHT, Element.FIRE]:
				return 0.5
	return 1.0
