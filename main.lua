--[[
    Rapid Mining Game
]]

local bump = require("lib.bump")

local lume = require("lib.lume")

---@enum GameStates
GAMESTATES = {
    STARTUP = -1,
    MAIN_MENU = 0,
    GAMEPLAY = 1,
    GAMEOVER = 2,
    HIGHSCORES = 3,
    TOSTARTUP = 4,
    
}

local SONGS = {
    MENU = love.audio.newSource("assets/music/8bit Dungeon Boss.mp3", "static"),
    GAME = love.audio.newSource("assets/music/8bit Dungeon Level.mp3", "static")
}
SONGS.MENU:setVolume(.8)
SONGS.GAME:setVolume(.6)

local SFX = {
    COLLAPSE = love.audio.newSource("assets/sound/small-rock-break-194553.mp3", "stream"),
    PICK = love.audio.newSource("assets/sound/Pick.wav", "stream"),
    COIN = love.audio.newSource("assets/sound/Coin.wav", "stream")
}
SFX.COLLAPSE:setVolume(.3)
    
---@enum State Determines how the game should function during each update
local STATES = {
    -- The main gameplay loop. User input will control the character, timer will go down, etc
    GAME = 0,

    -- Game is transitioning to the next room.
    -- (Sunsetting the current room)
    NEXTROOM = 1,

    -- Game is currently paused
    PAUSE = 2,

    -- Player lost
    GAMEOVER = 3,

    -- Game is loading the new room
    LOADGAME = 4,

    -- Load the gameover screen
    LOADGAMEOVER = 5
}

--[[
    Stores a list of buttons used for each menu
]]
MENU = {
    -- Bump world, used to check collision
    world = bump.newWorld(),
    current = {},
    MAIN = {
        {
            name = "Start",
            image = love.graphics.newImage("assets/images/BUTTON_START.png"),
            x = 200,
            y = 300,
            width = 400,
            height = 90,
            scale = 1
        },
        {
            name = "HighScore",
            image = love.graphics.newImage("assets/images/BUTTON_HIGHSCORE.png"),
            x = 200,
            y = 400,
            width = 400,
            height = 90,
            scale = 1
        }
    }, 
    GAMEOVER = {
        {
            name = "Menu",
            image = love.graphics.newImage("assets/images/BUTTON_MENU.png"),
            x = 200,
            y = 300,
            width = 400,
            height = 90,
            scale = 1
        }
    },
    HIGHSCORE = {
        {
            name = "Menu",
            image = love.graphics.newImage("assets/images/BUTTON_MENU.png"),
            x = 575,
            y = 550,
            width = 400,
            height = 90,
            scale = .5
        }
    },
    HOWTOPLAY = {
        {
            name = "Menu",
            image = love.graphics.newImage("assets/images/BUTTON_MENU.png"),
            x = 575,
            y = 550,
            width = 400,
            height = 90,
            scale = .5
        }
    },

    setMenu = function(self, menu) 
        local newWorld = bump.newWorld()
        self.current = self[menu]
        for _,button in pairs(self.current) do
            newWorld:add(button, button.x, button.y, 400 * button.scale, 90 * button.scale)
        end
        self.world = newWorld
    end,

    click = function(self)
        local mouseX, mouseY = love.mouse.getPosition()
        local cols, len = self.world:queryPoint(mouseX, mouseY)
        if len > 0 then
            local button = cols[1]
            return button.name
        else
            return nil
        end
    end,

    draw = function(self)
        for _,button in pairs(self.current) do
            love.graphics.draw(button.image, button.x, button.y, 0, button.scale)
        end
    end
}

MENU:setMenu("MAIN")

MAINMENU_BUTTONS = {
    {
        name = "Start",
        image = love.graphics.newImage("assets/images/BUTTON_START.png"),
        x = 200,
        y = 300,
        width = 400,
        height = 90
    },
    {
        name = "HighScore",
        image = love.graphics.newImage("assets/images/BUTTON_HIGHSCORE.png"),
        x = 200,
        y = 400,
        width = 400,
        height = 90
    }
}

GAMEOVER_BUTTONS = {
    {
        name = "Menu",
        image = love.graphics.newImage("assets/images/BUTTON_MENU.png"),
        x = 200,
        y = 300,
        width = 400,
        height = 90
    }
}

