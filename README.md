# Zeno3D
A rewritten and optimized version of Module3D V4 by [@TheNexusAvenger](https://github.com/TheNexusAvenger).

Zeno3D restores and improves Module3D V4, offering full control over 3D rendering without relying on ViewportFrames. While potentially more performance-intensive, it provides high customizability, simplicity, and intuitive usage for advanced UI-based 3D visualization

## Installation
[Download the latest Zeno3D.rbxm](https://github.com/voxelcrw/Zeno3D/releases)\
[Get Zone3D on Roblox Creator Hub](https://create.roblox.com/store/asset/117713259173402/Zeno3D)

## Code Examples
```luau
-- Requiring module
local Zeno3D = require(path.to.Zone3D)

-- Getting the model and GUI object (can be any GuiObject: Frame, ImageButton, etc.)
local Model = workspace.CarModel
local Frame = game.StarterGui.ScreenGui.ExampleFrame

-- Creating the controller
local Controller = Zeno3D:Attach3D(Model, Frame)
Controller:SetActive(true) -- Required to display the model on screen
Controller:SetDepth(3) -- Brings the model 3x closer to the player's camera
Controller:SetCFrame(CFrame.Angles(0, math.rad(180), 0)) -- Rotate the model (recommended: use CFrame.Angles)
```

## API Usage
### Methods
`Controller:SetCollisionGroup(groupName: string)`\
Sets the model's CollisionGroup. The group must already exist in the game.

`Controller:SetRotation(speed: number)`\
Enables automatic Y-axis rotation at the given speed (radians per frame).
Set to 0 to disable the rotation.

`Controller:Destroy()`\
Destroys the controller and disconnects all internal bindings.

### Setters
`Controller:SetActive(state: boolean)`\
Enable or disable the controller. Must be enabled to render the model.

`Controller:SetCFrame(value: CFrame)`\
Sets the model's CFrame (rotation). Only use CFrame.Angles — for positioning, update the adornee or its properties instead.

`Controller:SetAnchor(state: boolean)`\
Anchors or unanchors the model. Defaults to true. Anchored models are more performant.

`Controller:SetAdornee(guiObj: GuiObject)`\
Sets the GUI object (adornee) used to render the model.

`Controller:SetDepth(value: number)`\
Sets the model’s rendering depth multiplier (distance from the camera).

### Getters
`Controller:GetObject()`\
Returns the model being rendered by the controller.

`Controller:GetActive()`\
Returns whether the controller is active.

`Controller:GetCFrame()`\
Returns the current CFrame used to render the model.

`Controller:GetAnchor()`\
Returns whether the model is anchored.

`Controller:GetAdornee()`\
Returns the current adornee used for rendering.

`Controller:GetDepth()`\
Returns the current depth multiplier.

## Notes
Zeno3D is generally more **performance-intensive** than ViewportFrames, especially when rendering *complex models with many parts* or *displaying multiple models on screen.*

Optimizing Zeno3D for performance is one of my top priorities.

That said, you likely won’t experience issues with just one model on screen. However, if you're planning to display many models simultaneously, consider the following tips:
- Disable unnecessary physical properties on each part. ***CanCollide***, ***CanTouch***, ***CanQuery***, ***CastShadow***
- Use simplified or low-poly versions of your models if you think it's lagging so much
- Anchor the Model with `Controller:SetAnchor(true)` — this can improve performance by up to ~20% per model
