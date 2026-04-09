# Place Names

Luanti Mod that adds command to create, edit place names that are visible on player hud.

## How it works

* Places are stored in `world/places.json`
* Each place has:

  * `name`
  * `pos` (center)
  * `radius` (applies in all directions → cube region)
* Default radius is `10`

When multiple places overlap:

* The smallest radius wins
* If equal, the closest center wins


## Permissions

* `place_edit` – required to create, modify, or delete places
  (granted automatically in singleplayer)


## Commands

* `/placeadd <name>`
  Create a new place at your current position.

* `/placeedit <name>`
  Rename the place you are currently inside.

* `/placeremove`
  Delete the place you are currently inside.

* `/placepos`
  Move the center of the current place to your position.

* `/placeradius <radius>`
  Set the size of the current place.

* `/placeoverlay`
  Toggle a visual boundary overlay for the current place.

### HUD

* The current place name is displayed at the top of the screen
* Updates automatically as the player moves

### Overlay

* Shows a temporary particle outline of the current place
* Useful for visualizing boundaries
* Only visible when enabled per player via `/placeoverlay`

### Notes

* Radius defines a cube, not a sphere
* All changes are saved immediately to disk
* If no place is found, commands will fail with a message
