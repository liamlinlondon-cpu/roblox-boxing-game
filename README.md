# roblox-boxing-game
A Roblox boxing game featuring gym training, player progression, combat mechanics, and multiplayer/AI matches

## Setup notes
- **HD Admin**: cannot be created from code. In Studio, open Toolbox > Models, search "HD Admin" (by ROBLOX-owned HDAdmin), insert it into Workspace, and publish.
- **Robux items**: create one Developer Product per item in `ReplicatedStorage/Modules/Catalog.lua` (price must match `robux`) and paste its ID into `productId` (luck uses `LuckProductIds`). `productId = 0` is a free Studio-only test grant. Robux is paid to the experience owner, so make liamtw1 the owner (or group owner) in Creator Dashboard; scripts can't redirect payouts.
