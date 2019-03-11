#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>

int
	g_iMax,
	g_iDrop;
	
ConVar
	cvMax,
	cvDrop;
	
Handle
	g_hEntities[MAXPLAYERS+1];
	
public Plugin myinfo = 
{
	name = "Pickup Mod",
	author = "myst",
	description = "Pick up any entity you are looking at.",
	version = "1.0",
	url = "https://titan.tf"
}

public void OnPluginStart()
{
	cvMax 	= CreateConVar("sm_pickup_max", "10", "Change the maximum things a player can pick up.", _, true, 0.0, true, 2048.0);
	cvDrop 	= CreateConVar("sm_pickup_drop", "1", "Whether to drop pickups on death. (0 = No, 1 = Yes)", _, true, 0.0, true, 1.0);
	
	g_iMax 	= cvMax.IntValue;
	g_iDrop = cvDrop.IntValue;
	
	cvMax.AddChangeHook(OnCvarChanged);
	cvDrop.AddChangeHook(OnCvarChanged);
	
	RegAdminCmd("sm_pickup", Command_Pickup, ADMFLAG_GENERIC);
	RegAdminCmd("sm_drop", Command_Drop, ADMFLAG_GENERIC);
	
	HookEvent("player_death", Event_PlayerDeath);
	
	OnMapStart();
	for (int i = 1; i <= MaxClients; i++) if (IsValidClient(i))
		OnClientPutInServer(i);
}

public void OnPluginEnd() {
	for (int i = 1; i <= MaxClients; i++) if (IsValidClient(i))
		OnClientDisconnect(i);
}

public int OnCvarChanged(ConVar cvar, const char[] oldValue, const char[] newValue) {
	if (cvar == cvMax) g_iMax = cvMax.IntValue;
	if (cvar == cvDrop) g_iDrop = cvDrop.IntValue;
}

public void OnMapStart() {
	PrecacheModel("models/effects/bday_gib01.mdl");
}

public void OnMapEnd() {
	for (int i = 1; i <= MaxClients; i++) if (IsValidClient(i))
		ClearArray(g_hEntities[i]);
}

public void OnClientPutInServer(int iClient) {
	g_hEntities[iClient] = CreateArray(2049);
	SDKHook(iClient, SDKHook_PreThink, Hook_OnPreThink);
}

public void OnClientDisconnect(int iClient) {
	ClearArray(g_hEntities[iClient]);
	SDKUnhook(iClient, SDKHook_PreThink, Hook_OnPreThink);
}

public Action Event_PlayerDeath(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (GetEventInt(hEvent, "death_flags") & TF_DEATHFLAG_DEADRINGER) {
		return Plugin_Continue;
	}
	
	if (g_iDrop == 1) {
		ClearArray(g_hEntities[GetClientOfUserId(GetEventInt(hEvent, "userid"))]);
	}
	return Plugin_Continue;
}

public Action Command_Pickup(int iClient, int iArgs)
{
	if (GetArraySize(g_hEntities[iClient]) + 1 <= g_iMax)
	{
		int iTarget = GetClientPointVisible(iClient);
		if (iTarget > 0)
			PushArrayCell(g_hEntities[iClient], iTarget);
		else
			ReplyToCommand(iClient, "[SM] No valid entity was found.");
	}
	
	else
	{
		ReplyToCommand(iClient, "[SM] You have reached the maximum number of things you can carry.");
	}
	
	return Plugin_Handled;
}

