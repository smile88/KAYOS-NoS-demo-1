extends RefCounted
class_name ColdOpenScript
## Every word of Cold Open v2 (docs/Cold_Open_v2_Proposal.md) in one place: examine text, the
## conversations, Talindir's interior lines, the objectives, the cutscene's subtitles and the letter.
##
## Much of the examine writing is carried over from the first Cold Open (Balcony3D / Scriptorium3D) —
## it was the best thing in it. What is new is the quest: Maelis gives Talindir the Record duty,
## and every step of it shows the player one more thing the Song does, just before the Silence takes
## it away.

const TALINDIR := "Talindir"
const MAELIS := "Archivist Maelis"
const FG := "Festival-Goer"
const PO_TALINDIR := "PO-005"
const PO_FG := "PO-014"

# --- objectives ---------------------------------------------------------------------------------
const QUEST_TITLE := "The Luminarae Record"
const OBJ_RECORD := "Call the Record down from the high stacks"
const OBJ_INK := "Fill the ink-horn at the star-ink font"
const OBJ_GLASS := "Take the Song-glass reading"
const OBJ_KEY := "Ask Maelis for the balcony key — the cloister gate"
const OBJ_CLIMB := "Climb the stair tower to the balcony"
const OBJ_LECTERN := "Set the Record on the lectern at the rail"

# --- Talindir's interior (the whisper line) ------------------------------------------------------
const OPENING := "The two-thousandth Luminarae. Sixty years a scribe of the Astral Archive, and you have never once gone down to it."
const PLACE_CARD := "Astra'Thalas — the Astral Archive\nthe night of the two-thousandth Luminarae · 2000 AO"
const CONTROLS := "WASD walk   ·   Shift hurry   ·   right-drag look   ·   F examine   ·   V first person"
const CONTROLS_TOUCH := "Left thumb walks   ·   right thumb looks   ·   USE examines and talks"
const AFTER_DUTY := "Sixty years you have watched it from up there. Tonight, with a pen in your hand."
const LETTER_POCKETED := "You put Elorin's letter in your satchel. You were always going to."
const LIFT_FLICKER := "Every lamp in the hall dips at once — the way a room goes quiet when someone important stops speaking. Then they come back."
const INK_DRIFT := "The stars in the ink are drifting. All of them, slowly, the same way: south. Toward the Tower."
const GLASS_LOW := "Low. Lower than the night of Northreach's Tear. And not steady — it dips, and recovers, and dips, like breath held and let go."
const GLASS_KNOWN := "You have seen that shape once before. On her bench. Three hundred years ago."
const SEAL_WAKES := "In your satchel, against your hip, the seal on her letter has begun to glow."
const STAIR_LOCKED := "Locked for the festival, as it is every year. Maelis keeps the key."
const STAIR_COUNT := "A hundred and eight steps. You counted them the first year, and have never been able to stop."
const BALCONY_ARRIVE := "Below, they have begun the count to the ninth bell."
const LECTERN_WAIT := "Not yet. There is a woman coming toward you through the crowd."

# --- the cutscene -------------------------------------------------------------------------------
const CUT_NINTH := "The ninth bell."
const CUT_WHAT := "\"What was that? On the hills — did you see?\""
const CUT_CANT_HEAR := "\"I can't hear it. I can't hear it—\""
const CUT_NARRATION := [
	"The Song had never stopped. Not once, in two thousand years.",
	"Every lamp in Astra'Thalas. Every held drop of water. Every heart that had outlived its century.",
	"One note, held — and now it was not.",
]
const CUT_SHE_STAYS := "She sits down beside you on the marble. She does not ask again."
const CUT_SIT := "You do not run. You sit down on the cold marble, among the fallen garlands, and you take out her letter."
const LETTER_FIRST_LINE := "Talindir —\n\nif you are reading this, then what I built has been used."
const LETTER_SIGNED := "E."
const TITLE := "KAYOS"
const SUBTITLE := "THE NIGHT OF SILENCE"
const DEMO_END_TITLE := "END OF DEMO 1"
const DEMO_END_SUB := "The Night of Silence  ·  tap to play again"


