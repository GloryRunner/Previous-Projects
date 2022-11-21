-- Services
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroupService = game:GetService("GroupService")
local TextService = game:GetService("TextService")
 
-- Modules
local AdminConfig = require(script.Parent:WaitForChild("AdminConfig"))
 
-- Constants
local AdminPanelRemotes = ReplicatedStorage:WaitForChild("AdminPanelRemotes")
local BanPlayer = AdminPanelRemotes:WaitForChild("BanPlayer")
local UnbanPlayer = AdminPanelRemotes:WaitForChild("UnbanPlayer")
local MutePlayer = AdminPanelRemotes:WaitForChild("MutePlayer")
local UnmutePlayer = AdminPanelRemotes:WaitForChild("UnmutePlayer")
local WarnPlayer = AdminPanelRemotes:WaitForChild("WarnPlayer")
local KickPlayer = AdminPanelRemotes:WaitForChild("KickPlayer")
local MakeAnnouncement = AdminPanelRemotes:WaitForChild("MakeAnnouncement")
local EnableAdminPanel = AdminPanelRemotes:WaitForChild("EnableAdminPanel")
local PromptWarnNotification = AdminPanelRemotes:WaitForChild("PromptWarnNotification")
local CheckIfPlayerIsAnAdmin = AdminPanelRemotes:WaitForChild("CheckIfPlayerIsAnAdmin")
local HandleChatVisibility = AdminPanelRemotes:WaitForChild("HandleChatVisibility")
local CreateAdminLog = AdminPanelRemotes:WaitForChild("CreateAdminLog")
local CreateBanList = AdminPanelRemotes:WaitForChild("CreateBanList")
local RemoveFromBanList = AdminPanelRemotes:WaitForChild("RemoveFromBanList")
local ChangeCooldownState = AdminPanelRemotes:WaitForChild("ChangeCooldownState")
local CheckForHierarchyRequirement = AdminPanelRemotes:WaitForChild("CheckForHierarchyRequirement")
local RemovePlayerFromAdminList = AdminPanelRemotes:WaitForChild("RemovePlayerFromAdminList")
local AddPlayerToAdminList = AdminPanelRemotes:WaitForChild("AddPlayerToAdminList")
 
-- DataStore
local PunishmentData = DataStoreService:GetDataStore("PunishmentData")
local BanLogsData = DataStoreService:GetOrderedDataStore("BanLogs")
 
-- Caching
local StoredAdminLogs = {}
local StoredAdminUserIds = {}
local StoredBans = {}
local AdminsOnCooldown = {}
 
local AdminService = {}
 
function AdminService.Init()
    Players.PlayerAdded:Connect(function(Player)
        local Key = "Player-".. tostring(Player.UserId)
        local PlayerData = nil
 
        pcall(function()
            PlayerData = PunishmentData:GetAsync(Key)
        end)
 
        if not PlayerData then
            AdminService.SetPlayerBanDataToDefault(Player.Name)
        end
 
        if PlayerData then
            local BanData = AdminService.IsPlayerBanned(Player.Name)
 
            if BanData then
                Player:Kick("\n".. "You are banned.".. "\n".. "Reason: ".. PlayerData["BanReason"].. "\n".. "Banned by: ".. PlayerData["NameOfPersonWhoBanned"])
            end
        end
 
        if table.find(AdminsOnCooldown, Player.UserId) then
            task.spawn(function()
                ChangeCooldownState:FireClient(Player, "Enable")
                task.wait(30)
                table.remove(AdminsOnCooldown, table.find(AdminsOnCooldown, Player.UserId))
                ChangeCooldownState:FireClient(Player, "Disable")
            end)
        end
 
        if AdminService.CheckIfPlayerHasAdminPermissions(Player.Name) then
            table.insert(StoredAdminUserIds, Player.UserId)
 
            for _, LogText in ipairs(StoredAdminLogs) do
                AdminService.CreateAdminLog(LogText, false, false, Player)
            end
 
            for _, UserId in ipairs(StoredBans) do
                CreateBanList:FireClient(Player, UserId)
            end
 
            for _, Admin in ipairs(Players:GetPlayers()) do
                if table.find(StoredAdminUserIds, Admin.UserId) and Admin ~= Player then
                    AddPlayerToAdminList:FireClient(Admin, Player)
                end
            end
        end
 
        Player.Chatted:Connect(function(Message)
            AdminService.PromptPanel(Player, Message)
        end)
    end)
 
    Players.PlayerRemoving:Connect(function(Player)
        local PosInTable = table.find(StoredAdminUserIds, Player.UserId)
        if PosInTable then
            table.remove(StoredAdminUserIds, PosInTable)
        end
 
        for _, Admin in ipairs(Players:GetPlayers()) do
            if table.find(StoredAdminUserIds, Admin.UserId) then
                RemovePlayerFromAdminList:FireClient(Admin, Player)
            end
        end
    end)
 
    AdminService.HandleAdminCheckRequests()
    AdminService.HandleHierarchyCheckRequests()
    AdminService.CacheBanList()
    AdminService.MutePlayer()
    AdminService.UnmutePlayer()
    AdminService.KickPlayer()
    AdminService.BanPlayer()
    AdminService.UnbanPlayer()
    AdminService.AnnounceMessage()
    AdminService.WarnPlayer()
