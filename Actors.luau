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

-- <- Services -> --
local Players = game:GetService('Players');
local Storage = game:GetService('ServerStorage');
local ReplicatedStorage = game:GetService('ReplicatedStorage');

-- <- Modules -> --
local Loader = require(ReplicatedStorage["CrownLoader"]);
local Network = Loader.Modules.Network
local Util = Loader.Modules.Util
local CharacterStatus = Loader.Modules.CharacterStatus

-- <- Private Varabiles -> --
local ClientAssets = ReplicatedStorage.Assets
local ClientActors = ClientAssets.Actors

local ServerAssets = Storage.ServerAssets
local Actors = ServerAssets.Actors

-- <- Functions -> --
function ActorsManager:SetSkinsDatas(Player: Player, Table: {Player: Player, Rig: Model, Information: {}, Name: string, ServerBehiavor: {}, ClientBehiavor: {}, RigType: string, SkinName: string})
	local Save = Loader.Server.SavingManager:GetData(Player);
	if not Save then
		_G.Log(script, 'Error', `No save for player: {Player.Name}`);
		--
		return Table
	end
	--
	local SkinFolder = Actors.Skins:FindFirstChild(Table.RigType);
	if not SkinFolder then
		_G.Log(script, 'Error', `{Table.RigType} doesn't have a skin folder`);
		--
		return Table
	end
	--
	local ActorFolder = SkinFolder:FindFirstChild(Table.Name);
	if not ActorFolder then
		_G.Log(script, 'Error', `No actor folder for {Table.Name} (Skins)`);
		--
		return Table
	end
	--
	local SkinModule = ActorFolder:FindFirstChild(Table.SkinName);
	if not ActorFolder then
		_G.Log(script, 'Error', `No skin module for {Table.SkinName}`);
		--
		return Table
	end
	--
	local ClientModule = ClientActors.Skins:FindFirstChild(Table.RigType):FindFirstChild(Table.Name):FindFirstChild(Table.SkinName);
	if not ClientModule then
		_G.Log(script, 'Error', `No skin module for {Table.SkinName} (Client)`);
		--
		return Table
	end
	--
	local ClientBehiavor = ClientModule:FindFirstChild('ClientBehiavor');
	if ClientBehiavor then 
		Table.ClientBehiavor = Util:TableMerge(Table.ClientBehiavor, require(ClientBehiavor));
	end
	--
	Table.ServerBehiavor = Util:TableMerge(Table.ServerBehiavor, require(SkinModule));
	Table.Information = Util:TableMerge(Table.Information, require(ClientModule));
	--
	if SkinModule:FindFirstChildOfClass('Model') then
		Table.Rig = SkinModule:FindFirstChildOfClass('Model');
	end
	--
	return Table
end

function ActorsManager:Random()
	local PlayersTable = {}
	--
	for Index, Value in Players:GetChildren() do 
		if Value:IsA('Player') then
			table.insert(PlayersTable, Value);
		end
	end
	--
	local ShuffledTable = Util:ShuffleTable(PlayersTable);
	
end

