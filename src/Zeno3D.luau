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
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local libs = script:WaitForChild("lib")
local t = require(libs:WaitForChild("t"))

if not RunService:IsClient() then
	error("Zeno3D | Tried to require from a non-client Instance", 2)
end

------------------------------------------------------------------------------------------

local Zeno3D = {}

-- Variables
local camera: Camera = workspace.CurrentCamera
local viewport: Vector2 = camera.ViewportSize

local objects = {Anchored = {}, Unanchored = {}} -- Where objects will be stored and managed
local components = CFrame.new().components
local HighCF = CFrame.new(0, 100000, 0)

-- Types
export type RotationAxis = "X" | "Y" | "Z" | "XY" | "XZ" | "YZ" | "XYZ"
local validAxes = {"X", "Y", "Z", "XY", "XZ", "YZ", "XYZ"}

--[[ CACHE VARIABLES ]]--

-- Camera
local CamFOV = camera.FieldOfView
local AspectRatio = viewport.X/viewport.Y

local HFactor = math.tan(math.rad(CamFOV) * 0.5)
local WFactor = AspectRatio * HFactor

local MaxFOV = 120

-- Calculate horizontal and vertical angles
local rawAngleX = AspectRatio * CamFOV
local angleX = rawAngleX > MaxFOV and MaxFOV or rawAngleX
local angleY = CamFOV * (rawAngleX > MaxFOV and (MaxFOV / rawAngleX) or 1)

--[[ CACHE VARIABLES ]]--

local function GetDepthForWidth(PartWidth, VisibleSize)
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
	local rotationSpeed = 0
	local rotationAxis: RotationAxis = "Y"
	
	-- Updates and adjusts the object position
	local objT = Anchored and objects.Anchored or objects.Unanchored
	local WasMoved = false
	
	local Extents = Model:GetExtentsSize()
	local Width = math.max(Extents.X, Extents.Y, Extents.Z)
	
	-- Adornee properties
	local absSize = Adornee.AbsoluteSize
	local absPos = Adornee.AbsolutePosition
	local adorneeRot = math.rad(Adornee.Rotation)
	local sizeX, sizeY = absSize.X, absSize.Y
	local minSize = math.min(sizeX, sizeY)
	local pointX = absPos.X + sizeX * 0.5
	local pointY = absPos.Y + sizeY * 0.5
	
	-- IMPORTANT CACHE --

	-- "__UpdatePos" method cached variables	
	local camDepth = GetDepthForWidth(Width, minSize) / Depth
	local ray = camera:ScreenPointToRay(pointX, pointY, camDepth)

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
	
	-- Sets the model's CollisionGroup. The group must already exist in the game.
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
	
	-- Enables automatic axis rotation at the given speed (radians per frame). 
	-- Set to 0 to disable the rotation. Axis is Y by default.
	function self:SetRotation(speed: number, axis: RotationAxis?): ()
		safeAssertT(t.number, speed)
		
		rotationAxis = table.find(validAxes, axis) and axis or "Y" -- Y is the default axis
		rotationSpeed = math.rad(speed)
	end
	
	-- Destroys the controller and disconnects all internal bindings.
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
	
	-- Enable or disable the controller. Must be enabled to render the model.
	function self:SetActive(state: boolean): ()
		safeAssertT(t.boolean, state)
		Active = state
		Model.Parent = Active and camera or nil
	end
	
	-- Sets the model's CFrame (rotation). Only use CFrame.Angles
	function self:SetCFrame(value: CFrame): ()
		safeAssertT(t.CFrame, value)
		CF = value
	end
	
	-- Anchors the model. Anchored models are ~20% more performant.
	-- This option is true by default.
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
	
	-- Sets the GUI object (adornee) used to render the model.
	function self:SetAdornee(guiObj: GuiObject): ()
		safeAssertT(t.instanceIsA("GuiObject"), guiObj)
		Adornee = guiObj
		
		-- Update
		util.onAdorneeChange()
		
		local adorneePosCon = Adornee:GetPropertyChangedSignal("AbsolutePosition")
		local adorneeSizeCon = Adornee:GetPropertyChangedSignal("AbsoluteSize")
		local adorneeRotCon = Adornee:GetPropertyChangedSignal("Rotation")
		
		Connections["AdorneePos"]:Disconnect()
		Connections["AdorneeSize"]:Disconnect()
		Connections["AdorneeRot"]:Disconnect()
		
		Connections["AdorneePos"] = adorneePosCon:Connect(util.onAdorneeChange)
		Connections["AdorneeSize"] = adorneeSizeCon:Connect(util.onAdorneeChange)
		Connections["AdorneeRot"] = adorneeRotCon:Connect(util.onAdorneeChange)
	end
	
	-- Sets the model’s rendering depth multiplier (distance from the camera).
	function self:SetDepth(value: number): ()
		safeAssertT(t.number, value)
		Depth = value

		-- Update object depth
		camDepth = GetDepthForWidth(Width, minSize) / Depth
		ray = camera:ScreenPointToRay(pointX, pointY, camDepth)
	end
	
	-------------------------------------------- Getters ----------------------------------------------
	
	-- Returns the model being rendered by the controller.
	function self:GetObject(): Model
		return Object3D
	end
	
	-- Returns whether the controller is active.
	function self:GetActive(): boolean
		return Active
	end

	-- Returns the current CFrame used to render the model.
	function self:GetCFrame(): CFrame
		return CF
	end

	-- Returns whether the model is anchored.
	function self:GetAnchor(): boolean
		return Anchored
	end

	-- Returns the current adornee used for rendering.
	function self:GetAdornee(): GuiObject
		return Adornee
	end

	-- Returns the current depth multiplier.
	function self:GetDepth(): number
		return Depth
	end
	
	-------------------------------------------- Util ----------------------------------------------
	
	-- Updates adornee cached properties
	function util.onAdorneeChange()
		absSize = Adornee.AbsoluteSize
		absPos = Adornee.AbsolutePosition
		adorneeRot = math.rad(Adornee.Rotation)
		sizeX, sizeY = absSize.X, absSize.Y
		pointX = absPos.X + sizeX * 0.5
		pointY = absPos.Y + sizeY * 0.5
		
		local newMinSize = math.min(sizeX, sizeY)
		if newMinSize ~= minSize then
			minSize = newMinSize
			
			camDepth = GetDepthForWidth(Width, minSize) / Depth
			ray = camera:ScreenPointToRay(pointX, pointY, camDepth)
		end
	end

	-- Handles the object rotation defined with self:SetRotation()
	-- WARNING: This is a private method. Don't call it.
	function self.__UpdatePos(A,B,C,D,E,F,G,H,I, cameraMoved): ()
		if not Active then
			if not WasMoved then
				Model:PivotTo(HighCF)
				WasMoved = true
			end
			return
		end

		-- Calculate screen center and screen delta
		local centerX = viewport.X * 0.5
		local centerY = viewport.Y * 0.5
		local deltaX = (pointX - centerX) / centerX
		local deltaY = (pointY - centerY) / centerY

		-- Cast ray from screen point into 3D world
		if cameraMoved then
			ray = camera:ScreenPointToRay(pointX, pointY, camDepth)
		end

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
		Model:PivotTo(baseCF * rotCF * CF * CFrame.Angles(0, 0, adorneeRot))
		WasMoved = false
	end
	
	-- Handles the object rotation defined with self:SetRotation()
	-- WARNING: This is a private method. Don't call it.
	function self.__UpdateRot(deltaTime: number): ()
		if rotationSpeed == 0 or not Active then
			return
		end

		-- Get rotation step
		local rotationStep = rotationSpeed * deltaTime

		-- Update CF directly
		if rotationAxis == "X" then
			CF *= CFrame.Angles(rotationStep, 0, 0)
		elseif rotationAxis == "Y" then
			CF *= CFrame.Angles(0, rotationStep, 0)
		elseif rotationAxis == "Z" then
			CF *= CFrame.Angles(0, 0, rotationStep)
		elseif rotationAxis == "XY" then
			CF *= CFrame.Angles(rotationStep, rotationStep, 0)
		elseif rotationAxis == "XZ" then
			CF *= CFrame.Angles(rotationStep, 0, rotationStep)
		elseif rotationAxis == "YZ" then
			CF *= CFrame.Angles(0, rotationStep, rotationStep)
		elseif rotationAxis == "XYZ" then
			CF *= CFrame.Angles(rotationStep, rotationStep, rotationStep)
		end
	end

	-- Connections
	local adorneePosCon = Adornee:GetPropertyChangedSignal("AbsolutePosition")
	local adorneeSizeCon = Adornee:GetPropertyChangedSignal("AbsoluteSize")
	local adorneeRotCon = Adornee:GetPropertyChangedSignal("Rotation")
	Connections["AdorneePos"] = adorneePosCon:Connect(util.onAdorneeChange)
	Connections["AdorneeSize"] = adorneeSizeCon:Connect(util.onAdorneeChange)
	Connections["AdorneeRot"] = adorneeRotCon:Connect(util.onAdorneeChange)
	
	table.insert(objT, self)
	self:SetAnchor(true)
	self:SetActive(false)
	
	return self
