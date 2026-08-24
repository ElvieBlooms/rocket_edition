local credits = {}

function credits.init(mod)

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    mod.ui.insertBefore(items, "QUIT", {
      label = "T. KRIS",
      onSelect = function() mod.ui.push(game, "credits") end,
    })
    return next(game, items)
  end)

  mod.content.screens:register("credits", {
  new = function(game)
    local self = { isOpaque = true }
    local lines = {
      "CRYSTAL MOD CREATOR",
      "  Dgray66",
      "",
      "ROCKET PACK",
      " Elvie",
      "",
      "SPRITE ARTISTS",
      " Elvie",
      "",
      "GIRL MODE SCRIPT",
      " Amanda Arale-Chan",
      " DarioMelo",
      " Bhk",
      "",
      "KO-FI SUPPORTERS",
      " Dgray66",
    }

    function self:update(dt)
      if game.input:wasPressed("b") then game.stack:pop() end
    end

    function self:draw()
      mod.ui.Font.drawBox(0, 0, 20, 18)
      for i, line in ipairs(lines) do
        mod.ui.Font.draw(line, 8, 8 + (i - 1) * 8)
      end
    end

    return self
  end,
})

end

return credits
