# Team Rocket Edition - Character Pack
A player sprite character pack and starter-opening story mod for gen1recomp++, built on the modding framework from [dburton95/crystal](https://github.com/dburton95/crystal), used with the original author's permission.

Where Crystal packages a single player character (and multiple outfit choices and variations), this pack uses the same framework to bundle a full Team Rocket roster — Jessie, James, the Jessie/James/Meowth trio, both Rocket Grunts, and Giovanni — as selectable player sprites, each with its own name choices, text, and overworld palette. On top of that, this pack changes the game's own opening so you actually start your journey as one of Team Rocket's own Pokémon, with a full story to match, across every generation the pack supports (Red/Blue, Yellow, Gold, Silver, and Crystal).

<img width="823" height="740" alt="rocketEdition" src="https://github.com/user-attachments/assets/ea3eb97c-247a-49a8-8c3c-d19a07475b70" />
<img width="1022" height="739" alt="rocketEdition7" src="https://github.com/user-attachments/assets/6ac008bc-8c8b-4848-b224-7d6e5fcbe0d5" />
<img width="1026" height="744" alt="Screenshot_20260827_170217" src="https://github.com/user-attachments/assets/0c430344-4a96-420e-9dbf-b812757bd238" />

## Characters
| Character | Status |
|---|---|
| Jessie | Available |
| James | Available |
| Jessie/James/Meowth Trio | Available |
| Rocket Grunt (Male) | Custom sprites in progress |
| Rocket Grunt (Female) | Custom sprites in progress |
| Giovanni | Custom sprites in progress |

- Placeholder Crystal Clear community sprites will be used as placeholders for the interim where applicable

Each character is its own sprite folder under `assets/sprites/`, selected the same way Crystal's own sprite variants are — through the **BATTLE SPRITE** and **FRONT SPRITE** options in the mod's settings menu.

## Team Rocket Starters
Instead of the usual three, your very first Pokémon comes from Team Rocket — with a story explaining why, unique to each generation this pack supports. This can be turned off from the mod's settings menu (**ROCKET STARTERS**, on by default) if you'd rather keep the vanilla starters and story while still using the sprite pack; changing it needs a restart to take effect.

### Red/Blue: Koffing, Meowth, Ekans
Oak stops you before you can leave Pallet Town — Team Rocket is watching him, and the three Pokémon in his lab aren't the usual ones. Choosing one still triggers the normal rival counter-pick and lab battle, just with Rocket's own line-up: Koffing's rival counter-pick is Meowth, Meowth's is Ekans, and Ekans' is Koffing, matching the same type-triangle positions the vanilla starters use.(The canonical Chamander/Squirtle/Bulbasaur trio ends up in your PC box, so nothing is lost if you'd rather raise one of them alongside your Rocket starter.) Your rival's Rocket-mon evolves and keeps pace with them the whole game (Koffing → Weezing at 35, Meowth → Persian at 28, Ekans → Arbok at 22). The parcel-fetching errand and Pokédex handoff are re-themed to match, ending on the same note the whole story is building toward — that whatever Team Rocket set in motion, the rest of the journey is yours to choose.

### Yellow: Pikachu and Eevee, story only
Yellow's own mechanics — catching Pikachu outside Pallet Town, the single Eevee ball, the rival shoving you aside to steal it — are left completely untouched. Only the dialogue changes: the Eevee was Team Rocket's gift, meant to test you, and your rival takes it before you ever get the chance. Oak gives you the Pikachu he caught instead, and the rest of the intro (the parcel errand, the Pokédex handoff) is re-themed around that same idea of an opening you didn't choose, and a journey you do.

### Gold, Silver, and Crystal: Houndour, Spinarak, Snubbull
An unaddressed package arrives at Elm's lab with three Pokémon inside and no explanation — Elm asks for your help figuring out what to do with them. Choosing one triggers the usual rival counter-pick (Houndour's counter-pick is Spinarak, Spinarak's is Snubbull, Snubbull's is Houndour), and your rival's Rocket-mon evolves right alongside them (Houndour → Houndoom at 24, Spinarak → Ariados at 22, Snubbull → Granbull at 23). (The canonical Chikorita/Cyndaquil/Totodile trio still ends up in your PC box, just like in Gen 1.) After you return the Mystery Egg and the story's larger threads tie off, a final anonymous phone call on Route 29 closes out the mystery — for now.

