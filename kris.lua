local kris = {}

function kris.init(mod)

  local GameVersion = require("src.core.GameVersion")
  local isGen2 = GameVersion.generation(GameVersion.get()) == 2

  local PaletteFX = require("src.render.PaletteFX")
  local Json = require("src.link.Json")
  local originalSpriteObp = PaletteFX.spriteObp
  local advancedPack = assert(PaletteFX.gbcPack())

  -- Sprite variant discovery
  -- ----------------------------------
  local SPRITES_DIR = "assets/sprites"

  local function readMeta(key)
    if not key then return {} end
    local metaPath = SPRITES_DIR .. "/" .. key .. "/meta.json"
    if mod.assets:info(metaPath) then
      local ok, decoded = pcall(Json.decode, mod:read(metaPath))
      if ok and type(decoded) == "table" then return decoded end
    end
    return {}
  end

  local function fileVariant(key, name, trueColor)
    if not key then return nil end
    local rel = SPRITES_DIR .. "/" .. key .. "/" .. name
    if mod.assets:info(rel) then
      return { path = rel, trueColor = trueColor }
    end
    return nil
  end

  local function byLabel(a, b)
    return a.label < b.label
  end

  local function toChoicePairs(list)
    local out = {}
    for _, entry in ipairs(list) do
      table.insert(out, { entry.label, entry.key })
    end
    return out
  end

  local function defaultKey(list, preferred)
    for _, entry in ipairs(list) do
      if entry.key == preferred then return preferred end
    end
    return list[1] and list[1].key or preferred
  end

  local battleSpriteVariants = {}
  local frontSpriteVariants = {}
  local battleChoices = {}
  local frontChoices = {}

  -- Groups folders by an optional "character" field in meta.json, so the
  -- options menu can offer "pick a character, then pick that character's
  -- own variants" instead of one flat, ungrouped list. A folder that
  -- doesn't define "character" becomes its own single-variant character
  -- group (falling back to its label, then its folder key) -- this is
  -- exactly today's behavior, so every folder in the Crystal upstream
  -- this framework comes from keeps working unchanged. -Elvie
  -- --------------------------------------------------
  local frontFoldersByCharacter = {}
  local battleFoldersByCharacter = {}

  local function addToCharacter(byCharacter, character, entry)
    byCharacter[character] = byCharacter[character] or {}
    table.insert(byCharacter[character], entry)
  end

  for _, key in ipairs(mod.assets:list(SPRITES_DIR)) do
    local info = mod.assets:info(SPRITES_DIR .. "/" .. key)
    if info and info.type == "directory" then
      local meta = readMeta(key)
      local label = meta.label or key:upper()
      local character = (type(meta.character) == "string" and meta.character ~= "")
        and meta.character or label

      local back = fileVariant(key, "back.png", false)
      local backColor = fileVariant(key, "backColor.png", true)
      local front = fileVariant(key, "front.png", false)
      local frontColor = fileVariant(key, "frontColor.png", true)

      if back or backColor then
        battleSpriteVariants[key] = { dmg = back or backColor, fullColor = backColor or back }
        local entry = { label = label, key = key }
        table.insert(battleChoices, entry)
        addToCharacter(battleFoldersByCharacter, character, entry)
      end
      if front or frontColor then
        frontSpriteVariants[key] = { dmg = front or frontColor, fullColor = frontColor or front }
        local entry = { label = label, key = key }
        table.insert(frontChoices, entry)
        addToCharacter(frontFoldersByCharacter, character, entry)
      end
    end
  end

  table.sort(battleChoices, byLabel)
  table.sort(frontChoices, byLabel)
  for _, byCharacter in ipairs({ frontFoldersByCharacter, battleFoldersByCharacter }) do
    for _, entries in pairs(byCharacter) do
      table.sort(entries, byLabel)
    end
  end

  -- The character list itself: every character with a front and/or battle
  -- folder, deduplicated. -Elvie
  -- --------------------------------------------------
  local characterSet = {}
  for character in pairs(frontFoldersByCharacter) do characterSet[character] = true end
  for character in pairs(battleFoldersByCharacter) do characterSet[character] = true end
  local characterChoices = {}
  for character in pairs(characterSet) do
    table.insert(characterChoices, { label = character, key = character })
  end
  table.sort(characterChoices, byLabel)

  local function sanitizeKey(s)
    return (s:gsub("%W", "_"))
  end

  -- Resolves which folder to actually use for the given character and
  -- asset type: the character's only folder if it has just one, or its
  -- own sub-option's current value if it has several. -Elvie
  -- --------------------------------------------------
  local function resolveCharacterFolder(byCharacter, character, optionKeyPrefix)
    local entries = byCharacter[character]
    if not entries or #entries == 0 then return nil end
    if #entries == 1 then return entries[1].key end
    local optionKey = optionKeyPrefix .. sanitizeKey(character)
    local selected = mod.options:get(optionKey)
    for _, entry in ipairs(entries) do
      if entry.key == selected then return selected end
    end
    return entries[1].key
  end

  local function resolveFrontKey(character)
    return resolveCharacterFolder(frontFoldersByCharacter, character, "frontSpriteFor_")
  end

  local function resolveBattleKey(character)
    return resolveCharacterFolder(battleFoldersByCharacter, character, "battleSpriteFor_")
  end

  -- Resolves the default front sprite path without assuming a specific
  -- folder exists (previously hardcoded to "original", which broke when
  -- that folder was renamed). Falls back to the first available front
  -- variant if the selected option isn't found. -Elvie
  -- --------------------------------------------------
  local function defaultFrontPath()
    local character = mod.options:get("character")
    local selected = resolveFrontKey(character)
    local variant = selected and frontSpriteVariants[selected] and frontSpriteVariants[selected]["dmg"]
    if variant then return mod.assets:path(variant.path) end
    local fallbackKey = frontChoices[1] and frontChoices[1].key
    local fallbackVariant = fallbackKey and frontSpriteVariants[fallbackKey]
      and frontSpriteVariants[fallbackKey]["dmg"]
    return fallbackVariant and mod.assets:path(fallbackVariant.path) or nil
  end

  -- Define mod options
  -- CHARACTER comes first; its own front/battle sprite choices are added
  -- below, one pair per character, each hidden until that character is
  -- selected. -Elvie
  -- ----------------------------------
  local optionRows = {
    {
      key = "character", type = "choice", label = "CHARACTER",
      choices = toChoicePairs(characterChoices), default = defaultKey(characterChoices, "JESSIE")
    },
  }

  -- A character only gets a sprite sub-option if it actually has more than
  -- one folder to choose between -- a single-folder character resolves
  -- straight to it, so there's no pointless one-choice row in the menu. -Elvie
  -- --------------------------------------------------
  for _, character in ipairs(characterChoices) do
    local key = character.key
    local fronts = frontFoldersByCharacter[key]
    local battles = battleFoldersByCharacter[key]
    if fronts and #fronts > 1 then
      table.insert(optionRows, {
        key = "frontSpriteFor_" .. sanitizeKey(key), type = "choice", label = "FRONT SPRITE",
        choices = toChoicePairs(fronts), default = defaultKey(fronts, "original"),
        visible_if = { key = "character", equals = key },
      })
    end
    if battles and #battles > 1 then
      table.insert(optionRows, {
        key = "battleSpriteFor_" .. sanitizeKey(key), type = "choice", label = "BATTLE SPRITE",
        choices = toChoicePairs(battles), default = defaultKey(battles, "original"),
        visible_if = { key = "character", equals = key },
      })
    end
  end

  table.insert(optionRows, {
    key = "colorMode", type = "choice", label = "COLOR PALETTE",
    choices = {
      {"DMG COMPATIBLE", "dmg"},
      {"FULL COLOR", "fullColor"}},
      -- Gen 2's hardware natively supports color, so full color makes a
      -- better default there; Gen 1's default stays DMG-style. -Elvie
      default = isGen2 and "fullColor" or "dmg"
  })

  -- Read once at mod init by starters.lua, which gates its entire body
  -- on this -- like every option here, a change needs a restart to take
  -- effect, so both choice labels say so plainly. -Elvie
  table.insert(optionRows, {
    key = "rocketStarters", type = "choice", label = "ROCKET STARTERS",
    choices = {
      {"OFF (RESTART)", false},
      {"ON (RESTART)", true}},
      default = true
  })

  mod.options:define(optionRows)

  -- Assign player sprite based on mod options
  -- -----------------------------------------
  mod.hooks:wrap("player.sprite", function(next, path, ctx)
    path = next(path,ctx)
    if ctx.demo then return path end

    local colorMode = mod.options:get("colorMode")
    local character = mod.options:get("character")
    local variants, selected

    if ctx.side == "back" then
      variants = battleSpriteVariants
      selected = resolveBattleKey(character)
    elseif ctx.side == "front" then
      variants = frontSpriteVariants
      selected = resolveFrontKey(character)
    else
      return path
    end

    local variant = selected and variants[selected] and variants[selected][colorMode]

    if variant then
      ctx.trueColor = variant.trueColor
      return mod.assets:path(variant.path)

    end
    return path
  end)

  -- Scale sprite
  -- ---------------------------------------------------
  for label, colorModes in pairs(battleSpriteVariants) do
    for colorMode, asset in pairs(colorModes) do
      local labelId = label .. "_" .. colorMode
      mod.content.battle_sprite_scales:register(labelId, {
        path = mod.assets:path(asset.path),
	scale = 1.0,
      })
    end
  end
  

  -- Recoloring the "advanced" color palette
  -- Falls back to this default unless the selected sprite folder
  -- provides its own via meta.json. -Elvie
  -- ------------------------------------------
  local DEFAULT_CRYSTAL_COLORS = {
    {255, 255, 255},
    {239, 204, 175},
    {176, 55, 86},
    {0, 0, 0}
  }

  local function isColorTable(t)
    if type(t) ~= "table" or #t ~= 4 then return false end
    for _, triplet in ipairs(t) do
      if type(triplet) ~= "table" or #triplet ~= 3 then return false end
      for _, v in ipairs(triplet) do
        if type(v) ~= "number" or v < 0 or v > 255 then return false end
      end
    end
    return true
  end

  -- Per-folder overworld, naming, and gender overrides
  -- All follow whichever folder is resolved for the selected character's
  -- front sprite, falling back to defaults when a folder doesn't define
  -- them. -Elvie
  -- --------------------------------------------------
  local DEFAULT_NAME_CHOICES = {"JESSIE", "JAMES", "ROCKET", "GIOVANNI"}
  local DEFAULT_GENDER_MODE = "girl"
  local VALID_GENDER_MODES = { boy = true, girl = true, enby = true }

  local function isNonEmptyStringArray(t)
    if type(t) ~= "table" then return false end
    local count = 0
    for k, v in pairs(t) do
      if type(k) ~= "number" or type(v) ~= "string" or v == "" then return false end
      count = count + 1
    end
    return count > 0
  end

  local overworldKey = resolveFrontKey(mod.options:get("character"))
  local overworldMeta = readMeta(overworldKey)

  local CRYSTAL_COLORS = isColorTable(overworldMeta.overworldColors)
    and overworldMeta.overworldColors or DEFAULT_CRYSTAL_COLORS

  local nameChoices = isNonEmptyStringArray(overworldMeta.nameChoices)
    and overworldMeta.nameChoices or DEFAULT_NAME_CHOICES

  local genderMode = (type(overworldMeta.genderMode) == "string" and VALID_GENDER_MODES[overworldMeta.genderMode])
    and overworldMeta.genderMode or DEFAULT_GENDER_MODE

  -- Overworld sprite files, resolved per file with fallback to
  -- Crystal's stock assets. -Elvie
  -- --------------------------------------------------
  local function overworldAsset(name, fallback)
    local variant = fileVariant(overworldKey, name, false)
    return variant and mod.assets:path(variant.path) or mod.assets:path(fallback)
  end

  local overworldWalk = overworldAsset("overworldWalk.png", "assets/overworld/crystalPlayer.png")
  local overworldBike = overworldAsset("overworldBike.png", "assets/overworld/crystalBike.png")
  local overworldFishSide = overworldAsset("overworldFishSide.png", "assets/overworld/crystalFishSide.png")
  local overworldFishFront = overworldAsset("overworldFishFront.png", "assets/overworld/crystalFishFront.png")
  local overworldFishBack = overworldAsset("overworldFishBack.png", "assets/overworld/crystalFishBack.png")

  -- Intercepts the sprite renderer if the sprite is assigned a matching palette source and applies the CRYSTAL_COLORS palette to the sprite. 
  -- Hands the request back to the original sprite renderer if any other sprite.
  PaletteFX.spriteObp = function(spriteDef, seed)
    if spriteDef and spriteDef.paletteSource == "PLAYER_PALETTE" then
      return CRYSTAL_COLORS, "crystalPlayer"
      end
    
    if originalSpriteObp then
      return originalSpriteObp(spriteDef, seed)
      end
  end

  -- Same rendering interception but for Gen 2, gated on isGen2. This
  -- manifest also loads on plain Gen 1, and the engine unconditionally
  -- refuses to require any src.*.gen2.* module while a Gen 1 game is
  -- active (Loader.lua's crossGenerationDenial) -- an earlier unconditional
  -- version of this crashed mod load on Red/Blue. Patched once here rather
  -- than in game.ready, since Palettes has no game-instance dependency and
  -- game.ready can fire more than once a session (dev hot-reload). -Elvie
  -- -----------------------------------------
  if isGen2 then
    local Palettes = require("src.world.gen2.Palettes")
    local originalSpritePalette = Palettes.spritePalette
    Palettes.spritePalette = function(data, daytime, spriteDef, objDef)
      if spriteDef and spriteDef.paletteSource == "PLAYER_PALETTE" then
        return CRYSTAL_COLORS
      end
      return originalSpritePalette(data, daytime, spriteDef, objDef)
    end
  end

  -- Gen 2's fishing animation does not go through the sprite registry at
  -- all: it reads a fixed sheet path from gen2MenuGfx.emotes.fishing,
  -- loaded once at boot straight from generated data with no content
  -- registry in between, so there is nothing to override there. What can
  -- be overridden is Player:drawFishing itself, the method that actually
  -- draws it, the same way TrainerCard:drawPortrait was overridden above.
  -- A folder can optionally provide fishing.png/fishingColor.png matching
  -- the same 16x32 layout the vanilla sheet uses (three 16x8 pose frames
  -- stacked for down/up/side, then two 8x8 rod frames side by side at the
  -- bottom) documented in the README. If a folder does not provide one,
  -- this calls straight through to the original method, so fishing looks
  -- like vanilla Chris until a folder opts in. ROD_OAM and FISH_ROW are
  -- copied from Player.lua's own local tables so the custom sheet
  -- positions and animates identically to the vanilla one. -Elvie
  -- -----------------------------------------------
  if isGen2 then
    local Player = require("src.world.gen2.Player")
    local originalDrawFishing = Player.drawFishing
    local ROD_OAM = {
      down  = { dx =  0, dy = 16, tile = 0 },
      up    = { dx =  0, dy = -8, tile = 0 },
      left  = { dx = -8, dy =  5, tile = 1, flip = true },
      right = { dx = 16, dy =  5, tile = 1 },
    }
    local FISH_ROW = { down = 0, up = 1, left = 2, right = 2 }

    Player.drawFishing = function(self, yOffset)
      local colorMode = mod.options:get("colorMode")
      local dmg = fileVariant(overworldKey, "fishing.png", false)
      local color = fileVariant(overworldKey, "fishingColor.png", true)
      local variant = (dmg or color) and { dmg = dmg or color, fullColor = color or dmg }
      local fishingVariant = variant and variant[colorMode]
      if not fishingVariant then
        return originalDrawFishing(self, yOffset)
      end

      local sprite = self.sprite
      local py = self.py + yOffset
      local facing = self.facing
      sprite:draw(self.px, py, 0, 0, facing, 0, false, true)
      if not self.fishQuads then
        self.fishQuads = { pose = {}, rod = {} }
        for i = 0, 2 do
          self.fishQuads.pose[i] = love.graphics.newQuad(0, i * 8, 16, 8, 16, 32)
        end
        for i = 0, 1 do
          self.fishQuads.rod[i] = love.graphics.newQuad(i * 8, 24, 8, 8, 16, 32)
        end
      end
      local sx, sy = sprite:getScreenOrigin(self.px, py, 0, 0)
      sprite:drawTile(fishingVariant.path, sx,
        sy + math.max(0, sprite.frameHeight - 8), facing == "right",
        self.fishQuads.pose[FISH_ROW[facing] or 0])
      local oam = ROD_OAM[facing] or ROD_OAM.down
      sprite:drawTile(fishingVariant.path, sx + oam.dx, sy + oam.dy, oam.flip,
        self.fishQuads.rod[oam.tile])
    end
  end
  
    
  -- Overworld sprite replacements
  -- Gen 1's SPRITE_RED and Gen 2's SPRITE_CHRIS get identical treatment,
  -- so this applies both together instead of duplicating the patch per
  -- generation. Same for their bike variants. -Elvie
  -- --------------------------
  for _, spriteId in ipairs({ "SPRITE_RED", "SPRITE_CHRIS" }) do
    mod.content.sprites:patch(spriteId, {
      image = overworldWalk,
      trueColor = false,
      paletteSource = "PLAYER_PALETTE",
    })
  end

  for _, spriteId in ipairs({ "SPRITE_RED_BIKE", "SPRITE_CHRIS_BIKE" }) do
    mod.content.sprites:patch(spriteId, {
      image = overworldBike,
      trueColor = false,
      paletteSource = "PLAYER_PALETTE",
    })
  end

  -- Gen 1-only field registry patches. The field registry has no Gen 2
  -- target -- Gen 2's naming and title-screen equivalents are handled
  -- separately below via game.ready. Gating these explicitly makes that
  -- boundary part of the code instead of a runtime warning to discover. -Elvie
  -- --------------------------
  if not isGen2 then
    local frontPath = defaultFrontPath()

    mod.content.field:patch("playerPics", {
      front = frontPath
    })

    mod.content.field:patch("overworldFx", {
      redFishSide  = { path = overworldFishSide },
      redFishFront = { path = overworldFishFront },
      redFishBack  = { path = overworldFishBack },
    })

    mod.content.field:override("boot", {
      namePresets = {
        player = nameChoices
      }
    })

    mod.content.field:patch("boot", {
      title = {
        player = frontPath,
        versionRibbon = mod.assets:path("assets/menus/krisEdition.png"),
      },
    })
  end

  -- Gen 2 Trainer Card
  -- Registered under its own distinct screen id, so no Gen1/Gen2 gating
  -- is needed here the way the field registry patches above need it --
  -- nothing on Gen 1 would ever request "Gen2TrainerCard".
  --
  -- The portrait isn't a normal image on this screen: TrainerCard draws it
  -- from 35 individual 8x8 tiles baked into specific indices of the SAME
  -- tilesheet the frame itself uses (confirmed from TrainerCard.lua's own
  -- comments -- even one of the frame's own tiles, the top-right notch, is
  -- borrowed from that 35-tile range). Replacing the whole tilesheet to
  -- swap the portrait meant also having to recreate the frame's tile
  -- layout exactly right, and any mismatch there is what produced the
  -- fragmented, scrambled look. Keeping the real vanilla tilesheet (frame,
  -- dividers, ID No tiles, all correct by construction, straight from the
  -- game's own extracted data) and overriding drawPortrait to paint the
  -- resolved front sprite directly, as a normal image, avoids that whole
  -- class of tile-index bugs entirely -- a "blank card + overlay," just
  -- implemented as a method override instead of a second image file. -Elvie
  -- -----------------------------------------------
  mod.content.screens:register("Gen2TrainerCard", {
    new = function(game, opts)
      local TrainerCard = require("src.ui.gen2.TrainerCard")
      local instance = TrainerCard.new(game, opts)

      -- Portrait tile box: (14,1) to (18,7) in 8px tiles = 40x56 pixels.
      -- A folder can optionally provide trainerCard.png/trainerCardColor.png
      -- (checked in the same folder as the front sprite) purpose-built for
      -- this box; if it doesn't, this falls back to the same front sprite
      -- used everywhere else -- same fallback pattern as the overworld
      -- files above. Drawn at native size, centered, relying on
      -- transparency around the character rather than scaling to fill --
      -- easy to swap back to scale-to-fill (boxW / iw, boxH / ih) if this
      -- looks worse in practice for art that isn't purpose-built. -Elvie
      -- -----------------------------------------------
      local colorMode = mod.options:get("colorMode")
      local dedicatedDmg = fileVariant(overworldKey, "trainerCard.png", false)
      local dedicatedColor = fileVariant(overworldKey, "trainerCardColor.png", true)
      local dedicated = (dedicatedDmg or dedicatedColor)
        and { dmg = dedicatedDmg or dedicatedColor, fullColor = dedicatedColor or dedicatedDmg }
      local portraitVariant = (dedicated and dedicated[colorMode])
        or (frontSpriteVariants[overworldKey] and frontSpriteVariants[overworldKey][colorMode])

      instance.drawPortrait = function()
        if not portraitVariant then return end
        local image = mod.assets:image(portraitVariant.path)
        if not image then return end
        local iw, ih = image:getDimensions()
        local boxX, boxY, boxW, boxH = 14 * 8, 1 * 8, 40, 56
        local drawX = boxX + (boxW - iw) / 2
        local drawY = boxY + (boxH - ih) / 2
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, drawX, drawY)
      end

      return instance
    end,
  })
   
  -- Gen 2 naming options, pulled from nameChoices above. The field
  -- registry has no Gen 2 target (see above), so this writes directly to
  -- game.data instead -- the same namePresets shape OakSpeech reads for
  -- both generations, just reached a different way here. -Elvie
  -- --------------------------------------------------
  mod.events:on("game.ready", function(ev)
    local game = ev.game
    local palettes = game.data.gen2Palettes
    game.data.field = game.data.field or {}
    game.data.field.boot = game.data.field.boot or {}
    game.data.field.boot.namePresets = {
      player = nameChoices
    }
    if palettes and palettes.trainers then
      palettes.trainers.CAL = nil
    end
  end)

  -- Crystal shows a native gender-choice screen when its sprite cache
  -- carries Kris data (Gold/Silver never do, so they never get the step).
  -- Appearance here comes entirely from the selected sprite folder, so
  -- this strips that step out -- a no-op on Gen 1 and Gold/Silver, where
  -- it never existed. Skipping it defaults gender to "male" (Save.lua's
  -- own fallback), which is what SPRITE_CHRIS above is patched for. -Elvie
  -- --------------------------------------------------
  mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
    steps = next(steps, speech)
    return mod.ui.removeStep(steps, "gender_select")
  end)

  -- Hands the resolved config back to main.lua so it can choose
  -- girlMode, nbMode, or neither. -Elvie
  -- --------------------------------------------------
  return {
    nameChoices = nameChoices,
    genderMode = genderMode,
  }

end

return kris