end

-- Updates camera properties on change
camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	-- Camera properties
	viewport = camera.ViewportSize
	AspectRatio = viewport.X/viewport.Y
	WFactor = AspectRatio * HFactor

	-- Horizontal/Vertical angles
	rawAngleX = AspectRatio * CamFOV
	angleX = rawAngleX > MaxFOV and MaxFOV or rawAngleX
	angleY = CamFOV * (rawAngleX > MaxFOV and (MaxFOV / rawAngleX) or 1)
end)

camera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
	-- Camera properties
	CamFOV = camera.FieldOfView
	HFactor = math.tan(math.rad(CamFOV) * 0.5)
	WFactor = AspectRatio * HFactor

	-- Horizontal/Vertical angles
	rawAngleX = AspectRatio * CamFOV
	angleX = rawAngleX > MaxFOV and MaxFOV or rawAngleX
	angleY = CamFOV * (rawAngleX > MaxFOV and (MaxFOV / rawAngleX) or 1)
end)

-- Control objects placement each frame
local lastCamView
local step = 0
local _,_,_,A,B,C,D,E,F,G,H,I = components(camera.CFrame)

local function onRenderStepped(delta: number)
	-- Detect if the camera Moved since the last Frame
	local cameraMoved = camera.CFrame ~= lastCamView
	
	if cameraMoved then
		_,_,_,A,B,C,D,E,F,G,H,I = components(camera.CFrame)
	end
	
	-- Handling objects
	for _, obj in objects.Anchored do
		-- Rotates the object (if rotation is enabled)
		obj.__UpdateRot(delta)

		-- If there's no camera movement and object is anchored
		-- skip 1 frame each 5. Improving performance. 
		if not cameraMoved and step % 5 == 0 then
			continue
		end

		-- Update object position
		obj.__UpdatePos(A,B,C,D,E,F,G,H,I, cameraMoved)
	end

	for _, obj in objects.Unanchored do
		-- Update object position & orientation
		obj.__UpdatePos(A,B,C,D,E,F,G,H,I, cameraMoved)
		obj.__UpdateRot(delta)
	end

	lastCamView = camera.CFrame
	step += 1
end

-- Connections --
RunService.RenderStepped:Connect(onRenderStepped)

return Zeno3D
