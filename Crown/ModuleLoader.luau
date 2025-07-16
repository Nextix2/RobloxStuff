--!strict

--[[
    Author: Nextix (ne_tix)
    Type: Server & Client
    Description: Framework / Library
    Date: 7/10/25 -- // Second Revamp date
]]

-- <- Init -> --
local Module = {
	Modules = {
		Network = require(game.ReplicatedStorage:WaitForChild('CrownFramework').Modules.Network);
		Util = require(game.ReplicatedStorage:WaitForChild('CrownFramework').Modules.Util);
	};
	BaseModules = {
		Loader = require(script.Loader);
	};
	Settings = {
		NonLoadAttribute = 'NOLOAD';
		ClientFolder = game.ReplicatedStorage:WaitForChild('CrownFramework');
		ServerFolder = game:GetService('RunService'):IsServer() and game.ServerStorage:FindFirstChild('ServerModules') or nil
	};
	PlayerSystems = {};
	CharacterSystems = {};
	Server = {};
}
Module.__index = Module

-- <- Services -> --
local RunService = game:GetService('RunService');

-- <- Private Variables -> --
local Server = RunService:IsServer();
local Client = RunService:IsClient();
local IsStudio = RunService:IsStudio();

-- <- Functions -> --
function CrownLog(Script: string, Type: string, Message: string)
	local Logo = Type == 'Success' and '✅' or Type == 'Error' and '❌' or '⚠️'
	local AdditionalInformation = IsStudio and `| More information: RunType: {Server and 'Server' or 'Client'}, Call Line: {debug.info(2, 'l') or 'Unknown'}` or nil
	--
	if not Script then
		Script = 'NONE'
	elseif typeof(Script) == 'Instance' then
		Script = Script.Name
	else
		Script = 'None'
	end
	--
	warn(`[{Logo}​👑​] [{Script:upper()}]: {Message} {AdditionalInformation}`);
end

function Module:Init()
	local self = setmetatable({}, Module)
	--
	if Client then
		self.Player = game:GetService('NetworkClient').ClientReplicator:GetPlayer();
		self.Character = self.Player.Character or self.Player.CharacterAdded:Wait();
	end
	--
	self.Modules = self.Settings.ClientFolder.Modules
	self.CharacterSystems = self.Settings.ClientFolder.Systems.Character
	self.PlayerSystems = self.Settings.ClientFolder.Systems.Player
	--
	return self
end

function Module.Start()
	if script:GetAttribute(`Loaded_{Server and 'Server' or 'Client'}`) then
		return
	end
	--
	local Tick = tick();
	local self = Module:Init();
	--
	self.BaseModules.Loader:Register(
		self.Settings, 
		self.Modules, 
		Module.Modules
	);
	--
	if Server then
		self.BaseModules.Loader:Register(
			self.Settings, 
			self.Settings.ServerFolder, 
			Module.Server
		);
	else 
		self.BaseModules.Loader:Register(
			self.Settings, 
			self.CharacterSystems, 
			Module.CharacterSystems
		);
		self.BaseModules.Loader:Register(
			self.Settings, 
			self.PlayerSystems, 
			Module.PlayerSystems
		);
	end
	--
	Module.Loaded = true
	--
	script:SetAttribute(`Loaded_{Server and 'Server' or 'Client'}`, true);
	--
	if IsStudio then 
		_G.Log(script, 'Success', `{Server and 'Server' or 'Client'} loaded in {tick() - Tick}`);
	end
end

-- <- Script -> --
_G.Log = CrownLog

-- <- Return -> --
return Module
