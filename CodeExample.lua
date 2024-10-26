local NPC = script.Parent
local NPChumanoid = NPC:WaitForChild("Humanoid")
local NPCPrimaryPart = NPC:WaitForChild("HumanoidRootPart")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathFindingService = game:GetService("PathfindingService")
local MaxDistance = 50
local SeeableTarget = nil
local AgressiveDistance = 20
local State = NPChumanoid:GetState()
local TargetsOnRange = {}
NPCPrimaryPart:SetNetworkOwner(nil)
local TableOfSeeableTargets = {}
local Yielding = false
local ReachedConnection
local PathBlockedConnection
local Cooldown = 5
local CurrentlyMovingToTargetAfterLostSight = false
local Chasing = false
local MaxRetry = 5
local CurrentlyMovingRandomly = false
local RaycastParam = RaycastParams.new()
RaycastParam.FilterType = Enum.RaycastFilterType.Exclude
local RaycastFilterTable = {}
for i,v in pairs(NPC:GetDescendants()) do
	if v:IsA("BasePart") then
		if v.Name ~= "HumanoidRootPart" then
			table.insert(RaycastFilterTable,v)
			RaycastParam.FilterDescendantsInstances = RaycastFilterTable -- We  setup our table with first blacklisted Instances.
		end
	end
end
function TargetOnSight()
	local Nearest = GetNearestPlayer()
	if Nearest then
		if TableOfSeeableTargets[Nearest.Parent.Name] then
			return true
		end
	end
	return false
end
function GetTargetsOnRange()
	for _,Player in pairs(Players:GetPlayers()) do
		if Player.Character then
			local Char : Model = Player.Character
			if Char:FindFirstChild("HumanoidRootPart") then
				local TargetHRP : Part = Char:FindFirstChild("HumanoidRootPart")
				local Distance = (TargetHRP.Position - NPCPrimaryPart.Position).Magnitude
				if Distance < 80 then -- If Distance is lowwer than 80,we will Insert it to the table.
					table.insert(TargetsOnRange,TargetHRP)
				end
			end
		end
	end
end
function UpdateBlackList() -- We Update Blacklist here every while loop's procedure,check below to see the while loop.
	for _,player in pairs(Players:GetPlayers()) do
		if player.Character then
			local Char : Model = player.Character
			for _,Ins in pairs(Char:GetDescendants()) do
				if not table.find(RaycastFilterTable,Ins) then
					if Ins:IsA("BasePart") then
						if Ins.Name ~= "HumanoidRootPart" then
							table.insert(RaycastFilterTable,Ins)
							RaycastParam.FilterDescendantsInstances = RaycastFilterTable
						end
					end
				end
			end
		end
	end
end
function GetNearestPlayer() -- We Get Nearest Player with this function by using Distance.
	local Target : Part = nil
	for _,Player in pairs(Players:GetPlayers()) do
		if Player.Character then
			local Char : Model = Player.Character
			if Char:FindFirstChild("HumanoidRootPart") then
				local TargetHRP : Part = Char:FindFirstChild("HumanoidRootPart")
				local Distance = (TargetHRP.Position - NPCPrimaryPart.Position).Magnitude
				if Distance < 80 then
					if Target then
						if (Target.Position - NPCPrimaryPart.Position).Magnitude > (TargetHRP.Position - NPCPrimaryPart.Position).Magnitude then
							Target = TargetHRP
						end
					else
						Target = TargetHRP
					end
				end
			end
		end
	end
	return Target
end
function GetSeeablePlayers() -- We now detect with this function whether NPC can see the target.
	for _,Player in pairs(Players:GetPlayers()) do
		if Player.Character then
			local Char : Model = Player.Character
			if Char.Humanoid.Health == 0 then
				TableOfSeeableTargets[Char.Name] = nil
			else
				if Char:FindFirstChild("HumanoidRootPart") then
					local HRP : Part = Char:FindFirstChild("HumanoidRootPart")
					local Raycast = workspace:Raycast(NPCPrimaryPart.Position,(HRP.Position - NPCPrimaryPart.Position).Unit * 200,RaycastParam)
					if Raycast and Raycast.Instance then
							local Ins : Part = Raycast.Instance
							if Ins.Name == "HumanoidRootPart" then
								if Ins.Parent == HRP.Parent then
									TableOfSeeableTargets[Char.Name] = Ins
								end
							else
								TableOfSeeableTargets[Char.Name] = nil
						  end
          end
				end
			end
		end
	end
