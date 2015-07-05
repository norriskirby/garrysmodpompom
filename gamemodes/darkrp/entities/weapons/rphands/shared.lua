AddCSLuaFile()

SWEP.Author			= "DeltaTimo"
SWEP.Purpose		= "Hands for Roleplay servers"
SWEP.Category		= "Roleplay"
SWEP.Contact		= "Steam Community ID: 76561197995389141"
SWEP.Instructions	= "Right click to lower / raise your fists. Left click to punch with raised fists."

SWEP.Spawnable			= true
SWEP.UseHands			= true

SWEP.ViewModel			= "models/weapons/c_arms_citizen.mdl"
SWEP.WorldModel			= ""

SWEP.ViewModelFOV		= 52

SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Damage			= 10
SWEP.Primary.Automatic		= true
SWEP.Primary.Ammo			= "none"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo			= "none"

SWEP.Weight				= 5
SWEP.AutoSwitchTo		= false
SWEP.AutoSwitchFrom		= false

SWEP.UnreadyDelay		= 15 --The time in seconds until the Fists will be automatically lowered

SWEP.PrintName			= "Toggleable Fists"
SWEP.Slot				= 1
SWEP.SlotPos			= 1
SWEP.DrawAmmo			= false
SWEP.DrawCrosshair		= true

SWEP.ready = false

local SwingSound = Sound( "weapons/slam/throw.wav" )
local HitSound = Sound( "Flesh.ImpactHard" )

function SWEP:Initialize()
	self:SetWeaponHoldType( "normal" )
	if !IsValid(self.Owner) then return end
	local vm = self.Owner:GetViewModel()
	if !IsValid(vm) then return end
	vm:ResetSequence( vm:LookupSequence( "reference" ) )
end

function SWEP:PreDrawViewModel( vm, wep, ply )
	
	if !IsValid(vm) then return end

	vm:SetMaterial( "engine/occlusionproxy" )
end

function SWEP:PrimaryAttack()
	if (!self.ready) then return end
	if (self.ready) then
		self.Owner:SetAnimation( PLAYER_ATTACK1 )
		if (!SERVER) then return end
		
		--self:DeactivateTimer("lower")
		
		self.Owner:EmitSound(SwingSound)
		
		local vm = self.Owner:GetViewModel()
		
		if IsValid(vm) then
			vm:ResetSequence( vm:LookupSequence( "fists_idle_01" ) )
			vm:ResetSequence( vm:LookupSequence( table.Random({"fists_left","fists_right"}) ) )
		end
		
		timer.Simple( 0.15, function()
			if ( !IsValid( self ) ) then return end
			if ( !IsValid( self.Owner ) ) then return end
			local pos = self.Owner:GetShootPos()
			local ang = self.Owner:GetAimVector()
			local tracedata = {}
			tracedata.start = pos
			tracedata.endpos = pos + ang * 75
			tracedata.filter = self.Owner
			local trace = util.TraceLine(tracedata)
			if (trace.Hit) then self.Owner:EmitSound(HitSound) end
			if (trace.Hit and IsValid(trace.Entity)) then
				local dmginfo = DamageInfo()
				local dmg = math.random( 3, 7 )
				local hpcap = GetConVar("fists_healthcap"):GetInt() or 0
				if (trace.Entity:IsPlayer() and trace.Entity:Health() - dmg < hpcap) then
					dmginfo:SetDamage( - (hpcap - trace.Entity:Health()) )
				else
					dmginfo:SetDamage( dmg )
					if trace.Entity:IsPlayer() then
						local bullet = {}
						bullet.Num = 1
						bullet.Src = self.Owner:GetShootPos()
						bullet.Dir = self.Owner:GetAimVector()
						bullet.Spread = Vector(0, 0, 0)
						bullet.Tracer = 0
						bullet.Force = 0
						bullet.Damage = 0
						self.Owner:FireBullets(bullet)
					end
				end
				if ( !trace.Entity:IsPlayer() and IsValid(trace.Entity:GetPhysicsObject()) ) then
					trace.Entity:GetPhysicsObject():ApplyForceOffset( ang * (75 / 2), trace.Entity:WorldToLocal(trace.HitPos) )
				end
				dmginfo:SetDamageForce( ang * 7500 )
				dmginfo:SetInflictor( self )
				dmginfo:SetAttacker( self.Owner or self )
				trace.Entity:TakeDamageInfo( dmginfo )
			end
		end)
		
		self:ActivateTimer("lower")
		self:Idle(false)
		self:SetNextPrimaryFire( CurTime() + vm:SequenceDuration() + 0.2 )
		self:SetNextSecondaryFire( CurTime() + 0.75 )
	end
