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
    local metaPath = SPRITES_DIR .. "/" .. key .. "/meta.json"
    if mod.assets:info(metaPath) then
      local ok, decoded = pcall(Json.decode, mod:read(metaPath))
      if ok and type(decoded) == "table" then return decoded end
    end
    return {}
  end

  local function fileVariant(key, name, trueColor)
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

  for _, key in ipairs(mod.assets:list(SPRITES_DIR)) do
    local info = mod.assets:info(SPRITES_DIR .. "/" .. key)
    if info and info.type == "directory" then
      local meta = readMeta(key)
      local label = meta.label or key:upper()

      local back = fileVariant(key, "back.png", false)
      local backColor = fileVariant(key, "backColor.png", true)
      local front = fileVariant(key, "front.png", false)
      local frontColor = fileVariant(key, "frontColor.png", true)

      if back or backColor then
        battleSpriteVariants[key] = { dmg = back or backColor, fullColor = backColor or back }
        table.insert(battleChoices, { label = label, key = key })
      end
      if front or frontColor then
        frontSpriteVariants[key] = { dmg = front or frontColor, fullColor = frontColor or front }
        table.insert(frontChoices, { label = label, key = key })
      end
    end
  end

  table.sort(battleChoices, byLabel)
  table.sort(frontChoices, byLabel)

  -- Resolves the default front sprite path without assuming a specific
  -- folder exists (previously hardcoded to "original", which broke when
  -- that folder was renamed). Falls back to the first available front
  -- variant if the selected option isn't found. -Elvie
  -- --------------------------------------------------
  local function defaultFrontPath()
    local selected = mod.options:get("frontSprite")
    local variant = frontSpriteVariants[selected] and frontSpriteVariants[selected]["dmg"]
    if variant then return mod.assets:path(variant.path) end
    local fallbackKey = frontChoices[1] and frontChoices[1].key
    local fallbackVariant = fallbackKey and frontSpriteVariants[fallbackKey]
      and frontSpriteVariants[fallbackKey]["dmg"]
    return fallbackVariant and mod.assets:path(fallbackVariant.path) or nil
  end

  -- Define mod options
  -- ----------------------------------
  mod.options:define({
    {
      key = "battleSprite", type = "choice", label = "BATTLE SPRITE",
      choices = toChoicePairs(battleChoices), default = defaultKey(battleChoices, "original")
    },
    {
      key = "frontSprite", type = "choice", label = "FRONT SPRITE",
      choices = toChoicePairs(frontChoices), default = defaultKey(frontChoices, "original")
    },
    {
      key = "colorMode", type = "choice", label = "COLOR PALETTE",
       choices = {
         {"DMG COMPATIBLE", "dmg"},
         {"FULL COLOR", "fullColor"}},
         -- Gen 2's hardware natively supports color, so full color makes a
         -- better default there; Gen 1's default stays DMG-style. -Elvie
         default = isGen2 and "fullColor" or "dmg"},
    -- Read once at mod init by starters.lua, which gates its entire body
    -- on this -- like every option here, a change needs a restart to take
    -- effect, so both choice labels say so plainly. -Elvie
    {
      key = "rocketStarters", type = "choice", label = "ROCKET STARTERS",
      choices = {
        {"OFF (RESTART)", false},
        {"ON (RESTART)", true}},
        default = true}
  })

  -- Assign player sprite based on mod options
  -- -----------------------------------------
  mod.hooks:wrap("player.sprite", function(next, path, ctx)
    path = next(path,ctx)
    if ctx.demo then return path end

    local colorMode = mod.options:get("colorMode")
    local variants, selected

    if ctx.side == "back" then
      variants = battleSpriteVariants
      selected = mod.options:get("battleSprite")
    elseif ctx.side == "front" then
      variants = frontSpriteVariants
      selected = mod.options:get("frontSprite")
    else
      return path
    end

    local variant = variants[selected] and variants[selected][colorMode]

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
  -- All follow whichever folder is selected for FRONT SPRITE, falling
  -- back to defaults when a folder doesn't define them. -Elvie
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

  local overworldKey = mod.options:get("frontSprite")
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
  -- nothing on Gen 1 would ever request "Gen2TrainerCard". -Elvie
  -- -----------------------------------------------
  mod.content.screens:register("Gen2TrainerCard", {
    new = function(game, opts)
      local TrainerCard = require("src.ui.gen2.TrainerCard")
      local base = (game.data.gen2MenuGfx or {}).trainerCard or {}

      local gfx = {}
      for k, v in pairs(base) do gfx[k] = v end
      gfx.card = mod.assets:path("assets/menus/card.png")

      local newOpts = {}
      for k, v in pairs(opts or {}) do newOpts[k] = v end
      newOpts.menuGfx = { trainerCard = gfx }

      local instance = TrainerCard.new(game, newOpts)
      if instance.card then
        instance.card.palette = nil 
        instance.card.paletteFor = nil
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
