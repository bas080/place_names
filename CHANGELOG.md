# Changelog

## 0.0.0

- Create named places with `/placeadd`
- Rename places with `/placeedit`
- Remove places with `/placeremove`
- Move place center with `/placepos`
- Adjust place size with `/placeradius`
- Toggle boundary overlay with `/placeoverlay`
- Automatic detection of current place based on player position
- HUD display showing the active place name
- Supports overlapping places:
  - Smaller radius takes priority
  - If equal, closest center is chosen
- Persistent storage in `world/places.json`
- Automatic load/save of all place data
- Optional particle-based boundary overlay for active place
- `place_edit` privilege for all modification actions
  - Enabled by default in singleplayer
