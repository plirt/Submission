local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local player_gui = player.PlayerGui
local mouse = player:GetMouse()
local voting_gui: ScreenGui = player_gui:WaitForChild("MapVoting")
local main_frame = voting_gui:FindFirstChild("Frame")
local options = main_frame.Options
local option_template = options:FindFirstChild("OptionTemplate")

local pin_template = script.PinTemplate

local function mouse_to_scale(parent)
	local relative_x = mouse.X - parent.AbsolutePosition.X
	local relative_y = mouse.Y - parent.AbsolutePosition.Y

	local x_scale = relative_x / parent.AbsoluteSize.X
	local y_scale = relative_y / parent.AbsoluteSize.Y

	return UDim2.new(x_scale, 0, y_scale, 0)
end

local function get_headshot(player: Player)
	local user_id = player.UserId
	local thumbnail_url = Players:GetUserThumbnailAsync(user_id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	return thumbnail_url
end

local voting_system = {}

local function setup_option(map_name)
    if typeof(map_name) ~= "string" then map_name = "Untitled Map" end

    warn("Setup option")

    local option = option_template:Clone()
    local name_box = option.NameBox
    local label: TextLabel = name_box.TextLabel
    local button  = option.TextButton

    label.Text = map_name

    local text_size = TextService:GetTextSize(map_name, label.TextSize, label.Font, Vector2.new(math.huge, math.huge))

    name_box.Size = UDim2.new(0, text_size.X + 50, 0, text_size.Y + 10)

    option.Visible = true

    option.Parent = options

	button.Activated:Connect(function()
		ReplicatedStorage.Events.SubmitVote:FireServer(map_name, mouse_to_scale(main_frame))
	end)

    button.MouseEnter:Connect(function()
        name_box.Visible = true
    end)

    button.MouseLeave:Connect(function()
        name_box.Visible = false
    end)
end

local function clear_options()
    for i, v in options:GetChildren() do
        if v:IsA("Frame") and v.Name ~= "OptionTemplate" then
            v:Destroy()
        end
    end
end

function voting_system:init()
    warn("Initialized voting system via client")
    ReplicatedStorage.Events.TriggerVote.OnClientEvent:Connect(function(maps, toggle: boolean)
		warn("Recieved map data for vote")
		
		if toggle == false then
			voting_gui.Enabled = false
			clear_options()
			return
		else
			voting_gui.Enabled = true

			for i, v in maps do
				setup_option(v)
			end
		end
	end)
	
	ReplicatedStorage.Events.AuthorizeVote.OnClientEvent:Connect(function(voter, position)
		position = position or UDim2.new(0, 0, 0, 0)
		
		local new_pin = nil
		
		if main_frame.Pins:FindFirstChild(`{voter}'s Pin`) then
			new_pin = main_frame.Pins:FindFirstChild(`{voter}'s Pin`)
		else
			new_pin = pin_template:Clone()
			new_pin.Name = `{voter}'s Pin`
			new_pin.Visible = true
			
			new_pin.ImageLabel.Image = get_headshot(voter)
		end
		
		new_pin.Position = position
		new_pin.Rotation = math.random(-25, 25)
	
		new_pin.Parent = main_frame.Pins
	end)
end

return voting_system