function ActorsManager:CreatePlayer(Player: Player, Type: string)
	if ActorsManager.CurrentActors[Player.Name] then
		ActorsManager:DeletePlayer(Player)
		--
		Player:SetAttribute('Playing', nil)
	end
	--
	if not Player.Character then
		return
	end
	--
	if not Player.Character.PrimaryPart then
		return
	end
	--
	local Save = Loader.Server.SavingManager:GetData(Player);
	if not Save then
		_G.Log(script, 'Error', `No save for player: {Player.Name}`);
		--
		return
	end
	--
	local Folder = Actors:FindFirstChild(Type);
	if not Folder then
		_G.Log(script, 'Error', `Couldn't get folder for type: {Type}`);
		--
		return
	end
	--
	local ActorModule: ModuleScript = Folder:FindFirstChild(Save.Information.Equipped[Type].Equipped);
	if not ActorModule then
		_G.Log(script, 'Error', `Couldn't find actor: {Save.Information.Equipped[Type].Equipped}.`);
		--
		return
	end
	--
	local SuccessClient, ClientInfo = pcall(function()
		return require(ClientActors:FindFirstChild(Type):FindFirstChild(ActorModule.Name));
	end)
	--
	if not SuccessClient then
		_G.Log(script, 'Error', `Couldn't require actor: {ActorModule.Name}, Error: {ClientInfo}`);
		--
		return
	end
	--
	local SuccessServer, ServerInfo = pcall(function()
		return require(ActorModule);
	end)
	--
	if not SuccessServer then
		_G.Log(script, 'Error', `Couldn't require actor: {ActorModule.Name}, Error: {ServerInfo}`);
		--
		return
	end
	--
	local SuccessClientBehiavor, BehiavorInfo = pcall(function()
		return require(ClientActors:FindFirstChild(Type):FindFirstChild(ActorModule.Name).Behiavor);
	end)
	--
	if not SuccessClientBehiavor then
		_G.Log(script, 'Error', `Couldn't require actor behiavor: {ActorModule.Name}, Error: {BehiavorInfo}`);
		--
		return
	end
	--
	local Rig = ActorModule:FindFirstChildOfClass('Model');
	if not Rig then
		_G.Log(script, 'Error', `No rig for the player equipped actor ? {ActorModule.Name}`);
		--
		return
	end
	--
	local SavingTable = {}
	SavingTable.Connections = {}
	SavingTable.Player = Player
	SavingTable.Rig = Rig:Clone()
	SavingTable.Information = ClientInfo
	SavingTable.ServerBehiavor = ServerInfo
	SavingTable.ClientBehiavor = BehiavorInfo
	SavingTable.Name = ActorModule.Name
	SavingTable.RigType = Type
	SavingTable.SkinName = Save.Information.Equipped[Type].Skins[ActorModule.Name]
	--
	ActorsManager:SetSkinsDatas(Player, SavingTable);
	--
	SavingTable.Rig:SetAttribute('Player', Player.Name);
	SavingTable.Rig:SetAttribute('Skin', SavingTable.SkinName);
	SavingTable.Rig.PrimaryPart.CFrame = Player.Character.PrimaryPart.CFrame
	SavingTable.Rig.Parent = workspace.Players:FindFirstChild(Type);
	--
	Player.Character:Destroy();
	Player.Character = SavingTable.Rig
	--
	SavingTable.Connections[#SavingTable.Connections + 1] = SavingTable.Rig:FindFirstChildOfClass('Humanoid').Died:Connect(function()
		ActorsManager:DeletePlayer(Player);
	end)
	--
	ActorsManager.CurrentActors[Player.Name] = SavingTable
	--
	Player:SetAttribute('Playing', true)
	--
	Network:FireAllClients('Actors: Created', Player, SavingTable.Name, SavingTable.Information);
end

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

function ActorsManager.Init()
	Network:Register('Actors: Use Ability', 'Function', function(Player: Player, Ablitiy: string?)
		if type(Ablitiy) ~= 'string' then
			return
		end
		--
		local CurrentActor = ActorsManager.CurrentActors[Player.Name]
		--
		if not CurrentActor then
			return
		end
		--
		if not CurrentActor.ServerBehiavor.Abilities[Ablitiy] then
			return
		end
		--
		if CharacterStatus:CheckStatue(Player.Character, Ablitiy) then
			return
		end
		--
		ActorsManager.CurrentActors[Player.Name].ServerBehiavor.Abilities[Ablitiy].Function(CurrentActor);
		--
		local Cooldown = CurrentActor.Information.Abilities[Ablitiy].Cooldown or 0
		--
		Network:FireClient(Player, 'Actors: Use Ability', Ablitiy, Cooldown);
		--
		CharacterStatus:GiveStatue(Player.Character, Ablitiy, 'Cooldown', true, Cooldown);
	end)
end

-- <- Return -> --
return ActorsManager
