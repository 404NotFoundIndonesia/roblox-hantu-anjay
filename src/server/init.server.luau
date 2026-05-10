--!strict

-- init.server.luau
-- Server bootstrap entry point.
-- T-09: Require Remotes first to create all Remote instances before any player joins.
-- Full system bootstrap (T-47) will require all server systems from here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create all RemoteEvents and RemoteFunctions in ReplicatedStorage/Remotes/
-- Must happen before Players.PlayerAdded can fire meaningful events.
require(ReplicatedStorage.Shared.Remotes)

-- TODO (T-47): require and initialise all server systems in dependency order.