end
local Moving = false
local function PathfindTo(TargetPosition : Vector3) -- We now get the best path find for the NPC for to reach TargetPosition.
	local Path = game:GetService("PathfindingService"):CreatePath()
	local success, errorMessage = pcall(function()
		Path:ComputeAsync(NPC.PrimaryPart.Position, TargetPosition)
	end)
	if success and Path.Status == Enum.PathStatus.Success then
		Moving = true
		local waypoints = Path:GetWaypoints()
		local blockedConnection
		local reachedConnection
		local nextWaypointIndex
		local PathValue = Instance.new("BoolValue")
		PathValue.Name = "Path"
		PathValue.Parent = NPC.Paths
		local function DestroyPath()
			reachedConnection:Disconnect()
			blockedConnection:Disconnect()
			if PathValue then
				PathValue:Destroy()
			end
			Moving = false
		end
		PathValue.Changed:Connect(function()
			if PathValue.Value == true then
				DestroyPath()
			end
		end)
		blockedConnection = Path.Blocked:Connect(function(blockedWaypointIndex)
			if blockedWaypointIndex >= nextWaypointIndex then
				blockedConnection:Disconnect()
				DestroyPath()
			end
		end)
		if not reachedConnection then
			reachedConnection = NPChumanoid.MoveToFinished:Connect(function(reached)
				if reached and nextWaypointIndex < #waypoints then
					nextWaypointIndex += 1
					NPChumanoid:MoveTo(waypoints[nextWaypointIndex].Position)
				else 
					DestroyPath()
				end
			end)
		end
		nextWaypointIndex = 2
		NPChumanoid:MoveTo(waypoints[nextWaypointIndex].Position) 
	end
end
function DistanceWithTarget(Target : Part) -- This function calculates range with the target and npc.
	local Distance = (NPCPrimaryPart.Position - Target.Position).Magnitude
	if Distance < 30 then
		for i,v in ipairs(NPC.Paths:GetChildren()) do
			v.Value = true
		end
		return Distance
	end
end
function MoveToTarget(Target : Part) -- This function allows us to move towards Target.
	for i,v in ipairs(NPC.Paths:GetChildren()) do
		v.Value = true
	end
	local Path = game:GetService("PathfindingService"):CreatePath()
	Path:ComputeAsync(NPCPrimaryPart.Position,Target.Position)
	if Path.Status == Enum.PathStatus.Success then
		local Waypoints = Path:GetWaypoints()
		if #Waypoints > 2 then
			NPChumanoid:MoveTo(Waypoints[3].Position)
		end
	end
end
function MoveRandomly(RandomPos : Vector3) -- MoveRandomly function,this lets our npc to walk where it wants by math.random for details see the loop below.
	if Moving then return end
	PathfindTo(NPC.PrimaryPart.Position + RandomPos)
end
function TestRun() 
	GetTargetsOnRange() -- We also Get Targets on Range through here.
	local RandomPos = Vector3.new(math.random(-50,50),0,math.random(-50,50)) -- RandomPosition to Walk If NPC doesn't detect anything.
	UpdateBlackList() -- We Update Blacklist here with the following function here.
	local Nearest = GetNearestPlayer() -- We get the NearestPlayer possible.
	GetSeeablePlayers() -- We  get the SeeablePlayers through raycast.
	if Nearest then
		if TableOfSeeableTargets[Nearest.Parent.Name] then
			local Distance = DistanceWithTarget(Nearest)
			if Distance then
				return false
			else
				MoveToTarget(Nearest) -- We Move Target towards the Nearest Player.
			end
		else
			MoveRandomly(RandomPos)  -- If we don't see any values Inside the table,It moves randomnly.
		end
	else
		MoveRandomly(RandomPos)  -- If Nearest is Nil,It moves randomly.
	end
end
while wait(0.1) do
	TestRun() -- Initializing the Code.
end
