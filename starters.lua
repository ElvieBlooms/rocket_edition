-- Team Rocket starter-opening story, for every generation Rocket Edition
-- supports: Red/Blue, Yellow, and Gen 2 (Gold/Silver/Crystal).
--
-- Red/Blue: Koffing / Meowth / Ekans
-- Yellow: vanilla Pikachu / Eevee mechanics with a Rocket recruitment story
-- Gen 2: Houndour / Spinarak / Snubbull
--
-- Explicit game routing keeps each opening implementation isolated.
-- Originally built and tested as the standalone team_rocket_starters mod;
-- folded in here as a module once stable.

local starters = {}

function starters.init(mod)
  -- Defined in kris.lua (all of a mod's options live in one schema -- see
  -- the comment there), read once here at boot: like every option, a
  -- change needs a restart to take effect.
  if mod.options:get("rocketStarters") == false then
    return
  end

  local GameVersion = require("src.core.GameVersion")
  local playing = GameVersion.get()
  local function isGen2()
    return GameVersion.generation(playing) == 2
  end

  -- Places a normal level-5 Pokemon directly into PC storage, using the
  -- same constructor and box-deposit paths the engine itself uses.
  --
  -- Pokemon.new (src.pokemon.Pokemon) is Gen 1 only: it hardcodes the Gen 1
  -- five-stat calculator (src/pokemon/Stats.lua), which has no "special"
  -- entry for a Gen 2 species' baseStats and throws. Gen 2's own givepoke
  -- opcode builds Pokemon through src.battle.gen2.Mon instead, so that's
  -- what we use here too on Gen 2.
  local function depositLevel5ToPC(game, species)
    if not (game and game.save and game.data) then return false end

    local Boxes = require("src.pokemon.Boxes")
    local mon
    if isGen2() then
      local Mon = require("src.battle.gen2.Mon")
      mon = Mon.new(game.data, species, 5)
    else
      local Pokemon = require("src.pokemon.Pokemon")
      mon = Pokemon.new(game.data, species, 5)
    end
    if not mon then return false end

    game.save.player.id = game.save.player.id or math.random(0, 65535)
    mon.ot = game.save.player.name
    mon.otId = game.save.player.id

    if not Boxes.deposit(game.save, mon) then return false end

    game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
    game.save.pokedex.seen = game.save.pokedex.seen or {}
    game.save.pokedex.owned = game.save.pokedex.owned or {}
    game.save.pokedex.seen[species] = true
    game.save.pokedex.owned[species] = true
    return true
  end

  local function depositCanonicalTrio(game, speciesList, saveKey)
    if mod.save:get(saveKey) then return true end
    for _, species in ipairs(speciesList) do
      if not depositLevel5ToPC(game, species) then
        mod.log:warn("Could not deposit canonical starter " .. tostring(species))
        return false
      end
    end
    mod.save:set(saveKey, true)
    return true
  end

  if isGen2() then
    -------------------------------------------------------------------------
    -- GEN 2: anonymous Rocket recruitment test
    -------------------------------------------------------------------------
    local lastGame = nil
    mod.events:on("game.ready", function(ev)
      lastGame = ev and ev.game or lastGame
    end)

    local GOLD_SILVER_SLOTS = {
      LEFT = {
        scriptKey = "60:40c6",
        promptText = "60:45e3",
        promptLead = "ELM: You'll take",
        species = "HOUNDOUR",
        nativeIndex = 155,
        rivalSlot = "MIDDLE",
      },
      MIDDLE = {
        scriptKey = "60:4108",
        promptText = "60:460e",
        promptLead = "ELM: Do you want",
        species = "SPINARAK",
        nativeIndex = 158,
        rivalSlot = "RIGHT",
      },
      RIGHT = {
        scriptKey = "60:4144",
        promptText = "60:463a",
        promptLead = "ELM: So, you like",
        species = "SNUBBULL",
        nativeIndex = 209,
        rivalSlot = "LEFT",
      },
    }

    local CRYSTAL_SLOTS = {
      LEFT = {
        scriptKey = "1e:4c73",
        promptText = "1e:53c8",
        promptLead = "ELM: You'll take",
        species = "HOUNDOUR",
        nativeIndex = 155,
        rivalSlot = "MIDDLE",
      },
      MIDDLE = {
        scriptKey = "1e:4cb5",
        promptText = "1e:53f3",
        promptLead = "ELM: Do you want",
        species = "SPINARAK",
        nativeIndex = 158,
        rivalSlot = "RIGHT",
      },
      RIGHT = {
        scriptKey = "1e:4cf1",
        promptText = "1e:541f",
        promptLead = "ELM: So, you like",
        species = "SNUBBULL",
        nativeIndex = 209,
        rivalSlot = "LEFT",
      },
    }

    local engine = type(GameVersion.engine) == "function"
      and GameVersion.engine(playing) or nil
    local GEN2_SLOTS = engine == "crystal" and CRYSTAL_SLOTS
      or GOLD_SILVER_SLOTS

    local function copyTable(t)
      local out = {}
      if type(t) == "table" then
        for k, v in pairs(t) do out[k] = v end
      end
      return out
    end

    local function slotForScript(ctx)
      if not (ctx and ctx.generation == 2 and ctx.scriptKey) then return nil end
      for name, slot in pairs(GEN2_SLOTS) do
        if ctx.scriptKey == slot.scriptKey then return name, slot end
      end
      return nil
    end

    local function speciesIndex(game, species)
      local def = game and game.data and game.data.pokemon
        and game.data.pokemon[species]
      return def and def.index or nil
    end

    local function displayName(game, species)
      local def = game and game.data and game.data.pokemon
        and game.data.pokemon[species]
      return tostring((def and def.name) or species):upper()
    end

    local function updateElmPrompt(game, slotName, slot)
      local text = game and game.data and (game.data.gen2Text or game.data.text)
      if type(text) ~= "table" or not slot.promptText then return end
      local shown = displayName(game, slot.species)
      text[slot.promptText] = string.format(
        "%s\n%s\nTAKE THIS POKéMON?",
        slot.promptLead, shown
      )
      if game.world and type(game.world.text) == "table" then
        game.world.text[slot.promptText] = text[slot.promptText]
      end
    end

    -------------------------------------------------------------------------
    -- Elm story framing.
    --
    -- We use the stable command shapes surrounding the opening and final
    -- Mystery Egg return speech rather than hard-coding ROM text pointers.
    -------------------------------------------------------------------------
    local storyRuns = {}

    -- Tracks progress through the intro scene as a whole, independent of
    -- any single scriptKey. Crystal's real script keeps the entire opening
    -- (intro, both movements, "choose carefully") inside one scriptKey, so
    -- storing this per-scriptKey happened to work there. Gold/Silver's real
    -- script splits the same scene across several scriptKeys, so per-
    -- scriptKey state was silently abandoned once the intro's own script
    -- ended -- the movement counter never advanced. -Elvie
    local openingProgress = { opening = false, moves = 0, chooseNext = false, crystalStyle = false }

    local function storyState(ctx)
      local key = ctx and (ctx.scriptKey or ctx) or "__unknown"
      local s = storyRuns[key]
      if not s then
        s = { history = {} }
        storyRuns[key] = s
      end
      return s, key
    end

    local function remember(s, op)
      s.history[#s.history + 1] = op
      if #s.history > 7 then table.remove(s.history, 1) end
    end

    local function tail(s, ...)
      local want = {...}
      local h = s.history
      if #h < #want then return false end
      for i = 1, #want do
        if h[#h - #want + i] ~= want[i] then return false end
      end
      return true
    end

    mod.events:on("script.ended", function(ev)
      local ctx = ev and ev.ctx
      if not ctx then return end

      local _, starterSlot = slotForScript(ctx)
      storyRuns[ctx.scriptKey or ctx] = nil

      -- Deliver the anonymous recruiter's sealed message only after Elm's
      -- starter-ball script has completely finished, so it doesn't interrupt
      -- the cart's normal give-Pokemon / held-item / event-flag sequence. -Elvie
      if ctx.generation == 2
          and starterSlot
          and mod.save:get("gen2_audition_note_pending")
          and not mod.save:get("gen2_audition_note_seen")
          and mod.world then

        mod.save:set("gen2_audition_note_pending", false)
        mod.save:set("gen2_audition_note_seen", true)

        -- Same "show_text" -> "text" verb-name bug as the Route 29 call
        -- below: queueScript's allow list is start_battle/warp/text/
        -- setflag/clearflag, so this was being silently rejected before. -Elvie
        local ok, err = mod.world:queueScript({
          { "text",
            "ELM: Oh! There was\nsomething else in\nthe package.\f" ..
            "This envelope has\nyour name on it.\f" ..
            "I didn't open it.\nIt seemed...\npersonal." },

          { "text",
            "NOTE:\f" ..
            "\"You made your\nchoice.\"\f" ..
            "\"Now prove it was\nthe right one.\"\f" ..
            "\"Travel. Battle.\nGrow stronger.\"\f" ..
            "\"If you have what\nit takes, we'll\nfind you.\"\f" ..
            "\"Until then...\nconsider this an\naudition.\"" },

          { "text",
            "ELM: An audition?\f" ..
            "Whoever sent this\nreally does seem\nto know you.\f" ..
            "Be careful out\nthere, {PLAYER}." },
        })
        if not ok then
          mod.log:warn("[team_rocket_starters] audition note delivery failed: "
            .. tostring(err))
        end
      end
    end)

    mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
      if not (ctx and ctx.generation == 2 and type(cmd) == "table") then
        return next(ctx, name, args, cmd)
      end

      local game = mod.game or lastGame
      local slotName, slot = slotForScript(ctx)

      -----------------------------------------------------------------------
      -- Verified starter-ball scripts from Starter Picker 1.1.2.
      -----------------------------------------------------------------------
      if slot then
        local targetIndex = speciesIndex(game, slot.species)
        if not targetIndex then return next(ctx, name, args, cmd) end

        if name == "writetext" and cmd.text == slot.promptText then
          updateElmPrompt(game, slotName, slot)
          return next(ctx, name, args, cmd)
        end

        if name == "pokepic" or name == "getmonname" then
          local rewritten = copyTable(cmd)
          rewritten.species = targetIndex
          return next(ctx, name, args, rewritten)
        end

        if name == "cry" then
          local rewritten = copyTable(cmd)
          rewritten.id = targetIndex
          return next(ctx, name, args, rewritten)
        end

        if name == "givepoke" then
          local rewritten = copyTable(cmd)
          rewritten.species = targetIndex
          local result = next(ctx, name, args, rewritten)
          mod.save:set("gen2_starter_slot", slotName)
          mod.save:set("gen2_starter_species", slot.species)
          mod.save:set("gen2_audition_note_pending", true)

          -- The canonical Johto trio stays available in the PC for players
          -- who want the story flavor without giving up the usual starters. -Elvie
          depositCanonicalTrio(
            game,
            { "CHIKORITA", "CYNDAQUIL", "TOTODILE" },
            "gen2_canonical_starters_deposited"
          )

          return result
        end
      end

      -----------------------------------------------------------------------
      -- Narrative rewrites only inside Elm's Lab.
      -----------------------------------------------------------------------
      if ctx.mapGroup == 24 and ctx.mapNumber == 5 then
        local s = storyState(ctx)
        local rewrittenName, rewritten = name, copyTable(cmd)

        -- First Elm speech in the opening scene. Crystal's real script
        -- continues into a yesorno prompt right after this text, so the
        -- box must stay open for it. Gold/Silver has no yesorno here at
        -- all -- it goes straight to a normal waitbutton/closetext -- so
        -- forcing stay=true there left the engine waiting on a
        -- continuation that never came, freezing the game. -Elvie
        local introIsCrystal =
          tail(s, "applymovement", "showemote", "turnobject", "opentext")
        local introIsGoldSilver =
          tail(s, "applymovement", "turnobject", "opentext")
        if name == "writetext"
            and not mod.save:get("gen2_anonymous_intro_seen")
            and (introIsCrystal or introIsGoldSilver) then
          rewrittenName = "rawtext"
          openingProgress.crystalStyle = introIsCrystal
          if introIsCrystal then
            rewritten.text =
              "ELM: There you are!\f" ..
              "I was hoping you'd\nstop by.\f" ..
              "Something unusual\narrived at the lab\nthis morning.\f" ..
              "A package with no\nname or return\naddress.\f" ..
              "It was addressed\nto me...\f" ..
              "but the note inside\nmentioned you.\f" ..
              "Even stranger, the\npackage contained\nthree POKéMON.\f" ..
              "I don't know who\nsent them or why\nthey chose you.\f" ..
              "I've been trying to\nmake sense of it...\f" ..
              "but I also have a\nfavor to ask you.\f" ..
              "Will you help me?"
            rewritten.stay = true
            -- Crystal's real script has two idle Elm movzements between this
            -- speech and the "choose carefully" line -- counted below. -Elvie
            openingProgress.opening = true
            openingProgress.moves = 0
          else
            -- Gold/Silver's "choose carefully" follow-up lives in a
            -- separate script that only runs on a fresh, player-initiated
            -- interaction with Elm -- there's no automatic continuation
            -- point the way Crystal has one. Folding both pieces into this
            -- same multi-page text avoids needing the player to talk to
            -- Elm a second time. -Elvie
            rewritten.text =
              "ELM: There you are!\f" ..
              "I was hoping you'd\nstop by.\f" ..
              "Something unusual\narrived at the lab\nthis morning.\f" ..
              "A package with no\nname or return\naddress.\f" ..
              "It was addressed\nto me...\f" ..
              "but the note inside\nmentioned you.\f" ..
              "Even stranger, the\npackage contained\nthree POKéMON.\f" ..
              "The note said:\f" ..
              "\"Give the trainer\none. Let them\nchoose.\"\f" ..
              "\"We'll see what\nthey make of it.\"\f" ..
              "That's all.\nNo signature.\f" ..
              "I don't know who\nsent them or why\nthey chose you.\f" ..
              "But perhaps the\ntiming is fortunate.\f" ..
              "I have an errand I\ncould use your help\nwith.\f" ..
              "A colleague of mine\nhas made an unusual\ndiscovery.\f" ..
              "I'd like you to go\nsee him for me.\f" ..
              "If you're willing\nto make the trip,\ntake one of those\nPOKéMON with you.\f" ..
              "I'd feel better if\nyou weren't traveling\nalone.\f" ..
              "Choose whichever\none feels right."
            rewritten.stay = false
            openingProgress.opening = false
          end
          mod.save:set("gen2_anonymous_intro_seen", true)

        -- The two Elm movements immediately before ChooseAPokemon
        -- (Crystal only -- Gold/Silver never arms this, see above). -Elvie
        elseif name == "writetext" and openingProgress.chooseNext then
          rewrittenName = "rawtext"
          rewritten.text =
            "ELM: Thanks, {PLAYER}!\f" ..
            "Since you're making\nthat trip for me...\f" ..
            "there's something\nelse about that\npackage.\f" ..
            "The note said:\f" ..
            "\"Give the trainer\none. Let them\nchoose.\"\f" ..
            "\"We'll see what\nthey make of it.\"\f" ..
            "That's all.\nNo signature.\f" ..
            "I still don't know\nwhat the sender\nexpects from you.\f" ..
            "But they clearly\nintended one of\nthese POKéMON to\ngo with you.\f" ..
            "And if you're going\nto be traveling...\f" ..
            "I'd feel better if\nyou weren't alone.\f" ..
            "Choose whichever\none feels right."
          rewritten.stay = false
          openingProgress.chooseNext = false

        -- Final Elm text after the Mystery Egg return setup. Crystal's
        -- real command sequence includes a setflag here; Gold/Silver's
        -- doesn't. -Elvie
        elseif name == "writetext"
            and not mod.save:get("gen2_forge_path_seen")
            and (tail(s, "setevent", "setflag", "setmapscene", "clearevent", "setevent")
              or tail(s, "setevent", "setmapscene", "clearevent", "setevent")) then
          rewrittenName = "rawtext"
          rewritten.text =
            "ELM: Before you go,\n" ..
            "{PLAYER}...\f" ..
            "I've been thinking\nabout that package.\f" ..
            "Whoever sent it\nwanted you to take\na POKéMON...\f" ..
            "and prove what you\ncould do with it.\f" ..
            "Then someone breaks\ninto my lab and\nsteals another one.\f" ..
            "I don't know if the\ntwo are connected.\f" ..
            "But I like this\nless and less.\f" ..
            "Still...\f" ..
            "the POKéMON you\nchose is yours now.\f" ..
            "Whatever its sender\nexpected from you...\f" ..
            "you don't owe them\nanything.\f" ..
            "Travel with your\npartner.\f" ..
            "See the world.\nLearn what you can.\f" ..
            "And decide for\nyourself where this\njourney leads."
          rewritten.stay = false
          mod.save:set("gen2_forge_path_seen", true)
        end

        if openingProgress.opening and name == "applymovement" then
          openingProgress.moves = openingProgress.moves + 1
          if openingProgress.moves >= 2 then
            openingProgress.chooseNext = true
            openingProgress.opening = false
          end
        end

        remember(s, name)
        return next(ctx, rewrittenName, args, rewritten)
      end

      return next(ctx, name, args, cmd)
    end)

    -------------------------------------------------------------------------
    -- Anonymous recruitment follow-up.
    --
    -- After Elm's closing speech, the first entry onto Route 29 triggers one
    -- final message from the unknown sender. The mod then goes silent and the
    -- remainder of Johto is left to the vanilla story.
    -------------------------------------------------------------------------
    mod.events:on("map.entered", function(ev)
      if not ev
          or ev.mapId ~= "ROUTE_29"
          or not mod.save:get("gen2_forge_path_seen")
          or mod.save:get("gen2_recruiter_call_seen")
          or not mod.world then
        return
      end

      mod.save:set("gen2_recruiter_call_seen", true)

      -- queueScript validates every row's verb against a fixed allow list
      -- (start_battle, warp, text, setflag, clearflag) before running
      -- anything -- "show_text" isn't one of them, so the whole script was
      -- being silently rejected. The real verb is "text". -Elvie
      local ok, err = mod.world:queueScript({
        { "text",
          "PHONE:\n...Ring...\n...Ring..." },

        { "text",
          "???: You made the\ntrip.\f" ..
          "And you kept the\nPOKéMON.\f" ..
          "Good.\f" ..
          "The first part of\nyour audition is\ncomplete.\f" ..
          "We'll continue to\nwatch your progress.\f" ..
          "Become stronger.\f" ..
          "Make yourself\nuseful.\f" ..
          "When you're ready,\nwe'll find you.\f" ..
          "And {PLAYER}...\f" ..
          "Don't disappoint\nus.\f" ..
          "...Click." },
      })
      if not ok then
        mod.log:warn("[team_rocket_starters] Route 29 phone call failed: "
          .. tostring(err))
      end
    end)

    -------------------------------------------------------------------------
    -- Silver's starter.
    -------------------------------------------------------------------------
    local function movesAtLevel(game, species, level)
      local def = game and game.data and game.data.pokemon
        and game.data.pokemon[species]
      if not def then return nil end

      local ids, seen = {}, {}
      local function add(id)
        if id and not seen[id] then
          seen[id] = true
          ids[#ids + 1] = id
        end
      end

      -- Gen 2 species store starting + learned moves together in a single
      -- levelMoves list, not separate level1Moves/learnset fields (those are
      -- Gen 1's shape). Reading the wrong fields here silently returned an
      -- empty moveset for every Gen 2 species. -Elvie
      for _, row in ipairs(def.levelMoves or {}) do
        if (tonumber(row.level) or 101) <= (tonumber(level) or 1) then
          add(row.move)
        end
      end
      while #ids > 4 do table.remove(ids, 1) end

      local out = {}
      for _, id in ipairs(ids) do
        local m = game.data.moves and game.data.moves[id] or {}
        out[#out + 1] = { id = id, pp = m.pp or 0 }
      end
      return out
    end

    local function evolvedRocketSpecies(base, level)
      level = tonumber(level) or 1
      if base == "HOUNDOUR" then
        return level >= 24 and "HOUNDOOM" or "HOUNDOUR"
      elseif base == "SPINARAK" then
        return level >= 22 and "ARIADOS" or "SPINARAK"
      elseif base == "SNUBBULL" then
        return level >= 23 and "GRANBULL" or "SNUBBULL"
      end
      return base
    end

    mod.hooks:wrap("trainer.party", function(next, trainerClass, partyIndex, party)
      party = next(trainerClass, partyIndex, party)

      local goldRival = trainerClass == 9 or trainerClass == 42
        or trainerClass == "RIVAL1" or trainerClass == "RIVAL2"
      local chosen = mod.save:get("gen2_starter_slot")
      local chosenSlot = chosen and GEN2_SLOTS[chosen]
      if not (goldRival and chosenSlot and type(party) == "table" and #party > 0) then
        return party
      end

      local rivalSlot = GEN2_SLOTS[chosenSlot.rivalSlot]
      if not rivalSlot then return party end

      local out = {}
      for i, member in ipairs(party) do
        out[i] = copyTable(member)
      end

      local last = out[#out]
      local replacement = evolvedRocketSpecies(rivalSlot.species, last.level)
      last.species = replacement
      last.hp = nil
      local rebuilt = movesAtLevel(mod.game or lastGame, replacement, last.level)
      if rebuilt then last.moves = rebuilt end

      return out
    end, -10000)

    mod.log:info(
      "Team Rocket Johto starters active: HOUNDOUR / SPINARAK / SNUBBULL"
    )
  elseif GameVersion.isYellow() then
    -------------------------------------------------------------------------
    -- YELLOW: preserve the iconic Pikachu / Eevee mechanics completely.
    --
    -- Vanilla Yellow already has exactly the physical story beats we want:
    -- Oak catches Pikachu, offers the single Eevee ball, the rival shoves the
    -- player aside and steals Eevee, then Oak gives the caught Pikachu to the
    -- player. This branch changes only the motivation/dialogue.
    -------------------------------------------------------------------------

    mod.content.text:override(
      "_PalletTownOakHeyWaitDontGoOutText",
      "OAK: Wait! Don't\ngo out!\f" ..
      "There's something\nat my lab...\f" ..
      "It was sent for\nyou."
    )

    mod.content.text:override(
      "_PalletTownOakComeWithMe",
      "OAK: Come with me.\f" ..
      "I need to explain\nwhat's going on."
    )

    -------------------------------------------------------------------------
    -- Eevee was Rocket's intended recruitment gift.
    -------------------------------------------------------------------------
    mod.content.text:override(
      "_OaksLabOakChooseMonText",
      "OAK: Look, {PLAYER}!\f" ..
      "TEAM ROCKET sent\nthat EEVEE here.\f" ..
      "They said it was\nmeant for you.\f" ..
      "They want to see\nwhat you're capable\nof."
    )

    mod.content.text:override(
      "_OaksLabOak1GoAheadItsYours",
      "OAK: That EEVEE was\nsent for you.\f" ..
      "Go ahead."
    )

    mod.content.text:override(
      "_OaksLabRivalWhatAboutMeText",
      "{RIVAL}: Hey!\nWhat about me?"
    )

    mod.content.text:override(
      "_OaksLabOakBePatientText",
      "OAK: Be patient,\n{RIVAL}!\f" ..
      "This POKéMON was\nsent for {PLAYER}."
    )

    -------------------------------------------------------------------------
    -- The rival's vanilla shove/snatch sequence remains untouched.
    -------------------------------------------------------------------------
    mod.content.text:override(
      "_OaksLabRivalTakesText1",
      "{RIVAL}: What?!\f" ..
      "TEAM ROCKET sent\nthis just for you?"
    )

    mod.content.text:override(
      "_OaksLabRivalTakesText2",
      "{RIVAL}: Then I'll\ntake it!"
    )

    mod.content.text:override(
      "_OaksLabRivalTakesText3",
      "{RIVAL}: If they want\na strong trainer,\nthey chose wrong!"
    )

    mod.content.text:override(
      "_OaksLabRivalTakesText4",
      "{RIVAL}: This EEVEE\nis mine now!"
    )

    mod.content.text:override(
      "_OaksLabRivalTakesText5",
      "{RIVAL}: Tough luck,\n{PLAYER}!"
    )

    -------------------------------------------------------------------------
    -- Oak substitutes the Pikachu he caught outside Pallet Town.
    --
    -- We do NOT replace the give_pokemon command, Pikachu follower state,
    -- rivalStarter field, lab battle, or Eevee evolution routing. -Elvie
    -------------------------------------------------------------------------
    mod.content.text:override(
      "_OaksLabOakGivesText",
      "OAK: Oh no...\f" ..
      "That EEVEE was\nsupposed to go\nto you.\f" ..
      "If TEAM ROCKET\nfinds out...\f" ..
      "Here! Take the\nPIKACHU I caught.\f" ..
      "If you leave with\na POKéMON, maybe\n" ..
      "they'll consider\nmy end fulfilled...\f" ..
      "and leave me\nalone."
    )

    -------------------------------------------------------------------------
    -- Yellow parcel beat.
    --
    -- Yellow uses the same OAKS_PARCEL quest flags and the same return-to-Oak
    -- progression as Red/Blue. After the lab rival battle, Oak asks the
    -- player to retrieve the parcel that Rocket has been holding until he
    -- fulfilled his end of their arrangement.
    -------------------------------------------------------------------------
    mod.content.map_scripts:register("OAKS_LAB", {
      onStep = function(game, ow, x, y)
        local flags = game.save.flags or {}

        if not flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB
            or flags.EVENT_GOT_OAKS_PARCEL
            or flags.EVENT_OAK_GOT_PARCEL
            or flags.EVENT_GOT_POKEDEX
            or mod.save:get("yellow_parcel_request_shown") then
          return false
        end

        mod.save:set("yellow_parcel_request_shown", true)

        ow.runner:run({
          { "face_object", 5, "down" },
          { "face_player_dir", "up" },
          { "show_text",
            "OAK: One more thing,\n{PLAYER}.\f" ..
            "TEAM ROCKET is\nholding a parcel\nof mine in\nVIRIDIAN CITY.\f" ..
            "They said they\nwouldn't release it\nuntil I did my part.\f" ..
            "I suppose giving\nyou a POKéMON was\nwhat they meant.\f" ..
            "Please bring it\nback to me." },
        }, {})

        return true
      end,
    })

    mod.content.text:override(
      "_ViridianMartClerkYouCameFromPalletTownText",
      "CLERK: You're from\nPALLET TOWN, right?\f" ..
      "TEAM ROCKET said\nyou'd come once\nPROF.OAK did his\npart."
    )

    mod.content.text:override(
      "_ViridianMartClerkParcelQuestText",
      "CLERK: They told me\nnot to release this\nuntil then.\f" ..
      "Looks like the deal\nis done.\f" ..
      "Take this back to\nPROF.OAK.\f" ..
      "{PLAYER} got\nOAK's PARCEL!"
    )

    mod.content.text:override(
      "_ViridianMartClerkSayHiToOakText",
      "CLERK: Better get\nthat parcel back\nto PROF.OAK."
    )

    mod.content.text:override(
      "_OaksLabOak1DeliverParcelText",
      "OAK: You have my\nparcel!"
    )

    mod.content.text:override(
      "_OaksLabOak1ParcelThanksText",
      "OAK: They finally\nreleased it...\f" ..
      "Thank you.\f" ..
      "At least that's one\nless thing TEAM\nROCKET can hold\nover me."
    )

    -------------------------------------------------------------------------
    -- Pokédex coda: the accident becomes the point.
    --
    -- The parcel mechanics stay vanilla, but its dialogue is now part of the
    -- Rocket coercion story. The existing Pokédex handoff closes the altered
    -- opening and returns the game to the normal story.
    -------------------------------------------------------------------------
    mod.content.text:override(
      "_OaksLabOakIHaveARequestText",
      "OAK: I have a\nrequest for you\ntwo.\f" ..
      "After everything\nthat's happened...\f" ..
      "I want you to see\nthis journey for\nyourselves."
    )

    mod.content.text:override(
      "_OaksLabOakMyInventionPokedexText",
      "OAK: On the desk is\nmy invention, the\nPOKéDEX!\f" ..
      "It records data on\nPOKéMON you've\nseen or caught.\f" ..
      "Take it. Explore."
    )

    mod.content.text:override(
      "_OaksLabOakThatWasMyDreamText",
      "OAK: TEAM ROCKET\nchose EEVEE for\nyou.\f" ..
      "{RIVAL} took it.\f" ..
      "PIKACHU was never\npart of their plan.\f" ..
      "Yet here you are.\f" ..
      "Remember that.\f" ..
      "They may choose\nhow a journey\nbegins...\f" ..
      "But not where it\nleads.\f" ..
      "Forge your own\npath."
    )

    mod.log:info(
      "Team Rocket Yellow story active: Rocket Eevee -> rival; Pikachu -> player"
    )
  else
    ---------------------------------------------------------------------------
    -- 1. Foreshadow the altered opening without explaining everything yet.
    --
    -- The actual Team Rocket reveal now happens diegetically when Oak stops
    -- the player at Pallet Town's north exit.
    ---------------------------------------------------------------------------
    mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
      steps = next(steps, speech)

      mod.ui.insertStepAfter(steps, "oak_welcome", {
        id = "rocket_pressure",
        kind = "say",
        pic = "oak",
        text =
          "Before we begin...\f" ..
          "Things have become\na little... tense\v" ..
          "around PALLET TOWN.\f" ..
          "We'll speak again\nsoon.",
      })

      return steps
    end)

    ---------------------------------------------------------------------------
    -- 2. Re-theme Oak's existing Pallet Town escort.
    --
    -- gen1recomp already reproduces the complete vanilla cutscene: Oak calls
    -- out, walks to the player, escorts them to the lab, warps inside, and
    -- begins the starter sequence. Replacing these text resources changes the
    -- premise without replacing any movement or story-state code.
    ---------------------------------------------------------------------------
    mod.content.text:override(
      "_PalletTownOakHeyWaitDontGoOutText",
      "OAK: Wait! Don't\ngo out!\f" ..
      "I can't let you\nleave without a\nPOKéMON!"
    )

    mod.content.text:override(
      "_PalletTownOakItsUnsafeText",
      "OAK: TEAM ROCKET\nis watching me.\f" ..
      "They want to make\nsure I hold up my\nend of the deal.\f" ..
      "Come with me."
    )

    -- Automatic speech after Oak and the player enter the lab.
    mod.content.text:override(
      "_OaksLabOakChooseMonText",
      "OAK: Here, {PLAYER}!\f" ..
      "TEAM ROCKET left\nthese 3 POKéMON\nwith me.\f" ..
      "They told me to\nlet you choose one."
    )

    -- Talking to Oak before choosing uses a separate text key.
    mod.content.text:override(
      "_OaksLabOak1WhichPokemonDoYouWantText",
      "OAK: TEAM ROCKET\nsent these three.\f" ..
      "I was told to let\nyou choose one."
    )

    ---------------------------------------------------------------------------
    -- 3. Rocket-flavored Oak's Parcel setup.
    --
    -- The vanilla parcel remains OAKS_PARCEL and all normal story flags remain
    -- intact. After the lab rival battle, the first step toward leaving makes
    -- Oak ask the player to retrieve the parcel. This is mod-local state only:
    -- it does not replace or invent a vanilla progression flag. -Elvie
    ---------------------------------------------------------------------------
    mod.content.map_scripts:register("OAKS_LAB", {
      onStep = function(game, ow, x, y)
        local flags = game.save.flags or {}

        -- Roleplay convenience: once the Rocket starter exists, quietly
        -- place the original Kanto starter trio in PC storage.
        if flags.EVENT_GOT_STARTER then
          depositCanonicalTrio(
            game,
            { "BULBASAUR", "CHARMANDER", "SQUIRTLE" },
            "gen1_canonical_starters_deposited"
          )
        end

        if not flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB
            or flags.EVENT_GOT_OAKS_PARCEL
            or flags.EVENT_OAK_GOT_PARCEL
            or flags.EVENT_GOT_POKEDEX
            or mod.save:get("parcel_request_shown") then
          return false
        end

        -- Mark it before starting the blocking script so repeated step events
        -- cannot queue the scene twice.
        mod.save:set("parcel_request_shown", true)

        ow.runner:run({
          { "face_object", 5, "down" },
          { "face_player_dir", "up" },
          { "show_text",
            "OAK: One more thing,\n{PLAYER}.\f" ..
            "TEAM ROCKET is\nholding a parcel\nof mine at the\nVIRIDIAN POKé MART.\f" ..
            "They said they'd\n\"release\" it when\nyou arrived.\f" ..
            "Please bring it\nback to me." },
        }, {})

        return true
      end,
    })

    -- Viridian Mart already auto-stops the player, walks them to the counter,
    -- gives OAKS_PARCEL, and sets EVENT_GOT_OAKS_PARCEL. Only its dialogue
    -- needs to change.
    mod.content.text:override(
      "_ViridianMartClerkYouCameFromPalletTownText",
      "CLERK: You're from\nPALLET TOWN, right?\f" ..
      "Good. TEAM ROCKET\nsaid you'd be\ncoming."
    )

    mod.content.text:override(
      "_ViridianMartClerkParcelQuestText",
      "CLERK: They left\nthis package for\nPROF.OAK.\f" ..
      "Said they were\n\"holding it\" for\nhim.\f" ..
      "Better take it.\f" ..
      "{PLAYER} got\nOAK's PARCEL!"
    )

    mod.content.text:override(
      "_ViridianMartClerkSayHiToOakText",
      "CLERK: Better get\nthat parcel back\nto PROF.OAK."
    )

    -- A small payoff when the player returns it. The vanilla OaksLab script
    -- still removes the item, summons the rival, awards the Pokédex, and sets
    -- EVENT_OAK_GOT_PARCEL.
    mod.content.text:override(
      "_OaksLabOak1DeliverParcelText",
      "OAK: Ah! You have\nmy parcel!"
    )

    mod.content.text:override(
      "_OaksLabOak1ParcelThanksText",
      "OAK: Thank you!\f" ..
      "I'd rather not owe\nTEAM ROCKET any\nmore favors."
    )

    ---------------------------------------------------------------------------
    -- 3b. Put a bow on the altered intro during the vanilla Pokédex handoff.
    --
    -- The base game already runs these three beats after the parcel return:
    -- Oak makes a request -> explains the Pokédex -> gives it -> speaks once
    -- more before the rival answers. Re-theme those exact text resources so
    -- the Pokédex becomes Oak's invitation to break free of Rocket's path.
    ---------------------------------------------------------------------------
    mod.content.text:override(
      "_OaksLabOakIHaveARequestText",
      "OAK: I have a\nrequest for you\ntwo.\f" ..
      "TEAM ROCKET may\nhave started this\njourney for you...\f" ..
      "But what happens\nnext should be\nyour choice."
    )

    mod.content.text:override(
      "_OaksLabOakMyInventionPokedexText",
      "OAK: On the desk is\nmy invention, the\nPOKéDEX!\f" ..
      "It records data on\nPOKéMON you've\nseen or caught.\f" ..
      "Take it. Explore\\nfor yourselves."
    )

    mod.content.text:override(
      "_OaksLabOakThatWasMyDreamText",
      "OAK: TEAM ROCKET\nchose how your\njourney began.\f" ..
      "Don't let them\nchoose where it\nleads.\f" ..
      "Use that POKéDEX.\nSee the world and\nmeet its POKéMON.\f" ..
      "Forge your own\npath."
    )

    ---------------------------------------------------------------------------
    -- 4. Replace the three Red/Blue starter-ball talk handlers.
    ---------------------------------------------------------------------------
    local function starterBall(opts)
      return {
        { "check_flag", "EVENT_GOT_STARTER" },
        { "jump_if_true", "already_chosen" },

        -- Keep the vanilla gate: the player cannot take a ball until Oak
        -- has escorted them into the lab.
        { "check_flag", "EVENT_FOLLOWED_OAK_INTO_LAB" },
        { "jump_if_false", "not_ready" },

        -- Preview the actual Rocket starter rather than the vanilla species.
        { "push_screen", "DexEntryMenu",
          { species = opts.species, forceOwned = true } },

        { "ask", "Choose " .. opts.species .. "?" },
        { "jump_if_false", "end" },

        { "show_text", "_OaksLabMonEnergeticText" },
        { "text_sound", "Get_Key_Item" },
        { "show_text", "_OaksLabReceivedMonText", { RAM = opts.species } },
        { "give_pokemon", opts.species, 5 },

        -- Preserve the original story flags. These are what the vanilla
        -- rival-selection and later rival-party branches already understand.
        { "set_flag", "EVENT_GOT_STARTER" },
        { "set_flag", opts.choseFlag },

        { "hide_object", "OAKS_LAB", opts.ownBall },

        -- Rival walks to and takes the normal counter-pick ball.
        { "move_npc_to", 1, opts.rivalBallX, 4 },
        { "face_object", 1, "up" },
        { "show_text", "_OaksLabRivalIllTakeThisOneText" },
        { "hide_object", "OAKS_LAB", opts.rivalBall },
        { "text_sound", "Get_Key_Item" },
        { "show_text", "_OaksLabRivalReceivedMonText",
          { RAM = opts.rivalSpecies } },
        { "jump", "end" },

        -- Vanilla post-choice behavior for the one ball left on the table.
        { "label", "already_chosen" },
        { "face_object", 5, "down" },
        { "show_text", "That's PROF.OAK's\nlast POKéMON!" },
        { "jump", "end" },

        { "label", "not_ready" },
        { "show_text", "_OaksLabThoseArePokeBallsText" },
      }
    end

    mod.content.map_scripts:register("OAKS_LAB", {
      talk = {
        -- Charmander slot -> Koffing.
        -- Vanilla counter-pick is the Squirtle slot -> Meowth.
        TEXT_OAKSLAB_CHARMANDER_POKE_BALL = starterBall({
          species = "KOFFING",
          rivalSpecies = "MEOWTH",
          choseFlag = "EVENT_CHOSE_CHARMANDER",
          ownBall = "OAKSLAB_CHARMANDER_POKE_BALL",
          rivalBallX = 7,
          rivalBall = "OAKSLAB_SQUIRTLE_POKE_BALL",
        }),

        -- Squirtle slot -> Meowth.
        -- Vanilla counter-pick is the Bulbasaur slot -> Ekans.
        TEXT_OAKSLAB_SQUIRTLE_POKE_BALL = starterBall({
          species = "MEOWTH",
          rivalSpecies = "EKANS",
          choseFlag = "EVENT_CHOSE_SQUIRTLE",
          ownBall = "OAKSLAB_SQUIRTLE_POKE_BALL",
          rivalBallX = 8,
          rivalBall = "OAKSLAB_BULBASAUR_POKE_BALL",
        }),

        -- Bulbasaur slot -> Ekans.
        -- Vanilla counter-pick is the Charmander slot -> Koffing.
        TEXT_OAKSLAB_BULBASAUR_POKE_BALL = starterBall({
          species = "EKANS",
          rivalSpecies = "KOFFING",
          choseFlag = "EVENT_CHOSE_BULBASAUR",
          ownBall = "OAKSLAB_BULBASAUR_POKE_BALL",
          rivalBallX = 6,
          rivalBall = "OAKSLAB_CHARMANDER_POKE_BALL",
        }),
      },
    })

    ---------------------------------------------------------------------------
    -- 5. Keep the rival's Rocket starter through the vanilla story.
    ---------------------------------------------------------------------------
    local rivalClasses = {
      OPP_RIVAL1 = true,
      OPP_RIVAL2 = true,
      OPP_RIVAL3 = true,
    }

    local rocketFamilyByVanillaSpecies = {
      CHARMANDER = { basic = "KOFFING", evolved = "WEEZING", level = 35 },
      CHARMELEON = { basic = "KOFFING", evolved = "WEEZING", level = 35 },
      CHARIZARD = { basic = "KOFFING", evolved = "WEEZING", level = 35 },

      SQUIRTLE = { basic = "MEOWTH", evolved = "PERSIAN", level = 28 },
      WARTORTLE = { basic = "MEOWTH", evolved = "PERSIAN", level = 28 },
      BLASTOISE = { basic = "MEOWTH", evolved = "PERSIAN", level = 28 },

      BULBASAUR = { basic = "EKANS", evolved = "ARBOK", level = 22 },
      IVYSAUR = { basic = "EKANS", evolved = "ARBOK", level = 22 },
      VENUSAUR = { basic = "EKANS", evolved = "ARBOK", level = 22 },
    }

    mod.hooks:wrap("trainer.party", function(next, oppClass, partyIndex, party)
      local resolved = next(oppClass, partyIndex, party) or party

      if not rivalClasses[oppClass] or type(resolved) ~= "table" then
        return resolved
      end

      local out = {}
      for i, slot in ipairs(resolved) do
        local copy = {}
        for key, value in pairs(slot) do
          copy[key] = value
        end

        local family = rocketFamilyByVanillaSpecies[copy.species]
        if family then
          local level = tonumber(copy.level) or 1
          copy.species =
            level >= family.level and family.evolved or family.basic
        end

        out[i] = copy
      end

      return out
    end)

    mod.log:info(
      "Team Rocket starters active: KOFFING / MEOWTH / EKANS (Red/Blue)"
    )
  end
end

return starters
