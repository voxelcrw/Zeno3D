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
 
 Zone3D is a rewritten of Module3D V4 by TheNexusAvenger
_________________________________________________________________________________________
]]--

-- Imports
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

if not RunService:IsClient() then
	error("Tried to require from a non-client Instance", 2)
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
	-- Type check
	assert(
		typeof(Model) == "Instance" and Model:IsA("Model"),
		"Attempt to use "..typeof(Model)..". Model expected."
	)
	
	assert(
		typeof(Adornee) == "Instance" and Adornee:IsA("GuiObject"),
		"Attempt to use "..typeof(Model)..". GuiObject expected."
	)
	
	local self = {}
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

	-- Handle type errors destroying the Controller.
	local function extremeTypeAssert(arg: any, expected: string)
		local sucess, errorm = pcall(function()
			local argType = typeof(arg)
			local isValid = (argType == "Instance" and arg:IsA(expected)
				or argType == expected)
			
			local errorLog = "Attempt to use %s. %s expected."
			assert(isValid, errorLog:format(argType, expected))
		end)

		if not sucess then
			self:Destroy()
			error(errorm, 2)
		end
	end
	
	-- Handle type errors returning a default value.
	local function safeTypeAssert(arg: any, expected: string, 
		default: any): any
		
		local argType = typeof(arg)
		local isValid = (argType == "Instance" and arg:IsA(expected)
			or argType == expected)
		
		if isValid then
			return arg
		end
		
		-- Logging error if argument is not valid.
		local log = "Attempt to use %s. %s expected. Value unchanged - %s"
		
		local trace = debug.traceback("", 3)
		local stackLines = {}
		for line in trace:gmatch("[^\r\n]+") do
			table.insert(stackLines, line)
		end
		
		--[[
		Warn when an argument is of an unexpected type. If you see these
		warnings, use the Explorer to navigate to the script and line 
		shown in the output. That is where the error occurred.
		]]--
		warn(log:format(argType, expected, stackLines[1]))
		
		return default
	end
	
	-- Runs everytime anything changes on Adornee
	local function onAdorneeChange()
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

	-- Bind adornee to call "onAdorneeChange" when some properties change.
	local function bindAdorneeChanges()
		-- Properties to be binded
		local bindProperties = {
			"AbsolutePosition", "AbsoluteSize", "Rotation"
		}
		
		-- Disconnecting old binds
		for con, signal in Connections do
			if table.find(bindProperties, con) then
				signal:Disconnect()
				Connections[con] = nil
			end
		end
		
		-- Binding
		for _, con in bindProperties do
			Connections[con] = Adornee:GetPropertyChangedSignal(con):Connect(onAdorneeChange)
		end
	end

	-------------------------------------------- Methods ----------------------------------------------
	
	-- Sets the model's CollisionGroup. The group must already exist in the game.
	function self:SetCollisionGroup(groupName: string)
		if typeof(groupName) ~= "string" then
			warn("Attempt to use "..typeof(groupName)..". string expected.")
			return
		end
		
		if not PhysicsService:IsCollisionGroupRegistered(groupName) then
			warn(groupName.." is not a valid Collision group!")
			return
		end
		
		for _, v in Object3D:GetDescendants() do
			if v:IsA("BasePart") then
				v.CollisionGroup = groupName
			end
		end
	end
	
	-- Enables automatic axis rotation at the given speed (radians per frame). 
	-- Set to 0 to disable the rotation. Axis is Y by default.
	function self:SetRotation(speed: number, axis: RotationAxis?): ()
		local value = safeTypeAssert(speed, "number", rotationSpeed)
		
		rotationAxis = table.find(validAxes, axis) and axis or "Y" -- Y is the default axis
		rotationSpeed = math.rad(value)
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
		Active = safeTypeAssert(state, "boolean", Active)
		Model.Parent = Active and camera or nil
	end
	
	-- Sets the model's CFrame (rotation). Only use CFrame.Angles
	function self:SetCFrame(value: CFrame): ()
		CF = safeTypeAssert(value, "CFrame", CF)
	end
	
	-- Anchors the model. Anchored models are ~20% more performant.
	-- This option is true by default.
	function self:SetAnchor(state: boolean): ()
		Anchored = safeTypeAssert(state, "boolean", Anchored)
		
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
		Adornee = safeTypeAssert(guiObj, "GuiObject", Adornee)
		
		-- Update
		onAdorneeChange()
		bindAdorneeChanges()

		-- Update ray results, avoiding visual glitches when the camera hasn't moved.
		ray = camera:ScreenPointToRay(pointX, pointY, camDepth)
	end
	
	-- Sets the model’s rendering depth multiplier (distance from the camera).
	function self:SetDepth(value: number): ()
		Depth = safeTypeAssert(value, "number", Depth)

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
	bindAdorneeChanges()
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
