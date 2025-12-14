# MineRock

## Drivable boat setup in Roblox Studio
The `BoatController` server script drives any Model tagged `DriveableBoat` that contains a `VehicleSeat` and at least one `BasePart`.
Follow these steps to get a boat working in Studio:

1. Place `BoatController.server.lua` under **ServerScriptService** in your place.
2. In your boat Model:
   - Add a `VehicleSeat` and orient it facing forward.
   - Set **PrimaryPart** on the Model to the hull or another central `BasePart` so movement uses the correct reference. If you do not set a PrimaryPart, the script will fall back to the first `BasePart` it finds.
   - Make sure the boat is **not Anchored** so physics can move it.
3. Use **CollectionService** to apply the `DriveableBoat` tag to the boat Model.
4. Test the game. Sitting in the boat seat will apply throttle and steer input to move and rotate the boat using BodyVelocity and BodyGyro movers.

No additional Studio configuration is required beyond tagging the boat and placing the script. Multiple tagged boats will all be controlled automatically.
