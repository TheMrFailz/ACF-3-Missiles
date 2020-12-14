
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

local ACF = ACF

ACF.RegisterClassLink("acf_computer", "acf_rack", function(Computer, Target)
	if Computer.Weapons[Target] then return false, "This rack is already linked to this computer!" end
	if Target.Computer == Computer then return false, "This rack is already linked to this computer!" end

	Computer.Weapons[Target] = true
	Target.Computer = Computer

	Computer:UpdateOverlay()
	Target:UpdateOverlay()

	return true, "Rack linked successfully!"
end)

ACF.RegisterClassUnlink("acf_computer", "acf_rack", function(Computer, Target)
	if Computer.Weapons[Target] or Target.Computer == Computer then
		Computer.Weapons[Target] = nil
		Target.Computer = nil

		Computer:UpdateOverlay()
		Target:UpdateOverlay()

		return true, "Rack unlinked successfully!"
	end

	return false, "This rack is not linked to this computer."
end)

ACF.RegisterClassLink("acf_computer", "acf_gun", function(Computer, Target)
	if Computer.Weapons[Target] then return false, "This computer is already linked to this weapon!" end
	if Target.Computer == Computer then return false, "This computer is already linked to this weapon!" end

	Computer.Weapons[Target] = true
	Target.Computer = Computer

	Computer:UpdateOverlay()
	Target:UpdateOverlay()

	return true, "Computer linked successfully!"
end)

ACF.RegisterClassUnlink("acf_computer", "acf_gun", function(Computer, Target)
	if Computer.Weapons[Target] or Target.Computer == Computer then
		Computer.Weapons[Target] = nil
		Target.Computer = nil

		Computer:UpdateOverlay()
		Target:UpdateOverlay()

		return true, "Computer unlinked successfully!"
	end

	return false, "This computer is not linked to this weapon."
end)

--===============================================================================================--
-- Local Funcs and Vars
--===============================================================================================--

local CheckLegal  = ACF_CheckLegal
local Components  = ACF.Classes.Components
local UnlinkSound = "physics/metal/metal_box_impact_bullet%s.wav"
local MaxDistance = ACF.RefillDistance * ACF.RefillDistance
local HookRun     = hook.Run

local function CheckDistantLinks(Entity, Source)
	local Position = Entity:GetPos()

	for Link in pairs(Entity[Source]) do
		if Position:DistToSqr(Link:GetPos()) > MaxDistance then
			Entity:EmitSound(UnlinkSound:format(math.random(1, 3)), 500, 100)
			Link:EmitSound(UnlinkSound:format(math.random(1, 3)), 500, 100)

			Entity:Unlink(Link)
		end
	end
end

--===============================================================================================--

