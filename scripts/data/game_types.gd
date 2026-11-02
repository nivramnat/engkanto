class_name GameTypes
extends RefCounted
## Shared enums for the creature/move data system. Never instantiated; used
## only as a namespace (GameTypes.Element.EARTH, GameTypes.SpawnTime.NIGHT).

enum Element { NEUTRAL, EARTH, FIRE, WATER, WIND, DARK, LIGHT, SPIRIT }

enum SpawnTime { DAY, NIGHT, BOTH }