HIGHSCORE_BUTTONS = {
    {
        name = "Menu",
        image = love.graphics.newImage("assets/images/BUTTON_MENU.png"),
        x = 575,
        y = 550,
        width = 400,
        height = 90
    }
}
--[[
    Load all mutable game variables/local constants
]]
function love.load()
    math.randomseed(os.time())

    ---@type GameStates 
    CurrentState = GAMESTATES.STARTUP 

    HighScores = {}

    ---@type number Amount of time the player has before room collapses
    local TIMER_START = 60

    ---@type number 
    local SPAWN_TIME = 6

    ---@type number
    local PLAYER_SPEED = 64

    ---@type number Seconds before the player can swing again
    local SWING_COOLDOWN = .5

    ---@type number 
    local FALLING_MAX = 10

    ---@type number Player's spawnpoint, x-position
    local SPAWN_X = 384

    ---@type number Player's spawnpoint, y-position
    local SPAWN_Y = 416

    local GUI_Y = 512

    local imagePath = "assets/images/"
    Image = {
        Player = love.graphics.newImage(imagePath .. "Player.png"),
        Pickaxe = love.graphics.newImage(imagePath .. "Pick.png"),
        Cursor = love.graphics.newImage(imagePath .. "Cursor.png"),
        Floor = love.graphics.newImage(imagePath .. "floor.png"),
        GUI = love.graphics.newImage(imagePath .. "GameUI.png"),
        UITIMER = love.graphics.newImage(imagePath .. "UI_TIMER.png"),
        UISCORES = love.graphics.newImage(imagePath .. "UI_SCORE.png"),
        Wall = love.graphics.newImage(imagePath .. "tiles/Walls.png"),
        Title = love.graphics.newImage(imagePath .. "TITLE.png"),
        HighScore = love.graphics.newImage(imagePath .. "HIGHSCORE.png"),
        GameOver = love.graphics.newImage(imagePath .. "GAME_OVER.png"),
        Cart = love.graphics.newImage(imagePath .. "Cart.png"),
        Shadow = love.graphics.newImage(imagePath .. "/tiles/Shadow.png")
    }

    ScoreFont = love.graphics.newImageFont("assets/fonts/scorefont.png", "1234567890", 0)

    local WallImage = love.graphics.newImage("assets/images/tiles/Walls.png")
    local WallWidth = Image.Wall:getWidth()
    local WallHeight = Image.Wall:getHeight()
    local WallQuad = {
        -- Left Wall
        love.graphics.newQuad(0, 0, 32, 32, WallWidth, WallHeight),
        -- Upper Wall
        love.graphics.newQuad(32, 0, 32, 32, WallWidth, WallHeight),
        -- Right Wall
        love.graphics.newQuad(64, 0, 32, 32, WallWidth, WallHeight),
        -- Lower Wall
        love.graphics.newQuad(96, 0, 32, 32, WallWidth, WallHeight),
        -- Upper Left Intersect
        love.graphics.newQuad(0, 32, 32, 32, WallWidth, WallHeight),
        -- Upper Right Intersect
        love.graphics.newQuad(32, 32, 32, 32, WallWidth, WallHeight),
        -- Lower Right Intersect 
        love.graphics.newQuad(64, 32, 32, 32, WallWidth, WallHeight),
        -- Lower Left Intersect 
        love.graphics.newQuad(96, 32, 32, 32, WallWidth, WallHeight),
        -- Corner 1
        love.graphics.newQuad(0, 64, 32, 32, WallWidth, WallHeight),
        -- Corner 2
        love.graphics.newQuad(32, 64, 32, 32, WallWidth, WallHeight)
    }
    
    local Walls = {
        {5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 6},
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3},
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3},
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3},
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3},
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3},
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3},
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3},
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3},
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3},
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3},
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3},
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3},
        {8, 4, 4, 4, 4, 4, 4, 4, 4, 4, 9, 0, 0, 0,10, 4, 4, 4, 4, 4, 4, 4, 4, 4, 7},
        {5, 2, 2, 2, 2, 2, 2, 2, 2, 6, 1, 0, 0, 0, 3, 5, 2, 2, 2, 2, 2, 2, 2, 2, 6},
        {8, 4, 4, 4, 4, 4, 4, 4, 4, 7, 1, 0, 0, 0, 3, 8, 4, 4, 4, 4, 4, 4, 4, 4, 7}
    }

    local RockImage = love.graphics.newImage("assets/images/tiles/Rocks.png")
    local RockWidth, RockHeight = RockImage:getDimensions() 
    local RockQuads = {
        love.graphics.newQuad(0, 0, 32, 32, RockWidth, RockHeight),
        love.graphics.newQuad(32, 0, 32, 32, RockWidth, RockHeight),
        love.graphics.newQuad(64, 0, 32, 32, RockWidth, RockHeight),
        love.graphics.newQuad(96, 0, 32, 32, RockWidth, RockHeight),
        love.graphics.newQuad(128, 0, 32, 32, RockWidth, RockHeight),
        love.graphics.newQuad(0, 32, 32, 32, RockWidth, RockHeight),
        love.graphics.newQuad(32, 32, 32, 32, RockWidth, RockHeight),
        love.graphics.newQuad(64, 32, 32, 32, RockWidth, RockHeight),
        love.graphics.newQuad(96, 32, 32, 32, RockWidth, RockHeight),
        love.graphics.newQuad(128, 32, 32, 32, RockWidth, RockHeight)
    }

    WallBump = {
        { -- Top Wall
            x = 0,
            y = 0,
            w = 800,
            h = 32
        },
        { -- Bottom Wall 1
            x = 0, 
            y = 416,
            w = 352,
            h = 96
        },
        { -- Bottom Wall 2
            x = 448, 
            y = 416,
            w = 352,
            h = 96
        },
        {
            x = 0,
            y = 0,
            w = 32,
            h = 512
        },
        {
            x = 768,
            y = 0,
            w = 32,
            h = 512
        }
    }

    --[[
        A list of stats specific to each rock/gem type
        Determines rock health, score total, and timer rate
    ]]
    RockTypes = {
        { -- Normal
            score = 0,
            health = 1,
            timerRate = 0.1
        },
        { -- Ruby
            score = 1,
            health = 2,
            timerRate = 0.1
        },
        { -- Sapphire
            score = 2,
            health = 2, 
            timerRate = 0.2
        },
        { -- Gold
            score = 2,
            health = 2, 
            timerRate = 0.2
        },
        { -- Diamond
            score = 10,
            health = 5, 
            timerRate = 0.6
        }
    }

    --[[
        Creates a function for getting the spawn rate at different levels
        spawnrate = (multiplier * log10(level)) + addend
    ]]
    ---@return function
    local spawnRate = function(multiplier, addend) 
        local multiplier = multiplier 
        local addend = addend
        return function(x) 
            return ((multiplier * math.log10(x)) + addend)
        end
    end

    --[[
        Rate of rock spawns at each row from top to bottom
    ]]
    local RockTable = {
        -- Back Row (1)
        {[1] = 20, [2] = 50, [3] = 40, [4] = 30, [5] = 20},
        -- Row (2)
        {[1] = 50, [2] = 45, [3] = 20, [4] = 10, [5] = 5},
        -- Row (3)
        {[1] = 50, [2] = 45, [3] = 20, [4] = 10, [5] = 5},
        -- Row (4)
        {[1] = 50, [2] = 45, [3] = 20, [4] = 10, [5] = 5},
        -- Row (5)
        {[1] = 50, [2] = 45, [3] = 20, [4] = 10, [5] = 5},
        -- Row (6)
        {[1] = 50, [2] = 45, [3] = 20, [4] = 10, [5] = 5},
        -- Front (7)
        {[1] = 80, [2] = 20, [3] = 5, [4] = 2, [5] = 1},
    }

    --[[
        Calculates the spawn rates for each rock type at the current
        level
    ]]
    local CalcTable = {
        { -- Back Row (1)
            [2] = spawnRate(1, 80), 
            [3] = spawnRate(2, 40),
            [5] = spawnRate(5, 15),

        },
        { -- Row 2
            [1] = spawnRate(2, 50),
            [2] = spawnRate(2, 50),
            [3] = spawnRate(2, 50),
            [4] = spawnRate(2, 50),
            [5] = spawnRate(2, 5),
        },
        { -- Row 3
            [1] = spawnRate(2, 50),
            [2] = spawnRate(2, 50),
            [3] = spawnRate(8, 20),
            [4] = spawnRate(10, 10),
        },
        { -- Row 4
            [1] = spawnRate(2, 60),
            [2] = spawnRate(2, 50),
            [3] = spawnRate(2, 10),
            [4] = spawnRate(2, 10),
        },
        { -- Row 5
            [1] = spawnRate(2, 70),
            [2] = spawnRate(2, 20),
            [3] = spawnRate(2, 10),
            [4] = spawnRate(2, 5),
        },
        { -- Front Row (6)
            [1] = spawnRate(5, 90),
            [2] = spawnRate(3, 20),
            [3] = spawnRate(1, 5),
        }
    }


    --[[
        Creates a new instance of a "Rock" table
    ]]
    ---@return Rock
    local makeRock = function(type, x, y, falling)

        local rocktype = RockTypes[type]

        ---@class Rock
        local newRock = {
            name = "rock",
            ---@type number Specifies the rock type
            type = type,

            ---@type number Rock's x-position
            x = x,

            ---@type number Rock's y-position
            y = y,

            ---@type number Score given for this rock
            score = rocktype.score,

            ---@type number Number of hits to destroy this rock
            health = rocktype.health,

            ---@type number Adds this amount to the timer's rate of decrease
            rate = rocktype.timerRate,

            ---@type love.Quad Quad used to display the current rock
            quad = RockQuads[type + 5],

            ---@type number Time before the given rock is added to the world
            falling = falling,

            fallStart = falling,

            -- Allows rock to shake when hit
            hitTime = 0,

            update = function(self, dt) 
                if self.hitTime > 0 then
                    self.hitTime = self.hitTime - dt
                end
                if self.hitTime < 0 then
                    self.hitTime = 0
                end
            end,


            --[[
                Calculates what should occur when hit by the player
            ]]
            ---@param self Rock
            ---@return number score Score to add
            ---@return number rate Rate at which the timer should count down
            hitRock = function(self)
                self.hitTime = .25
                self.health = self.health - 1
                SFX.PICK:play()
                if self.health == 0 then
                    if self.score > 0 then
                        SFX.COIN:play()
                    end
                    return self.score, self.rate
                else 
                    return 0, 0
                end
            end,

            ---@param self Rock
            draw = function(self)
                if self.falling > 0 then
                    love.graphics.setColor(255, 255, 255, 1 - (self.falling / self.fallStart))
                    love.graphics.draw(Image.Shadow, self.x + 8, self.y + 8)
                    love.graphics.setColor(255, 255, 255)
                    
                else 
                    local sx = math.sin(8 * math.deg(self.hitTime))
                    love.graphics.draw(RockImage, self.quad, self.x + sx, self.y)
                end
            end
        }
        return newRock
    end

    --[[
        Controls the main gameplay loop
    ]]
    ---@class Game
    Game = {
        ---@type number Player's time limit for the current room
        timer = TIMER_START,

        ---@type number Rate the timer will decrease
        timerRate = 1,

        ---@type number Time before the next rocks will drop
        spawnTimer = SPAWN_TIME,

        totalScore = 0,

        score = 0,

        ---@class Player
        player = {
            name = "player",
            ---@enum PlayerStates
            STATES = {
                -- Player is currently idle/moving
                idle = 0,

                -- Player is currently swinging the pickaxe
                mining = 1,

                -- Player is currently in the cart
                incart = 2,
                -- Tells the game to move to the next screen 
                next = 3,
                -- Initiate a GAME OVER
                dead = 4,
            },
            x = SPAWN_X,
            y = SPAWN_Y,
            width = 32,
            height = 32,
            swingCooldown = 0,
            state = 0,
            ---@type number
            clickX = 0,
            ---@type number Last position the player clicked from
            clickY = 0,
            --[[
                Called when the player is on the same tile as a fallen
                rock. Ends the game instantly
            ]]
            ---@param self Player
            crush = function(self) 
                self.state = self.STATES.dead
            end,
            ---@param self Player 
            ---@return nil
            draw = function(self, minePos) 
                local angle = math.abs(math.deg(minePos.angle))
                if self.state == self.STATES.incart or self.state == self.STATES.next then 
                    love.graphics.draw(Image.Player, 352 + 32, 448 + 16)
                else 
                    if self.state == self.STATES.idle then 
                        minePos:draw()
                        if angle >= 90 then
                            love.graphics.draw(Image.Pickaxe, self.x + 16, self.y + 8, 0, 1, 1, 0, 16)
                        else 
                            love.graphics.draw(Image.Pickaxe, self.x + 16, self.y + 8, 0, -1, 1, 0, 16)
                        end
                    end
                    if angle >= 90 then
                        love.graphics.draw(Image.Player, self.x, self.y)
                    else 
                        love.graphics.draw(Image.Player, self.x + 32, self.y, 0, -1, 1)
                    end
                    if self.state ~= self.STATES.idle then 
                        local ratio = self.swingCooldown / SWING_COOLDOWN 
                        if angle >= 90 then
                            love.graphics.draw(Image.Pickaxe, self.x + 16, self.y + 16, minePos.angle + (math.rad(45) * ratio), 1, 1, -8, 24)
                        else 
                            love.graphics.draw(Image.Pickaxe, self.x + 16, self.y + 16, minePos.angle + (math.rad(90)) - (math.rad(45) * ratio), 1, 1, -8, 24)
                        end
                    end
                end
                
            end,
            reset = function(self) 
                self.x = SPAWN_X 
                self.y = SPAWN_Y 
                self.swingCooldown = 0 
                self.state = 0 

            end
        },

        world = bump.newWorld(),

        ---@type table All rocks in the current room
        rocks = {},

        minePos = {
            x = 0,
            y = 0,
            angle = 0,
            side = 8,
            setPos = function(self, x, y, angle) 
                self.x = x
                self.y = y 
                self.angle = angle
            end,
            draw = function(self) 
                love.graphics.draw(Image.Cursor, self.x - 8, self.y - 8)
            end
        },

        ---@type number Thelocaluser's current level. Influences gem spawn-rate and level layout
        level = 1,

        ---@type State The game's current state
        state = STATES.GAME,

        --[[
            Handles collisions at the mouse cursor position
            If rocks are at the given spot, the score and time rate
            are adjusted accordingly
        ]]
        ---@param self Game
        mine = function(self)
            local world = self.world
            local minePos = self.minePos 
            local items, len = world:queryRect(minePos.x, minePos.y, 8, 8)
            local addScore = 0
            if len > 0 then 
                local addScore = 0
                local addRate = 0
                for _, item in pairs(items) do
                    if item.name == "rock" and item.falling <= 0 then 
                        local score, rate = item:hitRock()
                        addScore = addScore + score
                        addRate = addRate + rate
                    end
                end
                self.score = self.score + addScore 
                self.timerRate = self.timerRate + addRate
            end
        end,

        --[[
            Spawns a new set of rocks over the map
        ]]
        ---@param self Game
        spawnRocks = function(self, rate, atStart) 
            --[[ Pseudocode
            ]]
            local rowX = 32
            local rowWidth = 704 
            ---@number 
            local rowHeight = 32
            local world = self.world

            -- For each row
            for i = 1, 6 do 
                ---@table Determines spawn rates for each rock type
                local rockTable = {}
                for j, func in pairs(CalcTable[i]) do 
                    rockTable[j] = func(self.level)
                end

                ---@type number Start of the current row
                local rowY = ((i - 1) * 64) + 32

                ---@type number Number of rocks dropped on the current row
                local numRocks = math.random(4, 7)

                -- Add Rocks to current row
                for i = 1, numRocks do 
                    local rockType = lume.weightedchoice(rockTable)
                    local pos = math.random(1, 46)
                    local rockX = ((pos % 23) - 1) * 32 + 32
                    local rockY = ((math.floor(pos / 23) - 1) * 32) + rowY + 32
                    local items, len = world:queryRect(rockX, rockY, 32, 32)
                    local fallTime = math.random(5, FALLING_MAX)

                    -- Determines whether the rock should have a fall time
                    if atStart then 
                        fallTime = 0 
                    end

                    -- If this spot is not occupied, add the rock
                    if len == 0 then 
                        local newRock = makeRock(rockType, rockX, rockY, fallTime)
                        table.insert(self.rocks, newRock)
                        world:add(newRock, newRock.x, newRock.y, 32, 32)
                    end
                    
                end
            end
        end,

        startOnLoad = function(self)
            self.state = STATES.LOADGAME
            Transition:start(.5)
        end,

        --[[
            Continues the current game state by one frame
        ]]
        ---@param self Game
        update = function(self, dt)

            if self.state == STATES.GAME then 
                if not SONGS.GAME:isPlaying() then 
                    SONGS.GAME:play()
                end
                ---@type Player
                local player = self.player
                local world = self.world 
                --[[ Update Player
                    Check Player state,
                    If state is idle, check input
                        If the player clicks the mine button, then set state to "mining"
                        elseif the player moves, then move them,
                    If the state is mining
                        If player is mid-swing, decrement swing cooldown
                        Else, check if the mouse is held, 
                            if so, then 
                                check spot towards the mouse cursor
                                    if touching minecart, then ask to leave 
                                    else check rock for mining
                                reset swing cooldown
                            else, 
                                Return to idle state
                ]]
                local pStates = player.STATES

                if player.state == pStates.incart then 
                    if love.keyboard.isDown("w") then 
                        player.state = pStates.idle
                    elseif love.mouse.isDown(1) then
                        player.state = pStates.next
                    end
                end

                if player.state == pStates.idle then 
                    if love.mouse.isDown(1) then 
                        player.state = pStates.mining
                    else
                        local moveX, moveY = 0, 0
                        if love.keyboard.isDown("w") then 
                            moveY = -1 * PLAYER_SPEED * dt
                        elseif love.keyboard.isDown("s") then 
                            moveY = PLAYER_SPEED * dt
                        end

                        if love.keyboard.isDown("a") then 
                            moveX = -1 * PLAYER_SPEED * dt
                        elseif love.keyboard.isDown("d") then 
                            moveX = PLAYER_SPEED * dt
                        end

                        local goalX, goalY = player.x + moveX, player.y + moveY
                        local actualX, actualY, cols, len = world:move(player, goalX, goalY, function(item, other) 
                            if other.name == "rock" and other.falling > 0 then 
                                return "cross"
                            else 
                                return "slide"
                            end
                        end)
                        -- Check every collision with player
                        if len > 0 then 
                            for _, col in pairs(cols) do
                                local other = col.other
                                if col.other.name == "cart" then
                                    player.state = player.STATES.incart
                                end
                            end
                        end
                        player.x, player.y = actualX, actualY

                        local minePos = self.minePos
                        local originX = player.x + 16
                        local originY = player.y + 16
                        local mouseX, mouseY = love.mouse.getPosition()
                        local angle = lume.angle(originX, originY, mouseX, mouseY)
                        local mineX, mineY = lume.vector(angle, 32)
                        minePos:setPos(originX + mineX, originY + mineY, angle)

                    end
                end

                if player.state == pStates.mining then 
                    if player.swingCooldown == 0 then 
                        if love.mouse.isDown(1) then 
                            player.swingCooldown = SWING_COOLDOWN
                            self:mine()

                        else 
                            player.state = pStates.idle 
                        end
                    else 
                        player.swingCooldown = player.swingCooldown - dt
                        if player.swingCooldown < 0 then 
                            player.swingCooldown = 0 
                        end
                    end
                end

                --[[ Rock Update
                    Update All Rocks in rock tablef,
                    If health == 0, then remove said rock from table
                ]]
                ---@type table<number,Rock>
                local rocks = self.rocks
                for i, rock in pairs(rocks) do 
                    rock:update(dt)
                    if rock.health == 0 then 
                        world:remove(rocks[i])
                        rocks[i] = nil
                    elseif rock.falling > 0 then 
                        rock.falling = rock.falling - dt
                        if rock.falling <= 0 then 
                            rock.falling = 0
                            local cols, len = world:queryRect(rock.x, rock.y, 32, 32)
                            if len > 1 then
                                for _, col in pairs(cols) do 
                                    local other = col 
                                    if other.name == "player" then
                                        other:crush()
                                    end
                                end
                            end
                        end 
                        
                    end
                end
                --[[
                    Decrement timer
                    Decrement spawn timer
                    if spawnTimer == 0 then 
                        Check every row of the screen.
                ]]
                self.timer = self.timer - (self.timerRate * dt)
                -- Spawn Timer
                self.spawnTimer = self.spawnTimer - (self.timerRate * dt)
                if self.spawnTimer <= 0 then 
                    self:spawnRocks(1, false)
                    self.spawnTimer = SPAWN_TIME
                end
                
                --[[
                Check Current game state/ Change if necessary
                If the timer == 0, then initiate game over,
                If the player has clicked the exit, start the next room sequence
                ]]
                if self.timer <= 0 or player.state == pStates.dead then
                    SONGS.GAME:stop()
                    SFX.COLLAPSE:play()
                    self.state = STATES.LOADGAMEOVER
                    Transition:start(5)
                elseif player.state == pStates.next then
                    self.totalScore = self.totalScore + self.score
                    self.score = 0
                    self.level = self.level + 1
                    self.state = STATES.NEXTROOM
                    Transition:start(.5)
                end
            end

            if self.state == STATES.NEXTROOM then 
                Transition:update(dt)
                if Transition.time == 0 then 
                    self:newRoom()
                    self.state = STATES.LOADGAME
                    Transition:start(.5)
                end

            elseif self.state == STATES.LOADGAME then
                Transition:update(dt)
                if Transition.time == 0 then
                    self.state = STATES.GAME
                end
            elseif self.state == STATES.LOADGAMEOVER then 
                Transition:update(dt)
                if Transition.time == 0 then
                    self.state = STATES.GAMEOVER
                    table.insert(HighScores, self.totalScore)
                    HighScores = lume.sort(HighScores, function(a,b) return a > b end)
                end
            end
        end,

        ---@param self Game
        draw = function(self)
            love.graphics.draw(Image.Floor, 0, 0)
            for i, row in pairs(Walls) do 
                for j, quad in pairs(row) do 
                    if quad > 0 then 
                        local x = (j - 1) * 32
                        local y = (i - 1) * 32
                        love.graphics.draw(Image.Wall, WallQuad[quad], x, y)
                    end
                end
            end
            love.graphics.draw(Image.Cart, 352, 448)

            -- UI ELEMENTS
            love.graphics.draw(Image.GUI, 0, GUI_Y)
            love.graphics.setColor(0, 0, 0)
            love.graphics.setColor(255, 255, 255)
            love.graphics.draw(Image.UITIMER, 20, 520)
            love.graphics.draw(Image.UISCORES, 595, 500)
            love.graphics.print(tostring(math.floor(self.timer)), ScoreFont, 40, 536)
            love.graphics.print(tostring(math.floor(((self.timer * 100) % 100) / 2)), ScoreFont, 72, 536, 0, .5, .5)
            local startX = 764
            local total = self.score 
            while total >= 10 do
                total = total / 10
                startX = startX - 17
            end
            love.graphics.print(tostring(self.score / 1), ScoreFont, startX, 525)
            startX = 764
            total = self.totalScore 
            while total >= 10 do
                total = total / 10
                startX = startX - 17
            end
            love.graphics.print(tostring(self.totalScore / 1), ScoreFont, startX, 560)

            -- Draw Entities
            for i, rock in pairs(self.rocks) do 
                rock:draw()
            end
            self.player:draw(self.minePos)
            
            -- Handles Transition States
            if self.state == STATES.NEXTROOM then 
                love.graphics.setColor(0, 0, 0, 1 - Transition.time)
                love.graphics.rectangle("fill", 0, 0, 800, 600)
                love.graphics.setColor(255, 255, 255)
            elseif self.state == STATES.LOADGAME then 
                love.graphics.setColor(0, 0, 0, Transition.time)
                love.graphics.rectangle("fill", 0, 0, 800, 600)
                love.graphics.setColor(255, 255, 255)
            elseif self.state == STATES.LOADGAMEOVER then 
                love.graphics.draw(Image.GameOver, 0, -600 + (600 * (1 - Transition.time)))
            elseif self.state == STATES.GAMEOVER then 
                --love.graphics.draw(Image.GameOver, 0, 0) 
            end
        end,

        -- Initialize a new Room
        ---@param self Game
        newRoom = function(self)
            self.timer = TIMER_START 
            self.spawnTimer = SPAWN_TIME
            self.timerRate = 1
            local world = bump.newWorld()
            for i, wall in pairs(WallBump) do
                world:add(wall, wall.x, wall.y, wall.w, wall.h)
            end
            local player = self.player 
            player:reset() 
            world:add(player, player.x, player.y, 32, 32)
            world:add({name = "cart"}, 353, 448, 96, 64)
            self.world = world
            self.rocks = {}
            self:spawnRocks(1, true)
        end,

        ---@param self Game
        totalReset = function(self)
            self.level = 1
            self.score = 0
            self.totalScore = 0
            self.state = STATES.GAME
            self:newRoom()
        end
    }

    --[[
        Controls when switching between modes
    ]]
    Transition = {

        MAX = 1,
        time = 0,
        ---@type number Rate at which time decreases
        rate = 1,
        --[[
        ]]
        update = function(self, dt)
            self.time = self.time - (self.rate * dt)
            if self.time < 0 then self.time = 0 end
        end,

        --[[
        ]]
        setState = function(self, state, rate)
            self.state = state 
            if (rate <= 0) then 
                self.rate = 0.1
            else 
                self.rate = rate 
            end
        end,

        -- Reset the current timer
        start = function(self, rate)
            if (rate <= 0) then 
                self.rate = 0.1
            else 
                self.rate = rate 
            end
            self.time = self.MAX 
        end
    }

    --[[
        Check where the user is clicking on the main menu
    ]]
    WorldMenu = bump.newWorld()
    for _, button in pairs(MAINMENU_BUTTONS) do
        WorldMenu:add(button, button.x, button.y, button.width, button.height)
    end

    GameOverMenu = bump.newWorld()
    for _, button in pairs(GAMEOVER_BUTTONS) do
        GameOverMenu:add(button, button.x, button.y, button.width, button.height)
    end

    HighScoreMenu = bump.newWorld()
    for _, button in pairs(HIGHSCORE_BUTTONS) do
        HighScoreMenu:add(button, button.x, button.y, button.width, button.height)
    end

    Game:totalReset()
    Transition:start(1)
