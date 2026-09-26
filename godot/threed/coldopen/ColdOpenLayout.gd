extends RefCounted
class_name ColdOpenLayout
## Where everything in Cold Open v2 is. The builders, the director, the cutscene and the tests all read
## these numbers, so the Archive a player walks and the one the camera flies past are the same place.
##
## 1 unit = 1 m (docs/Scale_Reference.md). Y up. The Archive's ground floor is y = 0. −Z points at the
## Tower of Celestial Harmony: the scriptorium's great window, the balcony's rail and the cutscene all
## look that way.
##
##   z −17 ┌──────── BALCONY (y 18) ────────┐          the Tower is 210 m further on, at z −225
##         │  flanking towers at x ±11..±17  │
##   z −3  └──────────────┬──────────────────┘
##   ┌ CLOISTER ┐┌STAIR ┐ │ SCRIPTORIUM (x −8..8, z −2..28): Talindir's desk; the window looks at the Tower
##   │ x −56..−31││TOWER │ │
##   │ z −8..39  ││x−30..│ │
##   │ open sky, ││ −12  │ │
##   │ fountain, │└──────┘ │
##   │ bell, gate│         │
##   │ to street ├─────────┴──── HALL OF RECORDS (x −30..24, z 29..39): stacks, book-lift, orrery,
##   └───────────┘                the Song-glass

# --- the scriptorium ----------------------------------------------------------------------------
const SCR_X := 8.0                 # interior half-width
const SCR_Z0 := -2.0               # window end (inner face)
const SCR_Z1 := 28.0               # door end (inner face)
const SCR_SPRING := 9.0            # where the vault springs
const SCR_RISE := 5.0              # vault rise
const WALL := 1.0

# --- the Hall of Records ------------------------------------------------------------------------
const HALL_X0 := -30.0
const HALL_X1 := 24.0
const HALL_Z0 := 29.0
const HALL_Z1 := 39.0
const HALL_H := 12.0

# --- the cloister -------------------------------------------------------------------------------
const CLO_X0 := -56.0
const CLO_X1 := -31.0
const CLO_Z0 := -9.0
const CLO_Z1 := 39.0
const CLO_ARCADE := 4.0            # depth of the covered walk round the garth
const CLO_ROOF := 6.0

# --- the stair tower ----------------------------------------------------------------------------
const STAIR_X0 := -30.0
const STAIR_X1 := -12.0
const STAIR_Z0 := -9.0
const STAIR_Z1 := -2.0
const FLIGHT_RISE := 6.0
const FLIGHT_RUN := 10.4           # 30° — a CharacterBody3D climbs it with room to spare
const STAIR_W := 3.0
const STAIR_FOOT_X := -27.0        # west landings run from the wall to here
const STAIR_HEAD_X := -16.6        # east landings run from here to the wall

# --- the balcony --------------------------------------------------------------------------------
const BAL_Y := 18.0
const BAL_X := 11.0                # half-width
const BAL_Z0 := -17.0              # the rail
const BAL_Z1 := 4.0                # the back wall (the terrace runs back over the scriptorium roof)
const MOSAIC := Vector3(0.0, BAL_Y, -10.0)
const MOSAIC_R := 4.2
const RAIL_H := 1.1

# --- the city and the Tower ---------------------------------------------------------------------
const PLAZA_Y := -34.0
const TOWER := Vector3(0.0, PLAZA_Y, -225.0)
const TOWER_R := 24.0
const TOWER_H := 184.0             # base to the apex platform (galleries, the spire, the crown)
const APEX_Y := PLAZA_Y + TOWER_H
const THREAD_HUB_Y := PLAZA_Y + 118.0

# --- where things are ---------------------------------------------------------------------------
const SPAWN := Vector3(-3.2, 0.0, 21.0)            # at his desk, facing the window
const DESK := Vector3(-3.2, 0.0, 19.4)
const INK_FONT := Vector3(6.4, 0.0, 13.0)
const QUILL_DESK := Vector3(3.2, 0.0, 9.5)
const BOOK_LIFT := Vector3(-6.0, 0.0, 37.2)
const ORRERY := Vector3(16.0, 0.0, 34.0)
const SONG_GLASS := Vector3(9.5, 0.0, 36.8)
const FOUNTAIN := Vector3(-43.5, 0.0, 15.0)
const BELL := Vector3(-43.5, 0.0, 33.0)
const GATE := Vector3(-56.5, 0.0, 15.0)
const ARCHIVIST := Vector3(-52.0, 0.0, 17.5)
const STAIR_DOOR := Vector3(-30.5, 0.0, -5.5)
const BAL_DOOR := Vector3(-11.5, BAL_Y, -5.5)
const LECTERN := Vector3(0.0, BAL_Y, -15.2)
const BAL_SPAWN := Vector3(-9.2, BAL_Y, -5.5)
