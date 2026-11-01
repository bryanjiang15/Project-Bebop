class_name MatchResult
extends RefCounted

## The outcome handed from GameSetup to the victory and defeat scenes.
## `latest` survives the scene change. GameSetup.start clears it.

const REASON_CONQUEST := "Conquest"
const REASON_SCORE := "Turn 50 score"
const REASON_ELIMINATED := "Eliminated"

static var latest: MatchResult


class Row extends RefCounted:
	var player: int
	var human: bool
	var color: String = ""
	var player_name: String = ""
	var score: int
	var tiles: int
	var cities: int
	var population: int
	var eliminated: bool
	var reason: String = ""

	func line() -> String:
		return "%s    %d    %d tiles    %d cities    %d pop    %s" % [player_name, score, tiles, cities, population, reason]


var human_won: bool
var ending: String = ""
var turn: int
var rows: Array[Row] = []
## Absolute path of this game's log. Empty when logging is off or the file could not be opened.
var log_path: String = ""


static func player_name(index: int, human_index: int) -> String:
	if index == human_index:
		return "You"
	return "Rival %d" % (index + 1)