# --- the letter (its text changes as the night comes on) -----------------------------------------
static func letter_text(stage: int) -> String:
	match stage:
		0:
			return "Elorin's letter. Folded vellum, your name in her precise, unhurried hand, and a seal of indigo wax — a void, held. Three hundred years you have kept it shut, because she asked you to. 'You will know the night,' she said. You took it out of the cabinet this evening. You have not let yourself look at why."
		1:
			return "The seal is warm. It has never once been warm."
		_:
			return "A thread of gold is running round the wax, as if a lamp were being lit inside it. Her safeguard. She told you it would wake if it ever had to. You do not open it. Not yet."


# --- conversations ------------------------------------------------------------------------------
static func maelis_duty() -> Dictionary:
	return {
		"id": "co2_maelis_duty", "start": "a",
		"nodes": {
			"a": {"speaker": MAELIS, "text": "Talindir. You're still here.", "choices": [
				{"text": "\"Where else would I be?\"", "goto": "b"},
				{"text": "\"The festival doesn't need me, Maelis.\"", "goto": "b"}]},
			"b": {"speaker": MAELIS, "text": "Sorrel has gone down to it. I gave her leave three days ago and forgot I had. Which means that tonight, for the first time in two thousand years, the Record has no hand.", "choices": [
				{"text": "\"Then let it go unwritten, one year.\"", "goto": "c1"},
				{"text": "\"You want me to go up.\"", "goto": "c2"}]},
			"c1": {"speaker": MAELIS, "text": "Two thousand festivals, and not one of them unwritten. I will not be the Archivist who broke the line — and neither, old friend, will you.", "choices": [
				{"text": "(let her go on)", "goto": "d"}]},
			"c2": {"speaker": MAELIS, "text": "I want you to go up. You've watched sixty of them from that balcony with your hands in your sleeves. Tonight you'll watch with a pen in them.", "choices": [
				{"text": "(let her go on)", "goto": "d"}]},
			"d": {"speaker": MAELIS, "text": "The Record's on the high stacks in the Hall — call the lift down for it. It takes star-ink and no other, so fill a horn at the font. And take the Song-glass reading before you go: the Invocation's time is written from it. It always is.", "choices": [
				{"text": "\"And the balcony?\"", "goto": "e"}]},
			"e": {"speaker": MAELIS, "text": "Locked, as every year. I'll be at the cloister gate — the procession passes at the eighth bell, and for once I mean to see it. Come to me for the key.", "choices": [
				{"text": "\"Maelis—\"", "goto": "f"},
				{"text": "\"Go and see your procession.\"", "goto": "g"}]},
			"f": {"speaker": MAELIS, "text": "Hm?", "choices": [
				{"text": "\"...Nothing. Go and see your procession.\"", "goto": "g"}]},
			"g": {"speaker": MAELIS, "text": "She pats your arm on the way past, the way she has for sixty years, and goes out toward the noise.", "set_flags": {"CO2_DUTY_GIVEN": true}},
		},
	}


static func maelis_key() -> Dictionary:
	return {
		"id": "co2_maelis_key", "start": "a",
		"nodes": {
			"a": {"speaker": MAELIS, "text": "There you are. Listen — you can hear them coming up the street. Have you got everything?", "choices": [
				{"text": "\"The Record, the ink, the reading. The glass is low, Maelis.\"", "goto": "b"},
				{"text": "\"Everything. The key?\"", "goto": "c"}]},
			"b": {"speaker": MAELIS, "text": "Low? On the Luminarae?\" She frowns at the sky, and then lets it go, because it is a festival. \"The Song always leans a little toward the Tower on the night. It'll come back when Sulvaine gives it back.", "choices": [
				{"text": "(say nothing)", "goto": "c"}]},
			"c": {"speaker": MAELIS, "text": "Here.\" A small gold key, warm from her hand. \"The balcony's yours. Take a cushion; you're too old to stand for three hours.", "choices": [
				{"text": "\"Maelis. If something were going to happen tonight — something no one could stop — would you want to know?\"", "goto": "d", "set_flags": {"CO2_ASKED_MAELIS": true}},
				{"text": "\"Thank you.\"", "goto": "e"}]},
			"d": {"speaker": MAELIS, "text": "She looks at you for a long moment. \"That's not a festival question.\" Then, quietly: \"No. I think I'd want to be watching the lights.\"", "choices": [
				{"text": "(take the key)", "goto": "e"}]},
			"e": {"speaker": MAELIS, "text": "Go on, then. You'll miss the count.", "set_flags": {"CO2_HAS_KEY": true}},
		},
	}


