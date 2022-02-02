#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#pragma semicolon 1

public Plugin myinfo = 
{
	name = "LandFix",
	author = "Haze",
	description = "",
	version = "1.1",
	url = ""
}

//ConVar gCV_Units = null;
Handle gH_CookieEnabled = null;

bool gB_Enabled[MAXPLAYERS+1] = {false, ...};

public void OnPluginStart()
{
	RegConsoleCmd("sm_landfix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_64fix", Command_LandFix, "Landfix");
	//gCV_Units = CreateConVar("landfix_units", "1.5", "", 0, true, 0.0, true, 2.0);
	
	gH_CookieEnabled = RegClientCookie("landfix_enabled", "landfix_enabled", CookieAccess_Protected);
	//AutoExecConfig();
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
			OnClientPutInServer(i);
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char strCookie[8];
	GetClientCookie(client, gH_CookieEnabled, strCookie, sizeof(strCookie));
	gB_Enabled[client] = view_as<bool>(StringToInt(strCookie));
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_GroundEntChangedPost, OnGroundChange);
}

public void OnGroundChange(int client)
{
	if(!gB_Enabled[client]) return;
	
	RequestFrame(DoLandFix, client);
}

public Action Command_LandFix(int client, int args)
{
	if(client == 0) return Plugin_Handled;

	gB_Enabled[client] = !gB_Enabled[client];
	SetClientCookie(client, gH_CookieEnabled, gB_Enabled[client] ? "1" : "0");
	PrintToChat(client, "LandFix: %s", gB_Enabled[client] ? "Enabled" : "Disabled");
	return Plugin_Handled;
}

//Thanks MARU for the idea/http://steamcommunity.com/profiles/76561197970936804
float GetGroundUnits(int client)
{
	if (!IsPlayerAlive(client)) return 0.0;
	if (GetEntityMoveType(client) != MOVETYPE_WALK) return 0.0;
	if (GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1) return 0.0;

	float origin[3], originBelow[3], landingMins[3], landingMaxs[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
	GetEntPropVector(client, Prop_Data, "m_vecMins", landingMins);
	GetEntPropVector(client, Prop_Data, "m_vecMaxs", landingMaxs);
	
	originBelow[0] = origin[0];
	originBelow[1] = origin[1];
	originBelow[2] = origin[2] - 2.0;

	TR_TraceHullFilter(origin, originBelow, landingMins, landingMaxs, MASK_PLAYERSOLID, PlayerFilter, client);
	
	if(TR_DidHit())
	{
		TR_GetEndPosition(originBelow, null);
		float defaultheight = originBelow[2] - RoundToFloor(originBelow[2]);
		if(defaultheight > 0.03125) defaultheight = 0.03125;
		float heightbug = origin[2] - originBelow[2] + defaultheight;
		return heightbug;
	}
	else
	{
		return 0.0;
	}
}

void DoLandFix(int client)
{
	int iGroundEnt = GetEntPropEnt(client, Prop_Data, "m_hGroundEntity");

	// jump start
	if(iGroundEnt == -1)
	{
		return;
	}

	bool bHasVelocityProp = HasEntProp(iGroundEnt, Prop_Data, "m_vecVelocity");

	if(bHasVelocityProp)
	{
		float fVelocity[3];
		GetEntPropVector(iGroundEnt, Prop_Data, "m_vecVelocity", fVelocity);

		// ground is moving
		if(fVelocity[2] != 0.0)
		{
			return;
		}
	}

	//float difference = (gCV_Units.FloatValue - GetGroundUnits(client)), origin[3];
	float difference = (1.50 - GetGroundUnits(client)), origin[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
	origin[2] += difference;
	SetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
}

public bool PlayerFilter(int entity, int mask)
{
	return !(1 <= entity <= MaxClients);
}