end
 
function AdminService.PromptPanel(Player, Message)
    if string.lower(Message) == ";adminpanel" and table.find(StoredAdminUserIds, Player.UserId) then
        EnableAdminPanel:FireClient(Player)
    end
end
 
function AdminService.HandleAdminCheckRequests()
    CheckIfPlayerIsAnAdmin.OnServerInvoke = function(_, PlayerBeingUsed)
        if table.find(StoredAdminUserIds, PlayerBeingUsed.UserId) then
            return true
        else
            return false
        end
    end
end
 
function AdminService.HandleHierarchyCheckRequests()
    CheckForHierarchyRequirement.OnServerInvoke = function(Player, NameOfPlayerBeingModerated)
        if AdminService.CheckIfPlayerMeetsHierarchyRequirement(Player.Name, NameOfPlayerBeingModerated) then
            return true
        else
            return false
        end
    end
end
 
-- Helper methods
 
function AdminService.CacheBanList()
    pcall(function()
        local BanData = BanLogsData:GetSortedAsync(false, 30)
        local Page = BanData:GetCurrentPage()
        for _, Data in ipairs(Page) do
            if Data.value == 1 then
                local ShortenedKey = string.gsub(Data.key, "Player", "")
                local UserId = tonumber(string.sub(ShortenedKey, 2, string.len(ShortenedKey)))
                table.insert(StoredBans, UserId)
            end
        end
    end)
end
 
function AdminService.CheckIfPlayerHasAdminPermissions(NameOfPlayer)
    local GroupId = AdminConfig.GroupId
    local AllowedGroupRanks = AdminConfig.AllowedGroupRanks
    local AllowedPlayers = AdminConfig.AllowedPlayers
    local Result = false
 
    pcall(function()
        if GroupId and table.find(AllowedPlayers, Players:GetUserIdFromNameAsync(NameOfPlayer)) or table.find(AllowedGroupRanks, AdminService.GetRankInGroupFromPlayerName(NameOfPlayer)) then
            Result = true
        elseif not GroupId then
            warn("GroupId is not set. Please set it in ServerScriptService -> AdminPanelServer -> AdminConfig.")
        end
    end)
 
    return Result
end
 
function AdminService.CheckIfPlayerMeetsHierarchyRequirement(NameOfAdmin, NameOfPlayerBeingModerated)
    local Result = false
 
    pcall(function()
        local AdminUserId = Players:GetUserIdFromNameAsync(NameOfAdmin)
        local PlayerBeingModeratedId = Players:GetUserIdFromNameAsync(NameOfPlayerBeingModerated)
        if table.find(AdminConfig.AllowedPlayers, AdminUserId) and not table.find(AdminConfig.AllowedPlayers, PlayerBeingModeratedId) and not table.find(AdminConfig.AllowedGroupRanks, AdminService.GetRankInGroupFromPlayerName(NameOfPlayerBeingModerated)) then
            Result = true
        end
    end)
 
    if AdminService.GetRankInGroupFromPlayerName(NameOfAdmin) > AdminService.GetRankInGroupFromPlayerName(NameOfPlayerBeingModerated) and not table.find(AdminConfig.AllowedPlayers, NameOfPlayerBeingModerated) then
        Result = true
    end
 
    return Result