static func festival_goer() -> Dictionary:
	# the one choice (GDD §4.1): COLDOPEN_HONEST, which echoes to the Coda
	return {
		"id": "coldopen_festivalgoer", "start": "q",
		"nodes": {
			"q": {"speaker": FG, "portrait": PO_FG, "text": "You're not watching the lights, scribe. All of Astra'Thalas is dancing, and you keep looking at the sky like it owes you a debt. Why do you look afraid?", "choices": [
				{"text": "Tell the truth. \"Tonight something ends.\"", "set_flags": {"COLDOPEN_HONEST": true}, "goto": "honest"},
				{"text": "Deflect. \"Just old bones. Go and dance.\"", "set_flags": {"COLDOPEN_HONEST": false}, "goto": "deflect"}]},
			"honest": {"speaker": FG, "portrait": PO_FG, "strain": 5, "text": "She laughs — and then she doesn't. Something in your face stops her. \"That isn't a kind thing to say on a festival night.\" She steps back into the crowd. She does not dance again.", "choices": [
				{"text": "(turn to the rail)", "goto": "end"}]},
			"deflect": {"speaker": FG, "portrait": PO_FG, "text": "\"Old bones! Then sit, grandfather, and let the young ones wear theirs out.\" She spins away, laughing, into the gold and the noise.", "choices": [
				{"text": "(turn to the rail)", "goto": "end"}]},
			"end": {"speaker": TALINDIR, "portrait": PO_TALINDIR, "text": "Overhead, past the festival-glow, the stars are very clear tonight. In your satchel, the seal on a three-hundred-year-old letter is warm as a hand."},
		},
	}


static func lectern_begin() -> Dictionary:
	return {
		"id": "co2_lectern", "start": "a",
		"nodes": {
			"a": {"speaker": "", "text": "The lectern at the rail, where the Record has been opened for two thousand Luminarae. The two-thousandth page is blank.", "choices": [
				{"text": "Open the Record and begin.", "goto": "b"},
				{"text": "Not yet.", "goto": "x"}]},
			"b": {"speaker": "", "text": "You set it down, and open it, and wet the pen. Below, the count reaches eight.", "set_flags": {"CO2_RECORD_OPEN": true}},
			"x": {"speaker": "", "text": "You keep it under your arm a little longer."},
		},
	}


