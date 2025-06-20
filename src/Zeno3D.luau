--[[
         ,----,                   ,--.    ,----..             .--,-``-.                  
       .'   .`|    ,---,.       ,--.'|   /   /   \           /   /     '.      ,---,     
    .'   .'   ;  ,'  .' |   ,--,:  : |  /   .     :         / ../        ;   .'  .' `\   
  ,---, '    .',---.'   |,`--.'`|  ' : .   /   ;.  \        \ ``\  .`-    ',---.'     \  
  |   :     ./ |   |   .'|   :  :  | |.   ;   /  ` ;         \___\/   \   :|   |  .`\  | 
  ;   | .'  /  :   :  |-,:   |   \ | :;   |  ; \ ; |              \   :   |:   : |  '  | 
  `---' /  ;   :   |  ;/||   : '  '; ||   :  | ; | '              /  /   / |   ' '  ;  : 
    /  ;  /    |   :   .''   ' ;.    ;.   |  ' ' ' :              \  \   \ '   | ;  .  | 
   ;  /  /--,  |   |  |-,|   | | \   |'   ;  \; /  |          ___ /   :   ||   | :  |  ' 
  /  /  / .`|  '   :  ;/|'   : |  ; .' \   \  ',  /          /   /\   /   :'   : | /  ;  
./__;       :  |   |    \|   | '`--'    ;   :    /          / ,,/  ',-    .|   | '` ,/   
|   :     .'   |   :   .''   : |         \   \ .'           \ ''\        ; ;   :  .'     
;   |  .'      |   | ,'  ;   |.'          `---`              \   \     .'  |   ,.'       
`---'          `----'    '---'                                `--`-,,-'    '---'         
_________________________________________________________________________________________
 									      CREDITS
 									      
 @ CloneTrooper1019, 2014 (with some edits by TheNexusAvenger in 2016)
	(Some code provided by Mark Langen, also known as stravant)

 @ Butterfly Studios, 2025 (Zeno3D)
 
 Zone3D is a rewritten of Module3D V4: create.roblox.com/store/asset/557211387
_________________________________________________________________________________________
]]--

-- Imports
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local libs = scipt:WaitForChild("lib")
local t = require(libs:WaitForChild("t"))

if not RunService:IsClient() then
	error("Zeno3D | Tried to require from a non-client Instance", 2)
end

------------------------------------------------------------------------------------------

local Zeno3D = {}

-- Variables
local camera: Camera = workspace.CurrentCamera
local viewport: Vector2 = camera.ViewportSize
local CamFOV = camera.FieldOfView

local objects = {Anchored = {}, Unanchored = {}} -- Where objects will be stored and managed
local components = CFrame.new().components
local HighCF = CFrame.new(0, 100000, 0)
local AspectRatio = viewport.X/viewport.Y

local MaxFOV = 120

-- Returns current screen resolution X, Y
local function GetScreenResolution(): Vector2
	local player: Player = Players.LocalPlayer
	local mouse: Mouse = player:GetMouse()
	
	return Vector2.new(mouse.ViewSizeX, mouse.ViewSizeY)
end

local function GetDepthForWidth(PartWidth, VisibleSize, FOV)
	local HFactor = math.tan(math.rad(FOV) * 0.5)
	local WFactor = AspectRatio * HFactor
	
	return math.abs(-0.5*viewport.X*PartWidth/(VisibleSize*WFactor))
end