end
 
function AdminService.GetRankInGroupFromPlayerName(PlayerName)
    local Result = 0
 
    pcall(function()
        for _, GroupData in ipairs(GroupService:GetGroupsAsync(Players:GetUserIdFromNameAsync(PlayerName))) do
            for _, PropertyValue in pairs(GroupData) do
                if PropertyValue == AdminConfig.GroupId then
                   Result = GroupData.Rank
                end
            end 
        end
    end)
    return Result
end
 
function AdminService.FilterText(NameOfPlayer, Text)
    local Result = nil
 
    pcall(function()
        local PlayerUserId = Players:GetUserIdFromNameAsync(NameOfPlayer)
        Result = TextService:FilterStringAsync(Text, PlayerUserId):GetChatForUserAsync(PlayerUserId)
   end)
 
   return Result
end
 
function AdminService.AddPlayerToBanList(NameOfPlayerBeingBanned, PlayerBanning, BanReason)
    pcall(function()
        local Key = "Player-".. tostring(Players:GetUserIdFromNameAsync(NameOfPlayerBeingBanned))
        local Data = PunishmentData:GetAsync(Key)
    
        if not Data then
            AdminService.SetPlayerBanDataToDefault(NameOfPlayerBeingBanned)
        end
        
        PunishmentData:SetAsync(Key, {
            ["IsPlayerMuted"] = Data["IsPlayerMuted"],
            ["MuteReason"] = Data["MuteReason"],
            ["NameOfPersonWhoMuted"] = Data["NameOfPersonWhoMuted"],
        
            ["IsPlayerBanned"] = true,
            ["BanReason"] = BanReason,
            ["NameOfPersonWhoBanned"] = PlayerBanning.Name
        })
        
        BanLogsData:SetAsync(Key, 1)
    end)
end
 
function AdminService.SetPlayerBanDataToDefault(PlayerName)
    pcall(function()
        local Key = "Player-".. tostring(Players:GetUserIdFromNameAsync(PlayerName))
 
        PunishmentData:SetAsync(Key, {
            ["IsPlayerMuted"] = false,
            ["MuteReason"] = nil,
            ["NameOfPersonWhoMuted"] = nil,
        
            ["IsPlayerBanned"] = false,
            ["BanReason"] = nil,
            ["NameOfPersonWhoBanned"] = nil
        })
    end)
end
 
function AdminService.RemovePlayerFromBanList(NameOfPlayerBeingRemoved)
    pcall(function()
        local Key = "Player-".. tostring(Players:GetUserIdFromNameAsync(NameOfPlayerBeingRemoved))
        local Data = PunishmentData:GetAsync(Key)
        PunishmentData:SetAsync(Key, {
            ["IsPlayerMuted"] = Data["IsPlayerMuted"],
            ["MuteReason"] = Data["MuteReason"],
            ["NameOfPersonWhoMuted"] = Data["NameOfPersonWhoMuted"],
        
            ["IsPlayerBanned"] = false,
            ["BanReason"] = nil,
            ["NameOfPersonWhoBanned"] = nil
        })
 
        BanLogsData:RemoveAsync(Key)
    end)
end
 
function AdminService.IsPlayerBanned(NameOfPlayer)
    local Result = nil
 
    pcall(function()
        local Key = "Player-".. tostring(Players:GetUserIdFromNameAsync(NameOfPlayer))
        local Data = PunishmentData:GetAsync(Key)
 
        if Data and Data["IsPlayerBanned"] then
            Result = true
        end
   end)
 
    return Result
end
 
function AdminService.GetPlayerRegardlessOfCapitalization(PlayerName)
    for _, Player in ipairs(Players:GetPlayers()) do
        if string.lower(Player.Name) == string.lower(PlayerName) then
            return Player
        end
    end
end
 
function AdminService.AddNewBanListMember(UserId)
    for _, Player in ipairs(Players:GetPlayers()) do
        if table.find(StoredAdminUserIds, Player.UserId) then
            CreateBanList:FireClient(Player, UserId)
        end
    end
end
 
function AdminService.RemoveBanListMember(UserId)
    for _, Player in ipairs(Players:GetPlayers()) do
        if table.find(StoredAdminUserIds, Player.UserId) then
            RemoveFromBanList:FireClient(Player, UserId)
        end
    end