# --- the examinables ----------------------------------------------------------------------------
## name -> text. The director places them (positions in ColdOpenDirector).
const EXAMINE := {
	"Your Desk": "Sixty years of the same chair, worn to the shape of you. Tonight's page is begun and abandoned: 'The two-thousandth Luminarae. The city is —' and there the ink stops, because you could not think of the word.",
	"A Cold Cup": "Long cold, with a skin on it. You made it at the seventh bell, meaning to drink it, and then the light through the window went the colour it goes and you forgot it. It has been a very long time since anything made you forget a cup of tea.",
	"Wax and Matrix": "Your sealing wax is archive-grey, as every scribe's is. But there is one stick of indigo in the bottom of the drawer, and you did not buy it, and it has sat there three hundred years going slowly hard. The matrix that matches it is not here. She kept that. Of course she kept that.",
	"Sorrel's Desk": "Neat, which yours never was at her age. A half-copied inventory, a pressed flower doing duty as a bookmark, and a note in her round hand: 'Back before the ninth — don't tell.' She is nineteen. She has gone to watch the sky catch fire with a boy from the granary. You would not have told.",
	"The Writing Quill": "Sorrel left it copying the inventory, and it goes on without her: the Song moves it the way it moves everything in this city, a little at a time, and never tires. As you watch, it stops mid-word — as if listening — and then goes on.",
	"The Scriptorium Window": "The festival, at a distance and through old glass, which is the way you have taken in most things. The Tower stands in the middle of the window, gold from foot to crown. From here the crowd makes no sound at all.",
	"A Floating Lamp": "You have read by these lamps for sixty years and never once wondered where the light in them comes from, any more than you wonder where the floor comes from. It is the Song. Put your hand near: that faint pressure against your palm is the hum of the world holding itself together. It has never, in two thousand years, so much as stuttered.",
	"Volume the First": "The oldest book in the room, opening the Age of Order with a sentence every apprentice copies out and none of them think about: 'Let it be recorded that on this day the Song was made steady, and will not fail, and there is therefore nothing further to record.' The rest of the volume is blank. He was so nearly right.",
	"The Newest Shelf": "The shelf for the years still to come, built by an optimist two thousand years ago and not yet a third full. There is room on it for another six hundred years of harvest yields. You have never once looked at it and felt what you feel looking at it now.",
	"The Duty Roster": "Tonight's watch, in your own hand. Ninth bell: Sorrel. Tenth: Vashti. Eleventh: the Ferrin boy. Every line struck through, each with the same excuse written small beside it. They are all down there dancing. You did not strike your own name through. Nobody asked you to.",
	"The Stacks — Recent Years": "The last two centuries, in the hands of eleven scribes, four of them yours. Harvest yields. Tower maintenance. A dispute about a boundary wall that ran forty years and was settled by both parties dying. Nothing on these shelves has ever mattered. You have loved them more than you have loved most people.",
	"The Stacks — the Middle Ages": "Eight hundred years compressed into one bay, because so little happened in them. The Age of Order is not a story. It is the absence of one. Somewhere in here is the year you came to this city, and you could find it in a moment, and you never have.",
	"The Orrery": "Gold and bronze planets on their rings, turning round a small gold sun on nothing but the Song. No gears, no weights. Children are brought to see it and told that this is how the world works, and it is.",
	"The Survey of the Songlines": "The Songlines under the city, drawn when someone still thought they were worth surveying: gold veins running out from the Tower to every street and lamp and fountain in Astra'Thalas. It is nine hundred years old. It is the newest one there is.",
	"The Fountain": "The water hangs in the air in six bright arcs, as it has for two thousand years — the Song holds each drop where it is, and the fountain has never once needed to fall. Tonight the arcs are trembling. You would not see it if you had not looked at them every evening for sixty years.",
	"The Street Gate": "Barred for the festival. Through the bars, the street is a river of lanterns — the whole city walking up toward the Tower, singing the old count. Nobody looks at the Archive. Nobody ever has.",
	"A Citrus Tree": "Planted by some Archivist before Maelis, before the one before her. Small, bitter fruit that nobody picks. It flowers in midwinter, because the Song is warm here, and has done so for longer than anyone has thought to be surprised by it.",
	"The Stair Window": "Through the slit: the Tower, whole and gold, closer than it looks. From this high you can see the threads of the Song strung out from it to every lamp in the city, like the strings of an instrument.",
	"Festival Banner": "Gold thread on white silk: THE TWO-THOUSANDTH LUMINARAE. Beneath the sun-sigil, in smaller stitching: 'May the Song hold.' It has held for two thousand years.",
	"A Star-Lamp": "No flame in it. There has never been a flame in it — the Solari hang these and the Song fills them, the way water fills a cup you did not know was empty. Every child in Astra'Thalas learns to cup their hands round one to feel the hum. You do it now, an old man alone at the rail. It hums.",
	"A Child's Sun-Mask": "Gold paper on a willow frame, the sun's nine rays cut out by hand. Dropped in the rush to see the Tower, and already trodden on once. Someone will cry about this tomorrow. You catch yourself on the word — tomorrow — and cannot say why it has gone cold in your mouth.",
	"Sun-Sigil Mosaic": "Gold tesserae, worn pale by two thousand years of feet. The Solari set these into every high place in the city so the Song would always have somewhere to land. You have never been certain whether that is theology or engineering. You have never been certain the Solari know either.",
	"Order of Ceremony": "THE ORDER OF THE TWO-THOUSANDTH LUMINARAE, struck in gold on cheap pulp. The apex is timed to the ninth bell: the Grand Archmage Sulvaine will draw the Song up through the Tower and return it to the city sevenfold. At the foot, in the smallest type the press could set: by the grace of the Song, which is eternal.",
	"The Balustrade": "Marble, worn smooth and faintly hollow at exactly the height of a man's forearms. Two thousand years of people leaning here to look at their own city. Sixty of those years are yours. Below, the whole city moves like one animal breathing, and the threads of the Song run gold over its head.",
	"Initials, Cut in the Rail": "Two sets of initials cut into the underside of the rail, where the wardens would not think to look. The cuts are old. You do not know who they were, and there is no one left to ask. That is the ordinary fate of very nearly everyone. It has never frightened you before tonight.",
	"Two Cups, Left Behind": "Both empty, set side by side on the parapet. Someone brought a friend up here to look at the city and did not stay long. The rims are still sticky — honey, clove, and something floral the Solari have never agreed on a name for.",
	"A Brazier": "Real fire, for once — logs and flame, lit by hand for the festival because the old rites call for it. It is the only light on this balcony the Song did not make. You find you are standing close to it.",
}