function Zeno3D:Attach3D(Model: Model, Adornee: GuiObject)
	-- API Parameters validator
	assert(t.instanceOf("Model")(Model))
	assert(t.instanceIsA("GuiObject")(Adornee))
	
	local self = {}
	local util = {}
	local Connections = {}
	
	-- Initializing instance properties
	local Object3D = Model
	
	local Active = false
	local CF = CFrame.Angles(0, 0, 0) -- CFrame.Angles only if possible
	local Anchored = true
	local Adornee = Adornee
	local Depth = 1
	
	-- Methods properties
	local rotationStep = 0
	local rotationSpeed = 0
	
	-- Updates and adjusts the object position
	local objT = Anchored and objects.Anchored or objects.Unanchored
	local WasMoved = false
	
	local Extents = Model:GetExtentsSize()
	local Width = math.max(Extents.X, Extents.Y, Extents.Z)
	
	-- Adornee properties
	local absSize = Adornee.AbsoluteSize
	local absPos = Adornee.AbsolutePosition
	local sizeX, sizeY = absSize.X, absSize.Y
	local pointX = absPos.X + sizeX * 0.5
	local pointY = absPos.Y + sizeY * 0.5
	
	-- Handle assertion errors destroying the Object when any error happens.
	-- Avoiding memory leaks
	local function safeAssertT(func, arg)
		local sucess, errorm = pcall(function()
			assert(func(arg))
		end)
		
		if not sucess then
			self:Destroy()
			error(errorm, 2)
		end
	end
	
	-------------------------------------------- Methods ----------------------------------------------
	
	function self:SetCollisionGroup(groupName: string)
		safeAssertT(t.string, groupName)
		
		if PhysicsService:IsCollisionGroupRegistered(groupName) then
			for _, v in Object3D:GetDescendants() do
				if v:IsA("BasePart") then
					v.CollisionGroup = groupName
				end
			end
		else
			warn(groupName.." is not a valid Collision group!")
		end
	end
	
	-- Manage object auto rotation
	function self:SetRotation(speed: number): ()
		safeAssertT(t.number, speed)
		rotationSpeed = math.rad(speed)
	end
	
	-- Destroy instance and end controller processes
	function self:Destroy(): ()	
		-- Disconnecting from position handler
		local objCon = table.find(objT, self)
		if objCon then
			table.remove(objT, objCon)
		end
		
		-- Disconnecting all events
		for key, index in Connections do
			index:Disconnect()
			Connections[key] = nil
		end
		
		-- Destroying model
		if Model then Model:Destroy() end
		
		-- Clearing self, connections and that's it.
		Connections = nil
		self = nil
	end
	
	-------------------------------------------- Setters ----------------------------------------------
	
	-- Change Controller state
	function self:SetActive(state: boolean): ()
		safeAssertT(t.boolean, state)
		Active = state
		Model.Parent = Active and camera or nil
	end
	
	-- Change Object CFrame. CFrame.Angles preferable
	function self:SetCFrame(value: CFrame): ()
		safeAssertT(t.CFrame, value)
		CF = value
	end
	
	-- Change Object Anchor. Keep in mind that unanchored objects uses
	-- more Device resources. Having a lot of them may be laggy
	function self:SetAnchor(state: boolean): ()
		safeAssertT(t.boolean, state)
		Anchored = state
		
		for _, v in Object3D:GetDescendants() do
			if v:IsA("BasePart") then
				v.Anchored = state
			end
		end
		
		-- Switch objects table
		local old = table.find(objT, self)
		if old then
			table.remove(objT, old)
		end

		objT = Anchored and objects.Anchored or objects.Unanchored
		table.insert(objT, self)
	end
	
	-- Change Object Adornee.
	function self:SetAdornee(guiObj: GuiObject): ()
		safeAssertT(t.instanceIsA("GuiObject"), guiObj)
		Adornee = guiObj
		
		-- Update
		util.onAdorneeChange()
		
		local adorneePosCon = Adornee:GetPropertyChangedSignal("AbsolutePosition")
		local adorneeSizeCon = Adornee:GetPropertyChangedSignal("AbsoluteSize")
		
		Connections["AdorneePos"]:Disconnect()
		Connections["AdorneeSize"]:Disconnect()
		
		Connections["AdorneePos"] = adorneePosCon:Connect(util.onAdorneeChange)
		Connections["AdorneeSize"] = adorneeSizeCon:Connect(util.onAdorneeChange)
	end
	
	-- Change Object Depth (distance) from camera.
	function self:SetDepth(value: number): ()
		safeAssertT(t.number, value)
		Depth = value
	end
	
	-------------------------------------------- Getters ----------------------------------------------
	
	-- Get the current object being manipulated by controller.
	function self:GetObject(): Model
		return Object3D
	end
	
	-- Get Controller active state.
	function self:GetActive(): boolean
		return Active
	end

	-- Get Object CFrame.
	function self:GetCFrame(): CFrame
		return CF
	end

	-- Get Object Anchor state.
	function self:GetAnchor(): boolean
		return Anchored
	end

	-- Get Object Adornee.
	function self:GetAdornee(): GuiObject
		return Adornee
	end

	-- Get Object Depth (distance) from camera.
	function self:GetDepth(): number
		return Depth
	end
	
	-------------------------------------------- Util ----------------------------------------------
	
	-- Updates adornee changes
	function util.onAdorneeChange()
		absSize = Adornee.AbsoluteSize
		absPos = Adornee.AbsolutePosition
		sizeX, sizeY = absSize.X, absSize.Y
		pointX = absPos.X + sizeX * 0.5
		pointY = absPos.Y + sizeY * 0.5
	end
	
	-- Handles the object position automatically by controller.
	function self.__UpdatePos(A,B,C,D,E,F,G,H,I): ()
		if not Active then
			if not WasMoved then
				Model:PivotTo(HighCF)
				WasMoved = true
			end
			return
		end

		-- Calculate horizontal and vertical angles
		local angleX = (viewport.X / viewport.Y) * CamFOV
		local angleY = CamFOV
		if angleX > MaxFOV then
			angleY = CamFOV * (MaxFOV / angleX)
			angleX = MaxFOV
		end

		-- Calculate screen center and screen delta
		local centerX = viewport.X * 0.5
		local centerY = viewport.Y * 0.5
		local deltaX = (pointX - centerX) / centerX
		local deltaY = (pointY - centerY) / centerY

		-- Get world depth based on 2D size
		local minSize = (sizeX < sizeY) and sizeX or sizeY
		local depth = GetDepthForWidth(Width, minSize, CamFOV)

		-- Cast ray from screen point into 3D world
		local ray = camera.ScreenPointToRay(camera, pointX, pointY, depth / Depth)
		local pos = ray.Origin + ray.Direction

		-- Prevent invalid (infinite) positions
		local posX = (pos.X == math.huge or pos.X == -math.huge) and 0 or pos.X
		local posY = (pos.Y == math.huge or pos.Y == -math.huge) and 0 or pos.Y
		local posZ = (pos.Z == math.huge or pos.Z == -math.huge) and 0 or pos.Z

		-- Construct final CFrame with rotation offsets
		local baseCF = CFrame.new(posX, posY, posZ, A,B,C,D,E,F,G,H,I)
		local rotCF = CFrame.Angles(
			-math.rad(angleY * 0.5) * deltaY,
			-math.rad(angleX * 0.5) * deltaX,
			0
		)

		-- Apply transformation to the model
		Model:PivotTo(baseCF * rotCF * CF * CFrame.Angles(0, 0, math.rad(Adornee.Rotation)))
		WasMoved = false
	end
	
	-- Handles the object rotation automatically by controller.
	function self.__UpdateRot(deltaTime: number): ()
		if rotationSpeed == 0 then
			return
		end
		
		-- Increases step
		rotationStep += rotationSpeed * deltaTime
		rotationStep %= (2 * math.pi)
		
		-- Update CF directly
		CF = CFrame.Angles(0, rotationStep, 0)
	end
	
	-- Connections
	local adorneePosCon = Adornee:GetPropertyChangedSignal("AbsolutePosition")
	local adorneeSizeCon = Adornee:GetPropertyChangedSignal("AbsoluteSize")
	Connections["AdorneePos"] = adorneePosCon:Connect(util.onAdorneeChange)
	Connections["AdorneeSize"] = adorneeSizeCon:Connect(util.onAdorneeChange)
	
	table.insert(objT, self)
	self:SetAnchor(true)
	self:SetActive(false)
	
	return self
end

-- Updates camera properties on change
camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	viewport = camera.ViewportSize
	AspectRatio = viewport.X/viewport.Y
end)

camera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
	CamFOV = camera.FieldOfView
end)

-- Control objects placement
local lastCamView
local step = 0
RunService.RenderStepped:Connect(function(delta: number)
	local _,_,_,A,B,C,D,E,F,G,H,I = components(camera.CFrame)
	
	-- Handling objects
	for _, obj in objects.Anchored do
		-- Rotates the object (if rotation is enabled)
		obj.__UpdateRot(delta)
		
		-- If there's no camera movement and object is anchored
		-- Minimize resources usage skipping 1 frame each 5
		if camera.CFrame == lastCamView and step % 5 == 0 then
			break
		end
		
		-- Update object position
		obj.__UpdatePos(A,B,C,D,E,F,G,H,I)
	end
	
	for _, obj in objects.Unanchored do
		-- Update object position & orientation
		obj.__UpdatePos(A,B,C,D,E,F,G,H,I)
		obj.__UpdateRot(delta)
	end
	
	lastCamView = camera.CFrame
	step = (step + 1 <= 10 and step + 1 or 0)
end)

return Zeno3D
