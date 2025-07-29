--[[
    Author: Nextix (ne_tix)
    Type: Server
    Description: Handle the actors.
    Date: 6/08/25
    
    Require:
    CrownLoader (Custom Private Module Loader)
]]

-- <- Init -> --
local ActorsManager = {
	CurrentActors = {}
}
ActorsManager.__index = ActorsManager

-- <- Types -> --
export type ActorType = {
	Player: Player,
	Rig: Model,
	Information: {},
	Name: string, 
	ServerBehavior: {},
	ClientBehavior: {},
	RigType: string,
	SkinName: string
}

-- <- Services -> --
local Players = game:GetService('Players');
local Storage = game:GetService('ServerStorage');
local ReplicatedStorage = game:GetService('ReplicatedStorage');

-- <- Modules -> --
local Loader = require(ReplicatedStorage["CrownLoader"]);
local Network = Loader.Modules.Network
local Util = Loader.Modules.Util
local CharacterStatus = Loader.Modules.CharacterStatus

-- <- Private Variables -> --
local ClientAssets = ReplicatedStorage.Assets
local ClientActors = ClientAssets.Actors

local ServerAssets = Storage.ServerAssets
local ServerActors = ServerAssets.Actors

-- <- Functions -> --

-- // Apply the skin data to the actor rig and update the ActorData table.
-- // @param Player Player
-- // @param ActorData table // The data table of the actor.
function ApplySkinToActor(Player: Player, ActorData: ActorType): ActorType
	local Save = Loader.Server.SavingManager:GetData(Player);
	if not Save then
		_G.Log(script, 'Error', `No save for player: {Player.Name}`);
		--
		return ActorData
	end
	--
	if not ServerActors:FindFirstChild('Skins') then return ActorData end
	--
	local SkinModule = Util:DeepFind(ServerActors, {'Skins', ActorData.RigType, ActorData.Name, ActorData.SkinName});
	if not SkinModule then
		_G.Log(script, 'Error', `No skin module for {ActorData.SkinName}`);
		--
		return ActorData
	end
	--
	local ClientActorModule = Util:DeepFind(ClientActors, {'Skins', ActorData.RigType, ActorData.Name});
	if not ClientActorModule then return ActorData end
	--
	local ClientModule = Util:DeepFind(ClientActors, {'Skins', ActorData.RigType, ActorData.Name, ActorData.SkinName});
	if not ClientModule then return ActorData end
	--
	local ClientBehavior = ClientModule:FindFirstChild('Behavior');
	if ClientBehavior then 
		ActorData.ClientBehavior = Util:TableMerge(ActorData.ClientBehavior, Util:SafeRequire(ClientBehavior));
	end
	--
	ActorData.ServerBehavior = Util:TableMerge(ActorData.ServerBehavior, Util:SafeRequire(SkinModule));
	ActorData.Information = Util:TableMerge(ActorData.Information, Util:SafeRequire(ClientModule));
	--
	local RigInstance = SkinModule:FindFirstChildOfClass('Model');
	if RigInstance then
		ActorData.Rig = RigInstance:Clone();
	end
	--
	return ActorData 
end

-- // Return the shuffled of eligible players.
function ActorsManager:Random(): any
	local PlayersTable = {}
	--
	for Index, Value in Players:GetPlayers() do 
		table.insert(PlayersTable, Value);
	end
	--
	local ShuffledTable = Util:ShuffleTable(PlayersTable);
	if ShuffledTable then
		return ShuffledTable
	end
	--
	return {}
end

-- // Return the client and server behavior of the actor.
-- // @param Player
-- // @param ServerActorModule // Server actor module of the actor (Lol)
-- // @param ClientActorModule // Same as above but client. 
function GetBehaviors(PlayerActor: string, ServerActorModule: Folder, ClientActorModule: Folder): (any, any, any)
	local ClientBehaviorModule = ClientActorModule:FindFirstChild('Behavior');
	if not ClientBehaviorModule then return end
	--
	local SuccessClient, ClientInfo = pcall(require, ClientActorModule);
	if not SuccessClient then
		_G.Log(script, 'Error', `Couldn't require actor: {PlayerActor}, Error: {ClientInfo} (Client)`);
		--
		return nil, nil, nil
	end
	--
	local SuccessServer, ServerBehavior = pcall(require, ServerActorModule);
	if not SuccessServer then
		_G.Log(script, 'Error', `Couldn't require actor: {PlayerActor}, Error: {ServerBehavior} (Server)`);
		--
		return nil, nil, nil
	end
	--
	local SuccessClientBehavior, ClientBehaviorInfo = pcall(require, ClientBehaviorModule);
	if not SuccessClientBehavior then
		_G.Log(script, 'Error', `Couldn't require actor Behavior: {PlayerActor}, Error: {ClientBehaviorInfo} (Client)`);
		--
		return nil, nil, nil
	end
	--
	return ClientBehaviorInfo, ServerBehavior, ClientInfo
end