end

function SWEP:SecondaryAttack()
	if (!SERVER) then return end
	self:DeactivateTimer("lower")	
	self:ToggleFists()
	self:SetNextSecondaryFire( CurTime() + 1 )
end

function SWEP:Idle()
	if ( !IsValid( self.Owner ) ) then return end
	local vm = self.Owner:GetViewModel()
	timer.Simple( vm:SequenceDuration() - 0.05, function()
		if ( !IsValid( self ) ) then return end
		if ( !IsValid( self.Owner ) ) then return end
		local vm = self.Owner:GetViewModel()
		if ( !IsValid( vm ) ) then return end
		if (!self.ready) then
			vm:ResetSequence( vm:LookupSequence( "reference" ) )
		else
			vm:ResetSequence( vm:LookupSequence( "fists_idle_0" .. math.random( 1, 2 ) ) )
		end
	end )
end

function SWEP:ActivateTimer(strtype)
	if (strtype == "lower") then
		self:DeactivateTimer("lower")
		timer.Create( "dt_rpfists_lower_" .. self:EntIndex(), self.UnreadyDelay, 1, function()
			if IsValid(self) and IsValid(self.Owner) then
				self:SetFists(false)
			end
		end)
	end
end

function SWEP:DeactivateTimer(strtype)
	if (strtype == "lower") then
		timer.Destroy( "dt_rpfists_lower_" .. self:EntIndex() )
	end
end

function SWEP:ToggleFists()
	if (!SERVER) then return end
	if ( !IsValid( self.Owner ) ) then return end
	local vm = self.Owner:GetViewModel()
	self.ready = !self.ready
	if (!self.ready) then
	
		if IsValid(vm) then
			vm:ResetSequence( vm:LookupSequence( "fists_idle_0" .. math.random( 1, 2 ) ) )
			vm:ResetSequence( vm:LookupSequence( "fists_holster" ) )
		end
		
		util.AddNetworkString( "dt_handswep" )
		net.Start( "dt_handswep" )
		net.WriteEntity(self)
		net.WriteBit(self.ready)
		net.Broadcast()
	else
	
		if IsValid(vm) then
			vm:ResetSequence( vm:LookupSequence( "idle" ) )
			vm:ResetSequence( vm:LookupSequence( "fists_draw" ) )
		end
		
		self:ActivateTimer("lower")
		
		net.Start( "dt_handswep" )
		net.WriteEntity(self)
		net.WriteBit(self.ready)
		net.Broadcast()
	end
	self:Idle()
end

function SWEP:SetFists(ready)
	if (!SERVER) then return end
	if (self.ready != ready) then
		self:ToggleFists()
	end
	return self.ready
end

function SWEP:Deploy()
	if (!SERVER) then return end
	if (!IsValid( self.Owner )) then return end
	local vm = self.Owner:GetViewModel()
	if IsValid(vm) then
		vm:ResetSequence( vm:LookupSequence( "reference" ) )
	end
	return true
end
 
function SWEP:Holster()
	self:DeactivateTimer("lower")

	if IsValid( self.Owner ) then
		local vm = self.Owner:GetViewModel()
		if IsValid( vm ) then
			vm:SetMaterial( "" )
		end
	end

	if !SERVER then return end

	self:SetFists(false)
	return true
end
 
function SWEP:Think()
end

if CLIENT then

net.Receive( "dt_handswep", function( len, pl )
	local weapon = net.ReadEntity()
	local status = net.ReadBit()
	weapon.ready = status
	if !IsValid(weapon) then return end
	if status==1 then
		weapon:SetWeaponHoldType( "fist" )
	else
		weapon:SetWeaponHoldType( "normal" )
	end
end)

else

util.AddNetworkString( "dt_handswep" )

end