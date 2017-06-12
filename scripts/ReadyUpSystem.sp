#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Sonfloro"
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <string>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "CS:GO Ready Up System",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = "clamclan.org"
};

// Handles for ConVars
Handle g_ReadyUpStatus;
Handle g_StartReadyUp;
Handle g_PlayersAreReady;


// Both numbers that are displayed on the ready up bubble 
int numOfPlayers = 0;
int playersReady = 0;
/*
PlayerStatus holds two integer values. A client ID and either a 1 or 0 for true/false.
Allows for easy tracking of who has and hasn't readied up yet

Would like to use something like a Struct to hold a name aswell, but doing that in sourcepawn would be far more complicated than it needs to be.
*/
int PlayerStatus[10][2]; 


// TODO:
/*
	Setup functions to display and update the ready up status.  DONE
	
	User PrintHintTextToAll on a loop that waits until all are ready.  DONE
	
	Change PrintHintTextToAll to PrintHintText to display "You are ready" and "You are not ready" for specific clients. DONE
	
	Remember to add a bool for .ready and .unready so players can't .ready when the server isn't waiting for people to ready. DONE
*/



public void OnPluginStart()
{
	g_ReadyUpStatus = CreateConVar("sm_readyUpStatus", // ConVar name
							"0", // Default Value
							"Set to 1 if currently in a ReadyUp period", // Description
							FCVAR_REPLICATED, // Flags
							true, // Has a minimum
							0.0,
							true, // Has a maximum
							1.0);
	g_StartReadyUp = CreateConVar("sm_startReadyUp", 
								"0", 
								"Set value to 1 to start a warmup period", 
								FCVAR_REPLICATED, 
								true, 
								0.0,
								true, 
								1.0);
	g_PlayersAreReady = CreateConVar("sm_PlayersAreReady",
							"0",
							"Set to 1 when all plays have readied up",
							FCVAR_REPLICATED,
							true,
							0.0,
							true,
							1.0);
	HookConVarChange(g_StartReadyUp, OnStartReadyUpChange); // Create a callback declaration 
}


public void OnStartReadyUpChange(ConVar convar, char[] oldValue, char[] newValue) // Callback function gets called whenever the g_StartReadyup convar changes
{
	if (StringToInt(newValue) == 1)
	{
		SetConVarBool(g_StartReadyUp, false); // Set the value back to 0, callback will be called again but nothing will come of it
		
		SetConVarBool(g_ReadyUpStatus, true); // Set ReadUpStatus to true (1) to tell the server that there's a readyup in progress
		
		setAllUnready(); // Set all players to unready so PrintHintText will show up for everyone
		
		CreateTimer(1.0, readyTimer, _, TIMER_REPEAT); // Start displaying the ready up message
	}
}


void updateNumOfPlayers()
{
	numOfPlayers = 0;
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			numOfPlayers++;
		}
	}
}

void setAllUnready()
{
	int temp = 0; // Keep track of who we're on
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			PlayerStatus[temp][0] = i;
			PlayerStatus[temp][1] = 0;
			temp++;
		}
	}
}


// UpdatePlayerStatus checks if a client has already readied up already, if not it writes the players client ID and ready state.
int updatePlayerStatus(int client, int ready)
{
	for (int i = 0; i < 10; i++)
	{
		if (PlayerStatus[i][0] == client && (PlayerStatus[i][1] == 0 && ready == 1))
		{
			PlayerStatus[i][1] = ready; // Set client to ready if they've been recorded, set to not ready, and want to be readied.
			playersReady++;
			return 1; // Return 1 if client was readied.
		}
		if (PlayerStatus[i][0] == client && (PlayerStatus[i][1] == 1 && ready == 0))
		{
			PlayerStatus[i][1] = ready; // Set client to unready if they've been recorded, set to ready, and want to be unreadied.
			playersReady--;
			return 2; // Return 2 if client was unreadied.
		}
		if (PlayerStatus[i][0] == client && (PlayerStatus[i][1] == 1 && ready == 1))
		{
			return -1; // Return -1 if this client has already been recorded, readied, and current update is to ready them.
		}
		if (PlayerStatus[i][0] == client && (PlayerStatus[i][1] == 0 && ready == 0))
		{
			return -2; // Return -2 if this client has already been recorded, unreadied, and current update is to unready them. 
		}
	}
	return 0;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (GetConVarBool(g_ReadyUpStatus))
	{	
		char ready[] = ".ready";
		char unReady[] = ".unReady";
		
		
		if (strcmp(sArgs[0], ready, false) == 0)
		{
			int update = updatePlayerStatus(client, 1);
			if (update == -1)
			{
				PrintToChat(client, "Error, you are already ready");	
			}
			if (update == 1)
			{
				char temp[MAX_NAME_LENGTH];
				GetClientName(client, temp, sizeof(temp));
				PrintToChatAll("\x01[\x07ClamClan\x01]  %s is now ready.", temp);
			}
		}
		if (strcmp(sArgs[0], unReady, false) == 0)
		{
			int update = updatePlayerStatus(client, 0);
			if (update == 2)
			{
				char temp[MAX_NAME_LENGTH];
				GetClientName(client, temp, sizeof(temp));
				PrintToChatAll("\x01[\x07ClamClan\x01]  %s is not ready.", temp);
			}
			if (update == -2)
			{
				PrintToChat(client, "Error. You haven't readied up yet");
			}
		}
	}
}


public Action readyTimer(Handle timer, any user)
{
	updateNumOfPlayers();
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			for (int j = 0; j < 10; j++)
			{
				if (PlayerStatus[j][0] == i) 
				{
					if (PlayerStatus[j][1]) // Check if player has readied up.
					{
						PrintHintText(i, "Waiting for players to ready...\n" 
												... "%d / %d players ready\n"
												... "You are <font color='#00ff00'>READY</font>", playersReady, numOfPlayers);	
					}
					if (!PlayerStatus[j][1]) // Check if player has not readied up
					{
						PrintHintText(i, "Waiting for players to ready...\n" 
												... "%d / %d players ready\n"
												... "You are <font color='#ff0000'>NOT READY</font>", playersReady, numOfPlayers);
					}
				}
			}
		}
	}
	if (playersReady == 10)
	{
		PrintToChatAll("\x01[\x07ClamClan\x01]  All players have now readied up. ");
		playersReady = 0;
		numOfPlayers = 0;
		SetConVarBool(g_ReadyUpStatus, false);
		SetConVarBool(g_PlayersAreReady, true);
		KillTimer(timer, false);
	}
	else if (GetConVarBool(g_ReadyUpStatus) == false)
	{
		playersReady = 0;
		numOfPlayers = 0;
		SetConVarBool(g_PlayersAreReady, false);
		KillTimer(timer, false);
	}
	return Plugin_Continue;
}