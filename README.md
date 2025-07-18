# Zeno3D
A rewritten and optimized version of Module3D V4 by [@TheNexusAvenger](https://github.com/TheNexusAvenger).

Zeno3D restores and improves Module3D V4, offering full control over 3D rendering without relying on ViewportFrames. It provides high customizability, simplicity, intuitive and ***super easy*** usage for advanced UI-based 3D visualization

## Installation
[Download the latest Zeno3D.rbxm](https://github.com/voxelcrw/Zeno3D/releases)\
[Get Zeno3D on Roblox Creator Hub](https://create.roblox.com/store/asset/117713259173402/Zeno3D)\
[Get Zeno3D on Wally](https://wally.run/package/voxelcrw/zeno3d)\
[Copy Zeno3D source code](https://raw.githubusercontent.com/voxelcrw/Zeno3D/refs/heads/main/src/Zeno3D.luau)

## Benchmark
Benchmarks were run using 10 models on screen, each containing 1600 parts (totaling ***16,000 parts*** rendered in ***real time***). All tests were performed with Roblox graphics set to maximum in an empty Baseplate with **Anchored** models. Results may vary depending on your hardware.

|Version          |FPS (Moving Camera) |FPS (Idle Camera) |Resources Usage (Micro Profiler) |
|-----------------|--------------------|------------------|---------------------------------|
|v1.1.0           |30                  |75                |🟩 Consistently low             |
|v1.0.1           |29                  |55                |🟧 Mid-low                      |
|v1.0.0           |28                  |50                |📉 Mid-high and Inconsistent    |
|Module3D V4      |26                  |26                |👎 Super Higher                 |

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
`Controller:MakeJoints()`\
Automatically weld the entire model. Recommended to call it before or exactly after you Unanchor the model. ***If your unanchored model are not showing on screen, consider using it***.

`Controller:SetCollisionGroup(groupName: string)`\
Sets the model's CollisionGroup. The group must already exist in the game.

`Controller:SetRotation(speed: number, axis: ("X" | "Y" | "Z" | "XY" | "XZ" | "YZ" | "XYZ"))`\
Enables automatic axis rotation at the given speed (radians per frame).
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

## Tips and Tricks
- You can use TweenService to animate the Adornee (position, size, rotation, etc.) and achieve powerful effects. Like a model growing on screen, a pet hatching animation, or anything like that. Since the Adornee is just a 2D GUI object, you can treat it like any other UI element for animations. Which will also apply to the Model.
- Physical properties like *CanCollide*, *CanTouch*, and *CanQuery* are automatically disabled. Keep them off to reduce overhead and maximize performance.
- Models are anchored by default and is recommended to stay that way for best performance. As shown in the benchmarks.
- If your models fall when unanchored or don't appearing on screen, they're probably not properly welded. Calling `MakeJoints()` can help fix that.
- Some specific models (like rigged ones) may still collide even with *CanCollide* set to false. To fix this, create a [CollisionGroup](https://create.roblox.com/docs/reference/engine/classes/BasePart#CollisionGroup) and assign it using the `SetCollisionGroup(groupName)` method.
- If your model is colliding with Workspace objects, try using `Controller:GetObject():ScaleTo(0.1)` followed by `Controller:SetDepth(2)` (or higher). This keeps the model visually the same size and position on screen, but makes it physically smaller. Which can help avoid unwanted collisions.
  
## Notes
Zeno3D is generally more performance-intensive than ViewportFrames, but it offers key advantages: full particle support and no visual quality loss. It’s actively maintained and optimized with every version. With the latest performance updates, FPS drops are minimal — often unnoticeable.

That said, you won’t experience any FPS drops with three, four, or fewer models on screen. Especially if each model has fewer than 250 parts.
As shown in the benchmark, even with *16,000 parts rendered simultaneously* and graphics set to **maximum**, the latest version of Zeno3D maintained over **70 FPS** while idle. This gives you the freedom to display multiple complex models without immediately tanking performance.