## Companion voice pack
Each character in this pack, including the Jessie/James/Meowth trio, will have a matching voice pack in [Trainer Talk](https://github.com/ElvieBlooms/trainer_talk) coming in the near future -- an optional add-on for extra immersion, not required to use this pack.

## Features
* Bike sprite
* Fishing sprite
* Battle sprites (front and back)
* Team Rocket starter Pokémon and story, with its own on/off toggle in the settings menu -- see "Team Rocket Starters" above
* Voxel Mod support -- mostly working.
  * The fishing sprite breaks with voxel. This looks like a pre-existing issue on the original sprite too, not something specific to this pack.
* Per-character name options in Oak's dialogue -- each character can define its own new-game name choices instead of the game's defaults
* Per-character gendering -- Dialogue and other text can be set to vanilla (male), re-gendered female, or gender-neutral phrasing independently for each character
* All sprites have an SGB-compatible mode as well as a full color mode
* Bring your own front and back sprites, in the same folder-based format Crystal uses

## How sprite folders work
* Each character lives in its own folder at `assets/sprites/FOLDER_NAME_HERE`
  * The folder name can't contain spaces -- the mod uses it as the option key.
  * Inside the folder:
    * `back.png`
    * `backColor.png`
    * `front.png`
    * `frontColor.png`
    * `meta.json`
    * As long as either `back.png` or `backColor.png` is present, the other is optional -- the mod falls back automatically if a sprite is missing. Same for `front.png`/`frontColor.png`.
* `meta.json` needs at least a `label` key -- this is the name shown for that character in the options menu.

### Example meta.json file
```json
{
  "label": "JESSIE"
}
```

### Overworld sprites, colors, names & gender
A character's folder can also optionally include any of these files to replace its walking, bike, and fishing overworld sprites:
* `overworldWalk.png`
* `overworldBike.png`
* `overworldFishSide.png`
* `overworldFishFront.png`
* `overworldFishBack.png`

And its `meta.json` can optionally set any of these keys:
* `overworldColors` -- array of exactly four `[r, g, b]` triplets (0-255) overriding the recolor palette applied to the sprites above.
* `nameChoices` -- array of strings shown as name choices at the start of a new game (Gen 1 and Gold).
* `genderMode` -- one of `"boy"` (vanilla text), `"girl"` (re-gendered text), or `"enby"` (gender-neutral text).

All of the above -- the five overworld files and the three meta.json keys -- apply only to whichever character is currently selected as **FRONT SPRITE** in the options menu (the same selection the title screen image uses), not to every character at once. Anything a character's folder doesn't supply falls back to the pack's defaults. Like the title screen sprite, all of this is resolved once when the mod loads, from whichever FRONT SPRITE is selected at that time -- changing FRONT SPRITE mid-session won't update it without a restart.

```json
{
  "label": "JAMES",
  "nameChoices": ["JAMES", "ANDREW"],
  "genderMode": "boy",
  "overworldColors": [[255, 255, 255], [111, 90, 165], [40, 20, 70], [0, 0, 0]]
}
```

## Crystal
Crystal is a supported game version, sprite pack and starter story alike. Crystal has its own native gender-choice screen (choosing between Chris and Kris) that Gold and Silver never had; since your appearance here already comes from your selected sprite folder, that screen is skipped automatically so it doesn't ask a second, separate question. Because we skip it your save will be defaulted to male but the text overrides from girl and enby mode will be applied based on the sprite folder you utilize. 

## Compatibility
This pack is built as its own standalone player sprite mod, using the same framework as the Crystal base mod. Since both mods patch the same player sprites and define the same options, running this pack alongside Crystal will likely conflict. If you'd like to use both, copy the contents of this pack's `assets` folder into Crystal's own `assets` folder rather than installing them as two separate mods. A zip file of the assets will be available in releases for that purpose.


## Credits
This pack's mod framework -- sprite folder discovery, options menu integration, overworld/color/naming/gender overrides -- is built on [dburton95/crystal](https://github.com/dburton95/crystal), used with permission. The Gen 2 starter-ball script handling follows patterns verified in [inmento's Starter Picker](https://github.com/inmento/Starter-Picker) mod, used with permission. All Team Rocket character sprites, text, the starter Pokémon story, and roster additions are original to this pack.
