aseprite-pokerogue is a collection of [Lua](https://www.lua.org/) scripts for [Aseprite](https://github.com/aseprite/aseprite), a pixel art tool.  
These scripts are primarily gathered here for the use of developing [PokeRogue](https://github.com/pagefaultgames/pokerogue), and will be tailored for that asset system.

## Contents
#### Scripts
 - `import_folder`: Opens each `.png` in a folder as a Frame of a single Sprite, Tagged with the name of the source `.png`.
 - `import_packed_atlas`: Converts an atlas (spritesheet and animation `.json`) back into a playable series of Frames in a Sprite. Colors Cels to indicate reuse of spritesheet frames. Thanks to _jest_ for the underlying code.
 - `sort_by_order`: Sorts the Palette by the order in which its Colors can be found on the active Sprite.
 - `apply_variant_palettes`: PokeRogue-specific, applies a Pokemon's variant shiny palette map to a spritesheet.
 - `open_pokemon`: PokeRogue-specific, offers an easier interface for finding and opening assets.
#### Utilities
 - `json`: Assorted functions for parsing `.json` files. Thanks to _rxi_.

## Contributing
Please feel free to fork the repository and make pull requests with contributions. 
The `main` branch will be reserved for tools applicable to PokeRogue, but all suggestions are welcome.

## Credits
 - [jest](https://github.com/jestarray/aseprite-scripts)
 - [rxi](https://github.com/rxi/json.lua)