end
 
-- Main Methods
 
function AdminService.CreateAdminLog(LogText, Store : boolean, Everyone : boolean, PlayerToPrompt)
   if Everyone then
        for _, Player in ipairs(Players:GetPlayers()) do
            for _, AdminID in ipairs(StoredAdminUserIds) do
                if Player.UserId == AdminID then
                    CreateAdminLog:FireClient(Player, LogText)
                end
            end
        end
    elseif not Everyone then
        CreateAdminLog:FireClient(PlayerToPrompt, LogText)
    end
 
    if Store then
        table.insert(StoredAdminLogs, LogText)
    end
end
 
function AdminService.MutePlayer()
    MutePlayer.OnServerEvent:Connect(function(Player, NameOfPlayerBeingMuted, MuteReason)
        if table.find(StoredAdminUserIds, Player.UserId) and NameOfPlayerBeingMuted and MuteReason and AdminService.CheckIfPlayerMeetsHierarchyRequirement(Player.Name, NameOfPlayerBeingMuted) then
            local PlayerBeingMuted = Players:FindFirstChild(NameOfPlayerBeingMuted)
            local FilteredMuteReason = AdminService.FilterText(Player.Name, MuteReason)
 
            if PlayerBeingMuted then
                HandleChatVisibility:FireClient(PlayerBeingMuted, "Disable")
                PromptWarnNotification:FireClient(PlayerBeingMuted, "MUTED", "You have been muted by ".. Player.Name.. "\n".. "\n".. "Reason: ".. FilteredMuteReason)
            end
            AdminService.CreateAdminLog("Moderator: ".. Player.Name.. " has Muted ".. NameOfPlayerBeingMuted.. "for the Reason: ".. FilteredMuteReason, true, true)
        end
    end)
end
 
function AdminService.UnmutePlayer()
    UnmutePlayer.OnServerEvent:Connect(function(Player, NameOfPlayerBeingUnmuted)
        if table.find(StoredAdminUserIds, Player.UserId) and NameOfPlayerBeingUnmuted then
            local PlayerBeingUnmuted = Players:FindFirstChild(NameOfPlayerBeingUnmuted)
 
            if PlayerBeingUnmuted then
                HandleChatVisibility:FireClient(PlayerBeingUnmuted, "Enable")
                PromptWarnNotification:FireClient(PlayerBeingUnmuted, "UNMUTED", "You have been unmuted by ".. Player.Name)
            end
 
            AdminService.CreateAdminLog("Moderator: ".. Player.Name.. " has Unmuted ".. NameOfPlayerBeingUnmuted, true, true)
        end
    end)
end
 
 
function AdminService.BanPlayer()
    BanPlayer.OnServerEvent:Connect(function(Player, NameOfPlayerBeingBanned, BanReason)
        if table.find(StoredAdminUserIds, Player.UserId) and NameOfPlayerBeingBanned and AdminService.CheckIfPlayerMeetsHierarchyRequirement(Player.Name, NameOfPlayerBeingBanned) and not table.find(AdminsOnCooldown, Player.UserId) then
            table.insert(AdminsOnCooldown, Player.UserId)
            ChangeCooldownState:FireClient(Player, "Enable")
            
            local FilteredBanReason = AdminService.FilterText(Player.Name, BanReason)
            AdminService.AddPlayerToBanList(NameOfPlayerBeingBanned, Player, FilteredBanReason)
 
            local PlayerBeingBanned = AdminService.GetPlayerRegardlessOfCapitalization(NameOfPlayerBeingBanned)
            if PlayerBeingBanned then
                PlayerBeingBanned:Kick("\n".. "You have been banned.".. "\n".. "Reason: ".. FilteredBanReason.. "\n".. "Banned by: ".. Player.Name)
            end
            
            AdminService.CreateAdminLog("Moderator: ".. Player.Name.. " has Banned ".. NameOfPlayerBeingBanned.. " for the Reason: ".. FilteredBanReason, true, true)
            
            pcall(function()
                AdminService.AddNewBanListMember(Players:GetUserIdFromNameAsync(NameOfPlayerBeingBanned))
            end)
 
            task.spawn(function()
                task.wait(30)
                table.remove(AdminsOnCooldown, table.find(AdminsOnCooldown, Player.UserId))
                ChangeCooldownState:FireClient(Player, "Disable")
            end)
        end
    end)