public Action Command_Drop(int iClient, int iArgs)
{
	Handle hMenu = CreateMenu(Command_Drop_Callback, MenuAction_Select | MenuAction_End | MenuAction_DisplayItem);
	SetMenuTitle(hMenu, "Picked Up Items\n \n");
	
	if (GetArraySize(g_hEntities[iClient]) != 0)
	{
		char sIndex[255];
		for (int i = 0; i < GetArraySize(g_hEntities[iClient]); i++)
		{
			char sModel[PLATFORM_MAX_PATH];
			GetEntPropString(GetArrayCell(g_hEntities[iClient], i), Prop_Data, "m_ModelName", sModel, PLATFORM_MAX_PATH);
			
			Format(sIndex, sizeof(sIndex), "%i", i);
			AddMenuItem(hMenu, sIndex, sModel);
		}
	}
	
	else {
		AddMenuItem(hMenu, "", "Nothing.", ITEMDRAW_DISABLED);
	}
	
	DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int Command_Drop_Callback(Handle hMenu, MenuAction maAction, int iClient, int iButton)
{
	switch (maAction)
	{
		case MenuAction_Select:
		{
			char sItem[64];
			GetMenuItem(hMenu, iButton, sItem, sizeof(sItem));
			
			float vPos[3];
			if (SetTeleportEndPoint(iClient, vPos))
			{
				TeleportEntity(StringToInt(sItem), vPos, NULL_VECTOR, NULL_VECTOR);
				RemoveFromArray(g_hEntities[iClient], StringToInt(sItem));
				
				Command_Drop(iClient, 0);
				ReplyToCommand(iClient, "[SM] Item dropped.");
			}
			
			else
			{
				ReplyToCommand(iClient, "[SM] Could not find a place to drop.");
			}
		}
		
		case MenuAction_End:
		{
			CloseHandle(hMenu);
		}
	}
}

public void OnEntityDestroyed(int iEntity)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidClient(iClient))
		{
			for (int i = 0; i < GetArraySize(g_hEntities[iClient]); i++)
			{
				if (iEntity == GetArrayCell(g_hEntities[iClient], i)) {
					RemoveFromArray(g_hEntities[iClient], GetArrayCell(g_hEntities[iClient], i));
					break;
				}
			}
		}
	}
}

public Action Hook_OnPreThink(int iClient)
{
	float vPos[3];
	float vAng[3];
	float vVelocity[3];
	
	if (GetArraySize(g_hEntities[iClient]) > 0)
	{
		for (int i = 0; i < GetArraySize(g_hEntities[iClient]); i++)
		{
			GetClientAbsOrigin(iClient, vPos);
			GetEntPropVector(iClient, Prop_Data, "m_angRotation", vAng);
			
			vPos[2] += 100.0;
			
			GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVelocity);
			TeleportEntity(GetArrayCell(g_hEntities[iClient], i), vPos, vAng, vVelocity);
		}
	}
}

stock int GetClientPointVisible(int iClient)
{
	float vOrigin[3]; float vAngles[3]; float vEndOrigin[3];
	
	GetClientEyePosition(iClient, vOrigin);
	GetClientEyeAngles(iClient, vAngles);
	
	Handle hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_ALL, RayType_Infinite, TraceDontHitEntity, iClient);
	TR_GetEndPosition(vEndOrigin, hTrace);
	
	int iReturn = -1;
	int iHit = TR_GetEntityIndex(hTrace);
	
	if (TR_DidHit(hTrace) && iHit != iClient) {
		iReturn = iHit;
	}
	
	CloseHandle(hTrace);
	return iReturn;
}

public bool TraceDontHitEntity(int iEntity, int iMask, any iData)
{
	if (iEntity == iData) return false;
	return true;
}

stock bool SetTeleportEndPoint(int iClient, float flPosition[3])
{
	float vAngles[3];
	float vOrigin[3];
	float vBuffer[3];
	float vStart[3];
	float flDist;
	
	GetClientEyePosition(iClient, vOrigin);
	GetClientEyeAngles(iClient, vAngles);
	
	//get endpoint for teleport
	Handle hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer2);

	if (TR_DidHit(hTrace))
	{   	 
   	 	TR_GetEndPosition(vStart, hTrace);
		GetVectorDistance(vOrigin, vStart, false);
		flDist = -35.0;
   	 	GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		flPosition[0] = vStart[0] + (vBuffer[0] * flDist);
		flPosition[1] = vStart[1] + (vBuffer[1] * flDist);
		flPosition[2] = vStart[2] + (vBuffer[2] * flDist);
	}
	
	else
	{
		CloseHandle(hTrace);
		return false;
	}
	
	CloseHandle(hTrace);
	return true;
}

public bool TraceEntityFilterPlayer2(int iEntity, int contentsMask)
{
	return iEntity > GetMaxClients() || !iEntity;
}

stock bool IsValidClient(int iClient, bool bReplay = true)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return false;
	if (bReplay && (IsClientSourceTV(iClient) || IsClientReplay(iClient)))
		return false;
	return true;
}