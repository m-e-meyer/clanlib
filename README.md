# clanlib
KoLmafia utility library for processing information about one's clan

## Record types

    cl_clannie
    
Represents a player who is a clanmate.

    cl_player
    
    distribution
    
    dungeon_run
    
## Procedures
    
    cl_player[int] clan_members(int clanid)
    
    void get_clan_activity(string[string][int][string][string][int] activity,
                           int[int][string][item] stash_activity)

    cl_clannie[int] get_clannies()
    
    boolean is_active(cl_player p)
    
    boolean join_clan(string name)
    
    dungeon_run[int] load_raidlogs() 
    
    cl_name_id lookup_clan_id(string name)
    
    string[string] players_loot(dungeon_run[int] raidlogs, string player)
    
    string stash_activity_file_name()
    
    string stash_file_name()