end
 
function AdminService.UnbanPlayer()
    UnbanPlayer.OnServerEvent:Connect(function(Player, NameOfPlayerBeingUnbanned)
        if table.find(StoredAdminUserIds, Player.UserId) and NameOfPlayerBeingUnbanned and not table.find(AdminsOnCooldown, Player.UserId) then
            table.insert(AdminsOnCooldown, Player.UserId)
            ChangeCooldownState:FireClient(Player, "Enable")
 
            AdminService.RemovePlayerFromBanList(NameOfPlayerBeingUnbanned)
            AdminService.CreateAdminLog("Moderator: ".. Player.Name.. " has Unbanned ".. NameOfPlayerBeingUnbanned, true, true)
 
            pcall(function()
                AdminService.RemoveBanListMember(Players:GetUserIdFromNameAsync(NameOfPlayerBeingUnbanned))
            end)
 
            task.spawn(function()
                task.wait(30)
                table.remove(AdminsOnCooldown, table.find(AdminsOnCooldown, Player.UserId))
                ChangeCooldownState:FireClient(Player, "Enable")
            end)
        end
    end)
end
 
function AdminService.AnnounceMessage()
    MakeAnnouncement.OnServerEvent:Connect(function(Player, AnnouncementTitle, AnnouncementMessage)
        if table.find(StoredAdminUserIds, Player.UserId) then
            local FilteredAnnouncementMessage = "Announcement from ".. Player.Name.. ": ".. AdminService.FilterText(Player.Name, AnnouncementMessage)
            local FilteredAnnouncementTitle = AdminService.FilterText(Player.Name, AnnouncementTitle)
 
            PromptWarnNotification:FireAllClients(FilteredAnnouncementTitle, FilteredAnnouncementMessage)
            AdminService.CreateAdminLog("Moderator: ".. Player.Name.. " has made an Announcement. Title: ".. FilteredAnnouncementTitle.. " Message: ".. FilteredAnnouncementMessage, true, true)
        end
    end)
end
 
function AdminService.WarnPlayer()
    WarnPlayer.OnServerEvent:Connect(function(Player, NameOfPlayerBeingWarned, WarnReason)
        if table.find(StoredAdminUserIds, Player.UserId) and WarnReason and NameOfPlayerBeingWarned and AdminService.CheckIfPlayerMeetsHierarchyRequirement(Player.Name, NameOfPlayerBeingWarned) then
            local FilteredWarnReason = AdminService.FilterText(Player.Name, WarnReason)
 
            local PlayerBeingWarned = AdminService.GetPlayerRegardlessOfCapitalization(NameOfPlayerBeingWarned)
            if PlayerBeingWarned then
                PromptWarnNotification:FireClient(PlayerBeingWarned, "WARNING", Player.Name.. " says: ".. FilteredWarnReason)
                AdminService.CreateAdminLog("Moderator: ".. Player.Name.. " has Warned ".. NameOfPlayerBeingWarned.. " for the Reason: ".. FilteredWarnReason, true, true)
            end
        end
    end)
end
 
function AdminService.KickPlayer()
    KickPlayer.OnServerEvent:Connect(function(Player, NameOfPlayerBeingKicked, KickReason)
        if table.find(StoredAdminUserIds, Player.UserId) and NameOfPlayerBeingKicked and KickReason and AdminService.CheckIfPlayerMeetsHierarchyRequirement(Player.Name, NameOfPlayerBeingKicked) then
            local FilteredKickReason = AdminService.FilterText(Player.Name, KickReason)
            local PlayerBeingKicked = AdminService.GetPlayerRegardlessOfCapitalization(NameOfPlayerBeingKicked)
 
            if PlayerBeingKicked then
                PlayerBeingKicked:Kick("\n".. "You have been kicked.".. "\n".. "Reason: ".. FilteredKickReason.. "\n".. "Kicked by: ".. Player.Name)
                AdminService.CreateAdminLog("Moderator: ".. Player.Name.. " has Kicked ".. NameOfPlayerBeingKicked.. "for the Reason: ".. FilteredKickReason, true, true)
            end
        end
    end)
end
 
return AdminService