end

function love.update(dt)
    -- Check Current state
    if CurrentState == GAMESTATES.GAMEPLAY then 
        Game:update(dt)
        if Game.state == STATES.GAMEOVER then
            CurrentState = GAMESTATES.GAMEOVER
            MENU:setMenu("GAMEOVER")
        end
    elseif CurrentState == GAMESTATES.MAIN_MENU then
        if not SONGS.MENU:isPlaying() then 
            SONGS.MENU:play()
        end
        if love.mouse.isDown(1) then
            local buttonName = MENU:click()
            if buttonName == "Start" then 
                CurrentState = GAMESTATES.GAMEPLAY
                Game:totalReset()
                Game:startOnLoad()
                SONGS.MENU:stop()
                SONGS.GAME:play()
            elseif buttonName == "HighScore" then 
                CurrentState = GAMESTATES.HIGHSCORES 
                MENU:setMenu("HIGHSCORE")
            end
        end
    elseif CurrentState == GAMESTATES.GAMEOVER then
        if love.mouse.isDown(1) then
            local buttonName = MENU:click()
            if buttonName == "Menu" then
                CurrentState = GAMESTATES.TOSTARTUP 
                Transition:start(1)
            end
        end
        
    elseif CurrentState == GAMESTATES.TOSTARTUP or CurrentState == GAMESTATES.STARTUP then
        if CurrentState == GAMESTATES.STARTUP then
            if not SONGS.MENU:isPlaying() then 
                SONGS.MENU:play()
            end
        end
        Transition:update(dt)
        if Transition.time == 0 then
            if CurrentState == GAMESTATES.STARTUP then
                CurrentState = GAMESTATES.MAIN_MENU
                Transition:start(1)
            else
                MENU:setMenu("MAIN")
                CurrentState = GAMESTATES.STARTUP
                Transition:start(1)
            end
        end
    elseif CurrentState == GAMESTATES.HIGHSCORES then
        if love.mouse.isDown(1) then
            local buttonName = MENU:click()
            if buttonName == "Menu" then
                CurrentState = GAMESTATES.MAIN_MENU
                MENU:setMenu("MAIN")
            end
        end
    end

