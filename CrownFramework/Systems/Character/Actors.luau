--[[
    Author: Nextix (ne_tix)
    Type: Client
    Description: Handle the client side of the actor system.
    Date: 6/11/25
]]

-- <- Init -> --
local Actors = {
	Alive = {}
}
Actors.__index = Actors

-- <- Services -> --
local RunService = game:GetService('RunService');
local Players = game:GetService('Players');
local ReplicatedStorage = game:GetService('ReplicatedStorage');
local UserInput = game:GetService('UserInputService');
local TweenService = game:GetService('TweenService');

-- <- Modules -> --
local Network = require(ReplicatedStorage.CrownFramework.Modules.Network);
local Util = require(ReplicatedStorage.CrownFramework.Modules.Util);
local Saving = require(ReplicatedStorage.CrownFramework.Systems.Player.Stuff.Save);
local Device = require(ReplicatedStorage.CrownFramework.Systems.Player.Stuff.Device);
local Chase = require(ReplicatedStorage.CrownFramework.Systems.Character.ChaseThemes);

-- <- Private Variables -> --
local Connections = {}
local Cooldowns = {}

local Assets = ReplicatedStorage.Assets
local ActorsFolder = Assets.Actors
local AbilityAssets = Assets.UI.Ability

-- <- Functions -> --
function Actors.Init()
	if RunService:IsServer() then
		return
	end
	--
	Network:Register('Actors: Created', 'Remote', function(Player: Player, Actor: string, Information)
		local LocalPlayer = game.Players.LocalPlayer
		local Character = Player.Character
		if not Character then 
			return
		end
		--
		if Player == LocalPlayer then
			local Save = Saving:GetSave();
			if not Save then
				return
			end
			--
			workspace.Camera.CameraSubject = Character:FindFirstChildOfClass('Humanoid');
			--
			local Type = Character.Parent.Name
			local FoundType = ActorsFolder:FindFirstChild(Type);
			if not FoundType then
				return
			end
			--
			local ActorFound = FoundType:FindFirstChild(Actor);
			if not ActorFound then
				return
			end
			--
			local Success, RequiredActor = pcall(function()
				return require(ActorFound);
			end)
			--
			local SkinSuccess, SkinBehiavor = true, {}
			--
			local Equipped = Save.Information.Equipped
			if not Equipped then
				return
			end
			--
			local TypeInfo = Equipped[Type]
			if not TypeInfo then
				return
			end
			--
			if not TypeInfo.Skins then
				return
			end
			--
			if TypeInfo.Skins[Actor] ~= '' and ActorsFolder.Skins:FindFirstChild(Type):FindFirstChild(Actor):FindFirstChild(Character:GetAttribute('Skin')):FindFirstChild('Behiavor') then
				SkinSuccess, SkinBehiavor = pcall(function()
					return require(ActorsFolder.Skins:FindFirstChild(Type):FindFirstChild(Actor):FindFirstChild(Character:GetAttribute('Skin')):FindFirstChild('Behiavor'));
				end)
			end
			--
			local BehiavorSuccess, ClientBehiavor = pcall(function()
				return require(ActorFound:FindFirstChild('Behiavor'));
			end)
			--
			if not Success then
				return
			end		
			--
			if not SkinSuccess then
				return
			end
			--
			if not BehiavorSuccess then
				return
			end
			--
			if Information.Animations then
				for Index, Value in Information.Animations do 
					if type(Value) == 'string' then
						local NewAnimation = Instance.new('Animation');
						NewAnimation.AnimationId = Value
						--
						pcall(function()
							Information.Animations[Index] = Character:FindFirstChildOfClass('Humanoid'):FindFirstChildOfClass('Animator'):LoadAnimation(NewAnimation);
						end)
					end
				end
			end
			--
			ClientBehiavor = Util:TableMerge(ClientBehiavor, SkinBehiavor);
			--
			if RequiredActor.Abilities then
				for AbilityName, AbilityInfo in RequiredActor.Abilities do 
					if not AbilityInfo.KeyBind then
						continue
					end
					--
					local CopyUi = AbilityAssets.AbilityContainer:Clone();
					CopyUi.Name = AbilityName
					CopyUi.AbilityName.Text = AbilityName
					CopyUi.Parent = LocalPlayer.PlayerGui.Main.AbilitiesContainer
					--
					if Device.GetDevice() ~= 'Mobile' then
						local ActualKeyBind = Save.Settings.Keybinds[AbilityInfo.KeyBind] and Save.Settings.Keybinds[AbilityInfo.KeyBind][Device.GetDevice()] or nil
						if not ActualKeyBind then
							continue
						end
						--
						local KeyBindTrans = ActualKeyBind
						--
						if table.find({'LMB'}, AbilityInfo.KeyBind) and Device.GetDevice() ~= 'Console' then
							KeyBindTrans = ActualKeyBind:gsub(ActualKeyBind, AbilityInfo.KeyBind);
						elseif table.find({'LMB'}, AbilityInfo.KeyBind) and Device.GetDevice() == 'Console' then
							KeyBindTrans = string.gsub(KeyBindTrans, 'Button', '')
						end
						--
						CopyUi.KeybindName.Text = KeyBindTrans:gsub('(%l)(%u)', '%1 %2');
						--
						Connections[#Connections + 1] = UserInput.InputBegan:Connect(function(Input: InputObject, Event: boolean)
							if Event then
								return
							end
							--
							if Input.KeyCode.Name == ActualKeyBind or Input.UserInputType.Name == ActualKeyBind then
								Network:InvokeServer('Actors: Use Ability', AbilityName)
								--
								CopyUi.Cooldown.Visible = true
							end
						end)
					end
					--
					Network:Register('Actors: Use Ability', 'Remote', function(Ability: string, Cooldown: number)
						Cooldowns[#Cooldowns + 1] = {
							Name = Ability,
							Time = Cooldown,
							TimePast = 0
						}
						--
						if ClientBehiavor and ClientBehiavor.Abilities[Ability] and ClientBehiavor.Abilities[Ability].Function then
							ClientBehiavor.Abilities[Ability].Function(Information);
						end
					end)
				end
			end
			--
			Connections[#Connections + 1] = RunService.RenderStepped:Connect(function(DeltaTime: number)
				for Index, Value in Cooldowns do 
					if not Value then
						continue
					end
					--
					local Ui = LocalPlayer.PlayerGui.Main.AbilitiesContainer:FindFirstChild(Value.Name);
					if not Ui then
						continue
					end
					--
					if Value.TimePast >= Value.Time then 
						Ui.Cooldown.Visible = false
						--
						Cooldowns[Index] = nil
						--
						continue
					end
					--
					local MeowMeow = math.clamp(Value.TimePast / Value.Time, 0, 1);
					--
					Ui.Darker.Size = UDim2.fromScale(1, MeowMeow);
					Ui.Darker.ImageLabel.Size = UDim2.fromScale(1, 1 / MeowMeow);
					Ui.Cooldown.Text = string.format('%.1f', Value.Time - Value.TimePast);
					--
					Value.TimePast += DeltaTime
				end
			end)
		end
		--
		if Character.Parent.Name == 'Killers' then
			Chase:NewKiller(Player, Information);
		end
		--
		Actors.Alive[Player.Name] = Information
	end)
	--
	Network:Register('Actors: Deleted', 'Remote', function(Player: Player)
		local LocalPlayer = game.Players.LocalPlayer
		local Character = Player.Character
		if not Character then 
			return
		end
		--
		if Player == LocalPlayer then
			for Index, Value in Connections do 
				if typeof(Value) == 'RBXScriptConnection' then
					Value:Disconnect()
				end
			end
			--
			for Index, Value in LocalPlayer.PlayerGui.Main.AbilitiesContainer:GetChildren() do 
				if Value:IsA('ImageButton') then
					Value:Destroy()
				end
			end
		end
		--
		if Character.Parent.Name == 'Killers' then
			Chase:KillerGone(Player);
		end
		--
		if Actors.Alive[Player.Name] then
			Actors.Alive[Player.Name] = nil
		else
			warn(`[ACTORS CLIENT]: Couldn't find {Player.Name} in the alive table ?`)
		end
	end)
end

-- <- Return -> --
return Actors