-- // Create a player and setup the rig.
-- // @param Player Player // Player to spawn in
-- // @param Type string // Type of the actor the player need to spawn in.
function ActorsManager:CreatePlayer(Player: Player, ActorType: string)
	if ActorsManager.CurrentActors[Player.Name] then
		ActorsManager:DeletePlayer(Player)
		--
		Player:SetAttribute('Playing', nil)
	end
	--
	if not Player.Character then return end
	if not Player.Character.PrimaryPart then return end
	--
	local PlayerSave = Loader.Server.SavingManager:GetData(Player);
	if not PlayerSave then return end
	--
	local PlayerActor = PlayerSave.Information.Equipped[ActorType].Equipped
	if not PlayerActor then return end
	--
	local PlayerCurrentSkin = PlayerSave.Information.Equipped[ActorType].Skins[PlayerActor]
	local ActorTypeServer = ServerActors:FindFirstChild(ActorType);
	if not ActorTypeServer then 
		return _G.Log(script, 'Error', `Couldn't get folder for type: {ActorType} (Server)`);
	end
	--
	local ActorTypeClient = ClientActors:FindFirstChild(ActorType);
	if not ActorTypeClient then 
		return _G.Log(script, 'Error', `Couldn't get folder for type: {ActorType} (Client)`);
	end
	--
	local ServerActorModule = ActorTypeServer:FindFirstChild(PlayerActor);
	if not ServerActorModule then
		return _G.Log(script, 'Error', `Couldn't get module for actor: {PlayerActor} (Server)`);
	end
	--
	local ClientActorModule = ActorTypeClient:FindFirstChild(PlayerActor);
	if not ClientActorModule then
		return _G.Log(script, 'Error', `Couldn't get module for actor: {PlayerActor} (Client)`);
	end
	--
	local ClientBehaviorInfo, ServerBehavior, ClientInfo = GetBehaviors(PlayerActor, ServerActorModule, ClientActorModule);
	local Rig = ServerActorModule:FindFirstChildOfClass('Model');
	if not Rig then
		return _G.Log(script, 'Error', `No rig for the player equipped actor ? {PlayerActor}`);
	end
	--
	local ActorTable = {}
	ActorTable.Connections = {}
	ActorTable.Player = Player
	ActorTable.Name = PlayerActor
	ActorTable.RigType = ActorType
	ActorTable.SkinName = PlayerCurrentSkin
	ActorTable.Information = ClientInfo
	ActorTable.ServerBehavior = ServerBehavior
	ActorTable.ClientBehavior = ClientBehaviorInfo
	--
	ActorTable = ApplySkinToActor(Player, ActorTable); -- // Update the table with the skin info.
	--
	ActorTable.Rig = ActorTable.Rig and ActorTable.Rig:Clone() or Rig:Clone();
	ActorTable.Rig:SetAttribute('Player', Player.Name);
	ActorTable.Rig:SetAttribute('Skin', ActorTable.SkinName);
	ActorTable.Rig.PrimaryPart.CFrame = Player.Character.PrimaryPart.CFrame
	ActorTable.Rig.Parent = workspace.Players:FindFirstChild(ActorType);
	--
	Player.Character:Destroy();
	Player.Character = ActorTable.Rig
	--
	local Humanoid = ActorTable.Rig:FindFirstChildOfClass('Humanoid');
	if Humanoid then
		ActorTable.Connections[#ActorTable.Connections + 1] = Humanoid.Died:Connect(function()
			ActorsManager:DeletePlayer(Player);
		end)
	end
	--
	ActorsManager.CurrentActors[Player.Name] = ActorTable
	--
	Player:SetAttribute('Playing', true)
	--
	Network:FireAllClients('Actors: Created', Player, ActorTable.Name, ActorTable.Information);
end

-- // Delete a player and clear his data.
-- // @param Player Player // Player to delete
function ActorsManager:DeletePlayer(Player: Player)
	if not ActorsManager.CurrentActors[Player.Name] then
		return
	end
	--
	for _, Connection in ActorsManager.CurrentActors[Player.Name].Connections do
		if typeof(Connection) == 'RBXScriptConnection' then
			Connection:Disconnect();
		end
	end
	--
	ActorsManager.CurrentActors[Player.Name] = nil
	--
	Player:SetAttribute('Playing', nil)
	--
	Network:FireAllClients('Actors: Deleted', Player);
end

-- // Init the network events for the Actor system.
-- // @type Server
function ActorsManager.Init()
	Network:Register('Actors: Use Ability', 'Function', function(Player: Player, Ability: string?)
		if type(Ability) ~= 'string' then
			return
		end
		--
		local CurrentActor = ActorsManager.CurrentActors[Player.Name]
		if not CurrentActor then return end
		if not CurrentActor.ServerBehavior.Abilities[Ability] then return end
		if CharacterStatus:CheckStatue(Player.Character, Ability) then return end
		--
		local Cooldown = CurrentActor.Information.Abilities[Ability].Cooldown or 0
		--
		ActorsManager.CurrentActors[Player.Name].ServerBehavior.Abilities[Ability].Function(CurrentActor);
		--
		Network:FireClient(Player, 'Actors: Use Ability', Ability, Cooldown);
		--
		CharacterStatus:GiveStatue(Player.Character, Ability, 'Cooldown', true, Cooldown);
	end)
end

-- <- Return -> --
return ActorsManager
