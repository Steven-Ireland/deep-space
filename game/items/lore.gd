class_name Lore
## What the earlier waves left in their data cores (GDD §3: lore is found, never told): logs from the
## survey stations that went before the LANTERN. A data core carries one (its record's `log`, an
## index here, picked from the derelict's seed); reading it from the suit panel adds it to the
## crew member's LOGS. Most of them are also a warning, if anyone's listening.

const LOGS := [
	["WAVE 3 / BEACON / DAY 112", "SURVEY STATION PERSEVERANCE",
		"Wave three reporting. Sector charted to the second row. Fuel nominal, crew in good spirits. Biosigns ambiguous on the fourth moon of the third system; recommend the next wave survey it in person."],
	["QUARTERMASTER'S NOTE", "SURVEY STATION PERSEVERANCE",
		"Somebody keeps taking the flares. If you need one, sign for it. If you're scared of the dark, say so, there's no shame in it. Just sign for it."],
	["MED LOG / ENSIGN HALE", "SURVEY STATION HALCYON",
		"Hale's fever broke this morning but he won't eat. He says he can hear the hull. Says it clicks back when he taps it. Sedated, logged, moving on."],
	["MED LOG / ENSIGN HALE (2)", "SURVEY STATION HALCYON",
		"Hale's bunk is empty. His suit's gone from storage, but the airlock logs show no cycle. The search found his gloves in the cargo hold, the fingers worn through from the inside."],
	["ENGINEERING / SECTION B", "SURVEY STATION HALCYON",
		"Breakers in B keep tripping. Coolant's pooling under the cable trays again. Do NOT walk the trays with the section live. I've said it twice. I'm writing it down so it's three times."],
	["RELAY K-17 / TELEMETRY", "RELAY K-17",
		"Next carrier expected in 4,012 days. Last contact: wave five, flagship WARDEN. Last message length 41 minutes. Content unintelligible. Content repeating."],
	["CAPTAIN'S LOG / WAVE 5", "FLAGSHIP WARDEN",
		"We found the source of the signal. It isn't a beacon. It's a voice, or it learned to be one. Science wants to go aboard. I've told them we jump at first watch."],
	["PERSONAL / J. OKONKWO", "SURVEY STATION MERIDIAN",
		"If you find this, my daughter is Ada Okonkwo, Lagos arcology, deck forty. Tell her the stars were beautiful out here. Don't tell her anything else."],
	["SECURITY / LOCKDOWN ORDER", "SURVEY STATION MERIDIAN",
		"By order of the captain the cargo deck is sealed. Nobody opens bulkhead C for anything. If you hear knocking from the other side, it is not your crewmate."],
	["SCIENCE / SAMPLE 31", "SURVEY STATION MERIDIAN",
		"The growth tolerates vacuum, cold, and the reactor's direct output. It does not tolerate light. Under the work lamps it draws in, like an anemone. In the dark it reaches."],
	["DRIVE ROOM / MAINTENANCE", "SURVEY STATION HALCYON",
		"Core shielding cracked in the hard dock. Dosimeters clicking from the hatch. Get the cells out fast and don't stand about admiring the glow. Nobody gets a medal for rads."],
	["CREW NOTICE", "SURVEY STATION PERSEVERANCE",
		"Reminder: the jump core stays in its cradle until the clamps are released from the bridge. Pulling it by hand trips every alarm on the ship. Ask me how I know."],
	["PERSONAL / UNSIGNED", "UNKNOWN",
		"It doesn't see. It hears. Walk soft, don't run, don't drop anything. Shut the doors behind you. It can't work a door. Not yet."],
	["KEEPER / AUTOMATED", "STATION COMPUTER",
		"CREW COMPLEMENT ZERO. LIFE SUPPORT IDLE. AWAITING NEXT WAVE. AWAITING NEXT WAVE. AWAITING NEXT WAVE."],
	["WAVE 4 / ASTROGATION", "SURVEY STATION TALLY-HO",
		"Second sector charted. Nothing habitable. Gas giants plenty. Recommend we stop calling them waves. Waves come back."],
	["MAINTENANCE / DOOR 7C", "SURVEY STATION TALLY-HO",
		"Door 7C's controller is shot. It cycles on its own every few seconds and it doesn't check what's in the frame. Mind your fingers. Mind everything else too."],
]


static func title(index: int) -> String:
	return LOGS[posmod(index, LOGS.size())][0]


static func source(index: int) -> String:
	return LOGS[posmod(index, LOGS.size())][1]


static func text(index: int) -> String:
	return LOGS[posmod(index, LOGS.size())][2]