do -- Spawn and update function
	local function VerifyData(Data)
		if not Data.Computer then
			Data.Computer = Data.Component or Data.Id
		end

		local Class = ACF.GetClassGroup(Components, Data.Computer)

		if not Class or Class.Entity ~= "acf_computer" then
			Data.Computer = "CPR-LSR"

			Class = ACF.GetClassGroup(Components, "CPR-LSR")
		end

		do -- External verifications
			if Class.VerifyData then
				Class.VerifyData(Data, Class)
			end

			HookRun("ACF_VerifyData", "acf_computer", Data, Class)
		end
	end

	local function CreateInputs(Entity, Data, Class, Computer)
		local List = {}

		if Class.SetupInputs then
			Class.SetupInputs(List, Entity, Data, Class, Computer)
		end

		HookRun("ACF_OnSetupInputs", "acf_computer", List, Entity, Data, Class, Computer)

		if Entity.Inputs then
			Entity.Inputs = WireLib.AdjustInputs(Entity, List)
		else
			Entity.Inputs = WireLib.CreateInputs(Entity, List)
		end
	end

	local function CreateOutputs(Entity, Data, Class, Computer)
		local List = { "Entity [ENTITY]" }

		if Class.SetupOutputs then
			Class.SetupOutputs(List, Entity, Data, Class, Computer)
		end

		HookRun("ACF_OnSetupOutputs", "acf_computer", List, Entity, Data, Class, Computer)

		if Entity.Outputs then
			Entity.Outputs = WireLib.AdjustOutputs(Entity, List)
		else
			Entity.Outputs = WireLib.CreateOutputs(Entity, List)
		end
	end

	local function UpdateComputer(Entity, Data, Class, Computer)
		Entity:SetModel(Computer.Model)

		Entity:PhysicsInit(SOLID_VPHYSICS)
		Entity:SetMoveType(MOVETYPE_VPHYSICS)

		if Entity.OnLast then
			Entity:OnLast()
		end

		-- Storing all the relevant information on the entity for duping
		for _, V in ipairs(Entity.DataStore) do
			Entity[V] = Data[V]
		end

		Entity.Name         = Computer.Name
		Entity.ShortName    = Entity.Computer
		Entity.EntType      = Class.Name
		Entity.ClassData    = Class
		Entity.OnUpdate     = Computer.OnUpdate or Class.OnUpdate
		Entity.OnLast       = Computer.OnLast or Class.OnLast
		Entity.OverlayTitle = Computer.OnOverlayTitle or Class.OnOverlayTitle
		Entity.OverlayBody  = Computer.OnOverlayBody or Class.OnOverlayBody
		Entity.OnDamaged    = Computer.OnDamaged or Class.OnDamaged
		Entity.OnEnabled    = Computer.OnEnabled or Class.OnEnabled
		Entity.OnDisabled   = Computer.OnDisabled or Class.OnDisabled
		Entity.OnThink      = Computer.OnThink or Class.OnThink

		Entity:SetNWString("WireName", "ACF " .. Computer.Name)
		Entity:SetNW2String("ID", Entity.Computer)

		CreateInputs(Entity, Data, Class, Computer)
		CreateOutputs(Entity, Data, Class, Computer)

		ACF.Activate(Entity, true)

		Entity.ACF.LegalMass	= Computer.Mass
		Entity.ACF.Model		= Computer.Model

		local Phys = Entity:GetPhysicsObject()
		if IsValid(Phys) then Phys:SetMass(Computer.Mass) end

		if Entity.OnUpdate then
			Entity:OnUpdate(Data, Class, Computer)
		end

		if Entity.OnDamaged then
			Entity:OnDamaged()
		end
	end

	hook.Add("ACF_OnSetupInputs", "ACF Computer Inputs", function(Class, List, _, _, _, Computer)
		if Class ~= "acf_computer" then return end
		if not Computer.Inputs then return end

		local Count = #List

		for I, Input in ipairs(Computer.Inputs) do
			List[Count + I] = Input
		end
	end)

	hook.Add("ACF_OnSetupOutputs", "ACF Computer Outputs", function(Class, List, _, _, _, Computer)
		if Class ~= "acf_computer" then return end
		if not Computer.Outputs then return end

		local Count = #List

		for I, Output in ipairs(Computer.Outputs) do
			List[Count + I] = Output
		end
	end)

	-------------------------------------------------------------------------------

	function MakeACF_Computer(Player, Pos, Angle, Data)
		VerifyData(Data)

		local Class = ACF.GetClassGroup(Components, Data.Computer)
		local Computer = Class.Lookup[Data.Computer]
		local Limit = Class.LimitConVar.Name

		if not Player:CheckLimit(Limit) then return false end

		local Entity = ents.Create("acf_computer")

		if not IsValid(Entity) then return end

		Entity:SetPlayer(Player)
		Entity:SetAngles(Angle)
		Entity:SetPos(Pos)
		Entity:Spawn()

		Player:AddCleanup("acf_computer", Entity)
		Player:AddCount(Limit, Entity)

		Entity.Owner     = Player -- MUST be stored on ent for PP
		Entity.Weapons   = {}
		Entity.DataStore = ACF.GetEntityArguments("acf_computer")

		UpdateComputer(Entity, Data, Class, Computer)

		if Class.OnSpawn then
			Class.OnSpawn(Entity, Data, Class, Computer)
		end

		HookRun("ACF_OnEntitySpawn", "acf_computer", Entity, Data, Class, Computer)

		WireLib.TriggerOutput(Entity, "Entity", Entity)

		Entity:UpdateOverlay(true)

		do -- Mass entity mod removal
			local EntMods = Data and Data.EntityMods

			if EntMods and EntMods.mass then
				EntMods.mass = nil
			end
		end

		CheckLegal(Entity)

		timer.Create("ACF Computer Clock " .. Entity:EntIndex(), 3, 0, function()
			if not IsValid(Entity) then return end

			CheckDistantLinks(Entity, "Weapons")
		end)

		return Entity
	end

	ACF.RegisterEntityClass("acf_opticalcomputer", MakeACF_Computer, "Computer") -- Backwards compatibility
	ACF.RegisterEntityClass("acf_computer", MakeACF_Computer, "Computer")
	ACF.RegisterLinkSource("acf_computer", "Weapons")

	------------------- Updating ---------------------

	function ENT:Update(Data)
		VerifyData(Data)

		local Class    = ACF.GetClassGroup(Components, Data.Computer)
		local Computer = Class.Lookup[Data.Computer]
		local OldClass = self.ClassData

		if OldClass.OnLast then
			OldClass.OnLast(self, OldClass)
		end

		HookRun("ACF_OnEntityLast", "acf_computer", self, OldClass)

		ACF.SaveEntity(self)

		UpdateComputer(self, Data, Class, Computer)

		ACF.RestoreEntity(self)

		if Class.OnUpdate then
			Class.OnUpdate(self, Data, Class, Computer)
		end

		HookRun("ACF_OnEntityUpdate", "acf_computer", self, Data, Class, Computer)

		self:UpdateOverlay(true)

		net.Start("ACF_UpdateEntity")
			net.WriteEntity(self)
		net.Broadcast()

		return true, "Computer updated successfully!"
	end
