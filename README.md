# Place Names

Luanti Mod that adds commands to create, edit, and manage named places visible on the player HUD. Includes a public API for other mods.

## How it works

* Places are stored in `world/places.json`
* Each place has:
  * `name` (string)
  * `min` (vector: minimum corner)
  * `max` (vector: maximum corner)
* Places are axis-aligned bounding boxes
* Creation uses raycasting to detect walkable surfaces around the player for automatic bounds

When multiple places overlap at a position:

* The first matching place in the internal list is returned
* Use the API for more control if needed

## Permissions

* `place_edit` – required to create, modify, or delete places
  (granted automatically in singleplayer)

## Commands

* `/place_name <name>`
  Create a new place at your current position using raycast to determine bounds.

* `/place_rename <new name>`
  Rename the place you are currently inside.

* `/place_remove`
  Delete the place you are currently inside.

* `/place_move`
  Resize/move the current place to new bounds determined by raycast from your position.

* `/place_overlay`
  Toggle a visual particle outline of the current place boundaries.

### HUD

* The current place name is displayed at the top center of the screen
* Updates automatically as the player moves
* Triggers enter/leave events for mods using the API

### Overlay

* Shows a temporary particle outline of the current place
* Useful for visualizing boundaries
* Only visible when enabled per player via `/place_overlay`

## API

Other mods can interact with places using the global `place_names` table.

### Functions

* `place_names.register_place(name, min, max)`
  Creates a new place with the given name and bounding box.
  Returns the place object or `nil` on error.

* `place_names.get_place(pos)` / `place_names.get_place_by_pos(pos)`
  Returns the place at the given position, or `nil` if none.

* `place_names.get_place_by_name(name)`
  Returns the first place with the given name, or `nil` if none.

* `place_names.get_current_place(player)`
  Returns the place the player is currently in, or `nil`.

* `place_names.get_all_places()`
  Returns a table of all places.

* `place_names.register_on_place_enter(func)`
  Registers a callback function called when a player enters a place.
  `func(player, place)` is called on enter.
  Returns a function that unregisters the callback when called.

* `place_names.register_on_place_leave(func)`
  Registers a callback function called when a player leaves a place.
  `func(player, place)` is called on leave.
  Returns a function that unregisters the callback when called.

### Place Object Methods

Place objects returned by the API have these methods:

* `place:remove()`
  Removes the place.

* `place:rename(new_name)`
  Renames the place.

* `place:set_bounds(min, max)`
  Changes the place's bounding box.

* `place:get_center()`
  Returns the center position as a vector.

* `place:get_size()`
  Returns the size vector (max - min).

### Example Usage

```lua
-- Create a place
local min = {x=0, y=0, z=0}
local max = {x=10, y=10, z=10}
local place = place_names.register_place("My Place", min, max)

-- Get place by position
local place_at_pos = place_names.get_place_by_pos({x=5, y=5, z=5})

-- Get place by name
local place_by_name = place_names.get_place_by_name("My Place")

-- Get all places
local all_places = place_names.get_all_places()

-- Get current place
local current = place_names.get_current_place(player)

-- Listen for enter/leave
local unregister_enter = place_names.register_on_place_enter(function(player, place)
    minetest.chat_send_player(player:get_player_name(), "Entered " .. place.name)
end)

-- Later, unregister the callback
unregister_enter()

-- Modify a place
if current then
    current:rename("New Name")
    current:set_bounds(new_min, new_max)
end
```

## Notes

* Bounds define an axis-aligned box, not a sphere
* All changes are saved immediately to `places.json`
* Raycasting for commands detects walkable nodes in all directions from the player
* If no place is found, commands will fail with a message
* The API allows programmatic creation and management for advanced use cases
