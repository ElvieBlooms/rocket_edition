# Team Rocket Edition - Character Pack
A player sprite character pack for gen1recomp++, built on the modding framework from [dburton95/crystal](https://github.com/dburton95/crystal), used with the original author's permission.

Where Crystal packages a single player character (and multiple outfit choices and variations), this pack uses the same framework to bundle a full Team Rocket roster — Jessie, James, the Jessie/James/Meowth trio, both Rocket Grunts, and Giovanni — as selectable player sprites, each with its own name choices, text, and overworld palette.

<img width="823" height="740" alt="rocketEdition" src="https://github.com/user-attachments/assets/ea3eb97c-247a-49a8-8c3c-d19a07475b70" />
<img width="1022" height="740" alt="rocketEdition2" src="https://github.com/user-attachments/assets/dbedb0ee-528c-4a22-91a1-53f63e6c5c5c" />
<img width="1023" height="739" alt="rocketEdition3" src="https://github.com/user-attachments/assets/0ff179ea-5310-40a0-868d-2cb863f3de20" />

## Characters
| Character | Status |
|---|---|
| Jessie | Available |
| James | Custom sprites in progress |
| Jessie/James/Meowth Trio | Custom sprites in progress |
| Rocket Grunt (Male) | Custom sprites in progress |
| Rocket Grunt (Female) | Custom sprites in progress |
| Giovanni | Custom sprites in progress |

- Placeholder Crystal Clear community sprites will be used as placeholders for the interim where applicable

Each character is its own sprite folder under `assets/sprites/`, selected the same way Crystal's own sprite variants are — through the **BATTLE SPRITE** and **FRONT SPRITE** options in the mod's settings menu.

## Companion voice pack
Each character in this pack, including the Jessie/James/Meowth trio, will have a matching voice pack in [Trainer Talk](https://github.com/ElvieBlooms/trainer_talk) coming in the near future -- an optional add-on for extra immersion, not required to use this pack.

## Features
* Bike sprite
* Fishing sprite
* Battle sprites (front and back)
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

## What works in Gold
* Full color overworld sprite
* Full color bike sprite (untested but should work)
* Credits
* Battle sprite choices
* Full color sprites in the battle engine
* Per-character re-gendering of the text

## What doesn't work in Gold
* Overworld sprite doesn't support DMG palettes yet (you can use the DMG palette -- the sprite will just be the only thing in full color)
* Player name options still show Gold's defaults (for now)

## Compatibility
This pack is built as its own standalone player sprite mod, using the same framework as the Crystal base mod. Since both mods patch the same player sprites and define the same options, running this pack alongside Crystal will likely conflict. If you'd like to use both, copy the contents of this pack's `assets` folder into Crystal's own `assets` folder rather than installing them as two separate mods. A zip file of the assets will be available in releases for that purpose.


## Credits
This pack's mod framework -- sprite folder discovery, options menu integration, overworld/color/naming/gender overrides -- is built on [dburton95/crystal](https://github.com/dburton95/crystal), used with permission. All Team Rocket character sprites, text, and roster additions are original to this pack.
