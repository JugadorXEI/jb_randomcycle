/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod Random Map Cycle Plugin
 * Randomly picks a map from the mapcycle.
 *
 * SourceMod (C)2004-2014 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#pragma semicolon 1
#include <sourcemod>

#pragma newdecls required

#define PLUGIN_VERSION "v1.00"

public Plugin myinfo =
{
	name = "RandomCycle (JBEP3 ver.)",
	author = "AlliedModders LLC, modified by JugadorXEI",
	description = "Randomly chooses the next map.",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

ConVar g_Cvar_ExcludeMaps;

ArrayList g_MapList = null;
ArrayList g_OldMapList = null;
int g_mapListSerial = -1;

char cSelectedMaplist[32] = "jbep3_default";
char cSelectedGamemode[32] = "default";

// Keyvalue handle
Handle g_hKeyvaluesMapFile = INVALID_HANDLE;

public void OnPluginStart()
{
	int arraySize = ByteCountToCells(PLATFORM_MAX_PATH);	
	g_MapList = new ArrayList(arraySize);
	g_OldMapList = new ArrayList(arraySize);
	
	g_Cvar_ExcludeMaps = CreateConVar("sm_randomcycle_exclude", "5", "Specifies how many past maps to exclude from the vote.", _, true, 0.0);
	
	AutoExecConfig(true, "randomcycle");
}

public void OnConfigsExecuted()
{
	GetRandomGamemodeList(cSelectedMaplist, sizeof(cSelectedMaplist),
	cSelectedGamemode, sizeof(cSelectedGamemode));	

	if (ReadMapList(g_MapList, g_mapListSerial,
	cSelectedMaplist, MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER) == null)
	{
		if (g_mapListSerial == -1)
		{
			LogError("Unable to create a valid map list.");
		}
	}
	
	CreateTimer(5.0, Timer_RandomizeNextmap); // Small delay to give Nextmap time to complete OnMapStart()
}

public Action Timer_RandomizeNextmap(Handle timer)
{
	char map[PLATFORM_MAX_PATH];
	char resolvedMap[PLATFORM_MAX_PATH];

	bool oldMaps = false;
	if (g_Cvar_ExcludeMaps.IntValue && g_MapList.Length > g_Cvar_ExcludeMaps.IntValue)
	{
		oldMaps = true;
	}
	
	do
	{
		int b = GetRandomInt(0, g_MapList.Length - 1);
		//PrintToServer("Map number: %i", g_MapList.Length);
		g_MapList.GetString(b, map, sizeof(map));
		FindMap(map, resolvedMap, sizeof(resolvedMap));
	} while (oldMaps && g_OldMapList.FindString(resolvedMap) != -1);
	
	g_OldMapList.PushString(resolvedMap);
	SetNextMap(map);

	if (g_OldMapList.Length > g_Cvar_ExcludeMaps.IntValue)
	{
		g_OldMapList.Erase(0);
	}
	
	ServerCommand("jb_sv_gamemode %s", cSelectedGamemode);
	LogAction(-1, -1, "RandomCycle has chosen %s (gamemode: %s) for the nextmap.", map, cSelectedGamemode);	

	return Plugin_Stop;
}

public Handle CreatePositionsFile(Handle hFile)
{
	if (hFile == INVALID_HANDLE)
	{
		hFile = CreateKeyValues("randomcycle_maplists"); // Keyvalues

		char cData[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, cData, PLATFORM_MAX_PATH, "data/randomcycle_maplists.txt");

		FileToKeyValues(hFile, cData);
	}
	return hFile;
}

stock bool GetRandomGamemodeList(char[] cMaplist, int iMaxSize1, char[] cGamemode, int iMaxSize2)
{
	g_hKeyvaluesMapFile = CreatePositionsFile(g_hKeyvaluesMapFile);
	if (g_hKeyvaluesMapFile == INVALID_HANDLE) return false;

	int iNumberOfGamemodes, iRandomGamemode = 0;
	
	KvRewind(g_hKeyvaluesMapFile); // We go to the top node, woo.
	KvGotoFirstSubKey(g_hKeyvaluesMapFile, false); // We go to the first subkey (which should be a map name)
	
	// Get the number of gamemodes first before choosing a random list.
	do iNumberOfGamemodes++;
	while (KvGotoNextKey(g_hKeyvaluesMapFile, false));
	KvRewind(g_hKeyvaluesMapFile); // We go to the top node again.
	KvGotoFirstSubKey(g_hKeyvaluesMapFile, false); // We go to the first subkey (which should be a map name)
	//PrintToServer("Number of gamemodes: %i", iNumberOfGamemodes);
	
	if (iNumberOfGamemodes <= 0) return false;
	
	// Pick random gamemode.
	iRandomGamemode = GetRandomInt(0, iNumberOfGamemodes-1);
	
	// We go to the key where there's the gamemode we're picking.
	for (int i = 0; i <= iRandomGamemode; i++) KvGotoNextKey(g_hKeyvaluesMapFile, false);
	
	KvGetSectionName(g_hKeyvaluesMapFile, cGamemode, iMaxSize2);
	KvGetString(g_hKeyvaluesMapFile, "maplist", cMaplist, iMaxSize1, "jbep3_default");
	//PrintToServer("MapList: %s - Gamemode: %s", cMaplist, cGamemode);
	
	return true;
}