## The balcony crowd: name -> [rig, text]. Their lines are the first Cold Open's, verbatim.
const CROWD := [
	["The Lamplighter", "NPC-sol-reveller7", "\"Sixty-first Luminarae I've worked, and there's nothing to light. There's never anything to light. My father held the office, and his mother before him, and not one of us has ever struck a flame in this city.\" He turns his unlit taper over in his hands. \"Tonight of all nights, scribe, I'd like there to be something to light.\""],
	["A Reveller, Well On", "NPC-sol-reveller1", "\"Two thousand years!\" He holds up two fingers, then looks at them, unconvinced. \"Do you know what that is, scribe? That's all of them. That's every year there's ever been.\" He is going to be very unwell tomorrow, and that is the worst thing that is going to happen to him tomorrow."],
	["A Woman, Looking", "NPC-sol-reveller2", "\"Have you seen a boy? So high. Gold mask, the nine rays, he cut it himself and he won't be parted from it.\" She is not frightened yet — it is a festival, and children run. \"He was at the rail a moment ago. He wanted to see the Tower.\""],
	["Two, Leaning", "NPC-sol-reveller6", "\"We came up for the view and stayed for the quiet.\" She does not look away from the city while she says it. \"Don't tell them it's quiet up here. They'll all come.\""],
	["A Solari Celebrant", "NPC-sol-reveller8", "\"The Song is eternal.\" She says it the way you would say the sky is blue — no fervour in it, none needed. \"Say it with me, scribe, it steadies a person. The Song is eternal, and was here before us, and will be here after.\" She smiles at your face. \"You've gone grey. Sit down. It's a festival.\""],
	["A Tower Functionary", "NPC-sol-reveller3", "\"He's been up there since the sixth bell.\" He means Sulvaine; up here tonight everyone means Sulvaine. \"Hasn't eaten. Sent the attendants out.\" He laughs, and it does not come out right. \"They're saying he's nervous. Archmages aren't nervous. It's a ceremony. We've done it two thousand times.\""],
	["A Bored Warden", "NPC-sol-reveller5", "\"Same duty every Luminarae: stop the balcony falling into the street. Two thousand years, and it has never once tried.\" He nods at the crowd, comfortable, incurious, entirely safe."],
	["A Mage of the Tower Choir", "NPC-sol-reveller4", "\"I sang the fourth voice at the Invocation for forty years. They let me watch now.\" She closes her eyes. \"Listen — you can hear him gathering it. Like breath before a shout. Every mage in the city can feel it tonight.\""],
]