end

function ENT:ACF_OnDamage(Energy, FrArea, Angle, Inflictor)
	local HitRes = ACF.PropDamage(self, Energy, FrArea, Angle, Inflictor)

	--self.Spread = ACF.MaxDamageInaccuracy * (1 - math.Round(self.ACF.Health / self.ACF.MaxHealth, 2))
	if self.OnDamaged then
		self:OnDamaged()
	end

	return HitRes
end

function ENT:Enable()
	if not CheckLegal(self) then return end

	self.Disabled	   = nil
	self.DisableReason = nil

	if self.OnEnabled then
		self:OnEnabled()
	end

	self:UpdateOverlay()
end

function ENT:Disable()
	if self.OnDisabled then
		self:OnDisabled()
	end

	self.Disabled = true

	self:UpdateOverlay()
end

local function Overlay(Ent)
	if Ent.Disabled then
		Ent:SetOverlayText("Disabled: " .. Ent.DisableReason .. "\n" .. Ent.DisableDescription)
	else
		local Title = Ent.OverlayTitle and Ent:OverlayTitle() or "Idle"
		local Body = Ent.OverlayBody and Ent:OverlayBody()

		Body = Body and ("\n\n" .. Body) or ""

		Ent:SetOverlayText(Title .. Body)
	end
end

function ENT:UpdateOverlay(Instant)
	if Instant then
		return Overlay(self)
	end

	if timer.Exists("ACF Overlay Buffer" .. self:EntIndex()) then return end

	timer.Create("ACF Overlay Buffer" .. self:EntIndex(), 0.5, 1, function()
		if not IsValid(self) then return end

		Overlay(self)
	end)
end

function ENT:Think()
	if self.OnThink then
		self:OnThink()
	end

	self:NextThink(ACF.CurTime)

	return true
end

function ENT:PreEntityCopy()
	if next(self.Weapons) then
		local Entities = {}

		for Weapon in pairs(self.Weapons) do
			Entities[#Entities + 1] = Weapon:EntIndex()
		end

		duplicator.StoreEntityModifier(self, "ACFWeapons", Entities)
	end

	-- wire dupe info
	self.BaseClass.PreEntityCopy(self)
end

function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
	local EntMods = Ent.EntityMods

	if EntMods.ACFWeapons then
		for _, EntID in pairs(EntMods.ACFWeapons) do
			self:Link(CreatedEntities[EntID])
		end

		EntMods.ACFWeapons = nil
	end

	-- Wire dupe info
	self.BaseClass.PostEntityPaste(self, Player, Ent, CreatedEntities)
end

function ENT:OnRemove()
	local OldClass = self.ClassData

	if OldClass.OnLast then
		OldClass.OnLast(self, OldClass)
	end

	HookRun("ACF_OnEntityLast", "acf_computer", self, OldClass)

	for Weapon in pairs(self.Weapons) do
		self:Unlink(Weapon)
	end

	if self.OnLast then
		self:OnLast()
	end

	timer.Remove("ACF Computer Clock " .. self:EntIndex())

	WireLib.Remove(self)
end
