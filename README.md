# clanlib
KoLmafia utility library for processing information about one's clan

## Record types

### `cl_clannie`
    
Represents a player-character who is a clanmate.  There are two kinds of fields: Those obtainable from the clan roster, and those obtainable from the detailed clan member stats.

#### Clan roster

* `int id`: Character's numeric ID
* `boolean is_active`: Whether the character has logged in in the last 40 days
* `string name`: Character's name
* `string rank`: Character's clan rank
* `string title`: Character's clan title

#### Detailed member stats

* `int ascensions`: Number of character's ascensions completed, including Hardcore
* `int hardcore_ascensions`: Number of character's Hardcore ascensions completed
* `int karma`: Clan karma accumulated by character
* `int moxie`: Character's current base Moxie
* `int muscle`: Character's current base Muscle
* `int mysticality`: Character's current base Mysticality
* `string player_class`: Character's current class
* `int pvp`: Character's PvP wins in current season?

### `cl_name_id`

Simple pairing of a clan name with its clan ID number.  The fields are:

* `int id`: ID number of the clan
* `string name`: Name of the clan

### `cl_player`
    
Represents a player-character.  There are two kinds of fields: Those obtainable from Clan recruiter roster displays, and those obtainable from the character's public page.

#### Clan Recruiter roster

* `int id`: Numberic id of character
* `boolean is_hardcore`: Whether the character is in a Hardcore run
* `boolean is_ronin`: Whther the character is under Ronin restrictions
* `int level`: Character's level
* `string name`: Character's name
* `string title`: Character's clan title

#### Public character page

* `int ascensions`: Number of ascensions 
* `int created`: Date the player-character was created, in number of seconds since midnight, Jan 1, 1970
* `int familiars`: Number of familiars acquired
* `int last_login`: Date the player-character last logged in, in number of seconds since midnight, Jan 1, 1970
* `int tattoos`: Number of tattoos acquired
* `int trophies`: Number of trophies acquired
* `int turns_run`: Number of turns played in current ascension
* `int turns_total`: Number of turns played over all ascensions

### `distribution`

Represents a loot distribution event.  Has the following fields:
* `string giver`: Name of the character that distributed the loot
* `string loot`: Name of the piece of loot distributed
* `string receiver`: Name of the character that received the loot

### `dungeon_run`

Represents a completed dungeon run.  Has the following fields:

* `distribution[int] distribs`: Map of loot distributions for that run.  Keys are 0, 1, 2, ...
* `int dungeon`: Code identifying the dungeon.  0 = Hobopolis, 1 = Slime Tube, 2 = Haunted Sorority, 3 = Dreadsylvania.
* `int end_date`: Date the run was ended, in number of seconds since midnight, Jan 1, 1970
* `int id`: Numeric identifier for the dungeon run
* `int start_date`: Date the run was started, in number of seconds since midnight, Jan 1, 1970
* `int turns`: Number of adventures taken to finish the dungeon

## Procedures
    
    string activity_file_name()

Returns the name of the data file in which activity data for the current clan is stored.

    cl_player[int] clan_members(int clanid)
    
Returns a map of the members of the clan with the given clan ID, indexed by 0, 1, 2, ...
    
    void get_clan_activity(string[string][int][string][string][int] activity,
                           int[int][string][item] stash_activity)

Reads data from the clan activity data files into the two given maps (see `activity_file_name()` and `stash_activity_file_name()`), adds data to the maps from the Clan Activity Log of the current clan, and writes the updated data into the clan activity data files.  The data are left in the maps for use after `get_clan_activity()` completes.

The keys to the activity map are, in order:

* `string` denoting the type of activity: `"basement"` for basement activity, `"inout"` for entering and leaving the clan, `"lounge"` for VIP lounge activity, and `"misc"` for miscellaneous activity.
* `int` denoting the time of the activity, expressed as a human-readable timestamp.  For example, `202105011645` is May 1, 2021, at 4:45 PM
* `string` giving the name of the player-character that did something
* `string` code for what the player-character did: 
  * `"basement"` activity has `"closed"` for closing a dungeon, `"meat"` for recovering meat from a dungeon, and `"opened"` for opening a dungeon
  * `"inout"` activity has `"admitted"` for admitting a new member, `"otherclan"` for joining another clan, and`"rejoined"` for rejoining the current clan
  * `"lounge"` activity has `"ate"` for eating from the Hot Dog Stand and `"fabricated"` for fabricating something in the Floundry
  * `"misc"` activity has `"applied"` for applying for clan membership, `"chgrank"` for changing a clan member's rank, `"chgtitle"` for changing a clan member's title, `"modrank"` for modifying a clan rank, `"posted"` for posting an announcement, and `"xfrlead"` for transferring leadership
* `int` is a serial number 

And the value of the map is a string denoting the object of the activity, or `-` if there is no object.

Note: Activity by CheeseFax and Easyfax are not included.

The keys to the stash activity map are, in order:

* `int` denoting the time of the activity, expressed as a human-readable timestamp.  For example, `202105011645` is May 1, 2021, at 4:45 PM
* `string` giving the name of the player-character that moved things into or out of the stash
* `item` denoting what item was moved.  If `$item[none]`, then the player contributed meat. 

And the value of the map is a number denoting how many of the item was moved, or how much meat was contributed.  If positive, items were added to the stash; if negative, items were taken from the stash.

    cl_clannie[int] get_clannies()

Returns a map of all the members of the current clan, indexed by the characters' ID numbers.
    
    boolean is_active(cl_player p)

Returns `true` if and only if the given player-character has logged in within the last 40 days.
    
    boolean join_clan(string name)

Join the clan (to which you should be whitelisted) with the given name (case-insensitive).  Returns `false` if the attempt to join failed.
    
    void load_raidlogs(dungeon_run[int] raidlogs) 
    
Populates the given map `raidlogs` with the logs of the current clan's basement runs.  Keys for the map are numbered 1, 2, 3, ..., starting with the oldest run.

    dungeon_run[int] load_raidlogs() 
    
Similar to the previous procedure, but returns the raid logs in a new map.
    
    cl_name_id lookup_clan_id(string name)

Returns a clan name/clan ID number pair for the clan with the given name (case-insensitive).
    
    string[string] players_loot(dungeon_run[int] raidlogs, string player)
    
Given a map of basement raid logs and the name of a player-character, returns a map of the loot received by the character.  The keys of the map are strings of the form `"yyyy-MM-dd n"`, where `yyyy-MM-dd` is a date like `2021-05-01` and `n` is a serial number, in case the character receives multiple pieces of loot in the same day.

    string stash_activity_file_name()

Returns the name of the data file in which stash activity data for the current clan is stored.