end

function love.draw()
    if CurrentState == GAMESTATES.MAIN_MENU or CurrentState == GAMESTATES.STARTUP then
        love.graphics.draw(Image.Title)
        MENU:draw()

        if CurrentState == GAMESTATES.STARTUP then
            love.graphics.setColor(0, 0, 0, Transition.time)
            love.graphics.rectangle("fill", 0, 0, 800, 600)
            love.graphics.setColor(255, 255, 255)
        end

    elseif CurrentState == GAMESTATES.GAMEPLAY then 
        Game:draw()
    elseif CurrentState == GAMESTATES.GAMEOVER or CurrentState == GAMESTATES.TOSTARTUP then
        love.graphics.draw(Image.GameOver)
        MENU:draw()
        if CurrentState == GAMESTATES.TOSTARTUP then 
            love.graphics.setColor(0, 0, 0, 1 - Transition.time)
            love.graphics.rectangle("fill", 0, 0, 800, 600)
            love.graphics.setColor(255, 255, 255)
        end
    elseif CurrentState == GAMESTATES.HIGHSCORES then
        love.graphics.draw(Image.HighScore, 0, 0)
        for i=1, 5 do
            if HighScores[i] then
                love.graphics.print(HighScores[i], ScoreFont, 320, ((i - 1)* 75) + 215)
            else
                love.graphics.print(tostring(0), ScoreFont, 320, ((i - 1)* 75) + 215)
            end
        end
        MENU:draw()
    end
end