/*
    CLANLIB - Collection of utilities for collecting, examining, and saving stats of clan members

Record type: clannie
    Fields: 
        int id: ID number of player
        string name: Name of player
        boolean is_active: True if and only if player is not "inactive" in roster
        string rank: Player's clan rank
        string title: Player's clan title
        string player_class: Class of player
        int muscle: Player's Muscle at the time of stat collection
        int mysticality: Player's Muscle at the time of stat collection
        int moxie: Player's Muscle at the time of stat collection
        int ascensions: Number of player's completed ascensions, including hardcore
        int hardcore_ascensions: Number of player's hardcore ascensions
        int pvp: Number of player's PvP fights available
        int karma: Player's clan karma
        string restriction: "ronin", "hardcore", or ""
        int created: Date player's account was created, in the form YYYYMMDD
        int last_login: Date player last logged in, in the form YYYYMMDD

Record type: distribution
    Fields:
        string giver: Name of the player distributing loot
        string loot: Name of the loot distributed
        string receiver: Name of the player receiving loot

Record type: dungeon_run
    Fields:
        int id: ID of the dungeon run
        int start_date: Date the dungeon was opened, in the form YYYYMMDD
        int end_date: Date the dungeon was closed, in the form YYYYMMDD
        int dungeon: 0 = Hobopolis, 1 = Slime, 2 = Sorority, 3 = Dread
        int turns: Number of turns spent in the dungeon (or number of kisses, for Dread)
        distribution[int] distribs: Array of individual loot distributions

Constants:  
    DEFAULT_SAVE_FILE: File to which clannie records are saved by default
    DEPTH_ACTIVE_ONLY: Use to indicate only account details of active players needed
    DEPTH_ALL: Use to indicate account details of all players needed
    DEPTH_NONE: Use to indicate only clan stats of players needed
    
Functions:
    clannie[int] load_clannies(int depth)
        Retrieve clannie information from KoL and return as an array indexed by player ID.
        Index 0 of the array contains a special record recording the date the array was
        constructed.
    clannie[int] load_clannies_from_disk(string pathname)
        Retrieve clannie information from the given pathname (or DEFAULT_SAVE_FILE if
        pathname not supplied) and return as an array indexed by player ID
    void save_clannies(clannie[int] clannies, string pathname)
        Save the clannie information in clannies to the given pathname (or DEFAULT_SAVE_FILE
        if pathname not supplied) 
    void load_raidlogs(dungeon_run[int] raidlogs)
        Load raid logs from the clan records into the given raidlog array.
    dungeon_run[int] load_raidlogs() 
        Load raid logs from the clan records into a new raidlog array and return it.
    string[int] players_loot(dungeon_run[int] raidlogs, string player)
        Return a list of all loot received by the named player according to the given raidlog array.
*/

notify "Aventuristo";

// Clannie record, with information from roster, detailed roster, and individual player pages
record clannie {
    // These fields are read from the clan logs, and are set by all depths
    int id;
    string name;
    boolean is_active;
    string rank;
    string title;
    string player_class;
    int muscle;
    int mysticality;
    int moxie;
    int ascensions;     # INCLUDES hardcore
    int hardcore_ascensions;
    int pvp;
    int karma;
    // These fields are set from the individual clannie's page, but only if depth is ALL, 
    // or if the depth is ACTIVE_ONLY and the clannie is active
    string restriction;
    int created;
    int last_login;
};

// Months of the year
int[string] MONTHS = { "January": 1, "February": 2, "March": 3, "April": 4,
                       "May": 5, "June": 6, "July": 7, "August": 8,
                       "September": 9, "October": 10, "November": 11, "December": 12 };

string DEFAULT_SAVE_FILE = "clannies.txt";


int parse_date(string d)
{
    matcher m = create_matcher("(.*) ([0-9]*), ([0-9]*)", d);
    find(m);
    return (to_int(group(m, 3)) * 10000 + MONTHS[group(m, 1)] * 100 + to_int(group(m, 2)));
}

/*
    load_clannies() - Get information on clannies from Kingdom of Loathing - involves two or 
        more server hits
    Arguments: depth - int from 0 to 2 designating whether to get info from player pages
*/
int DEPTH_NONE = 0;
int DEPTH_ACTIVE_ONLY = 1;
int DEPTH_ALL = 2;
clannie[int] load_clannies(int depth)
{
    clannie[int] clannies;
    // ---- Add "header" to record when list created ----
    clannie header;
    header.name = "   Date created   ";
    header.created = to_int(today_to_string());
    clannies[0] = header;
    
    // ---- Parse the clan roster ----
    int page = 1;
    print("Parsing clan roster...", "blue");
    while (page < 99999) {
        buffer buf = visit_url("clan_members.php?begin=" + page);
        matcher m = create_matcher('who=([0-9]*)">([^<]*)</a>(.*?)</td><td>(.*?)</td><td>(.*?)</td></tr>', buf);
        int clannies_found = 0;
        while (find(m)) {
            clannies_found = clannies_found + 1;
            clannie c;
            c.id = to_int(group(m, 1));
            c.name = group(m, 2);
            c.is_active = !(index_of(group(m, 3), "inactive") > 0);
            string rank = group(m, 4);
            if (index_of(rank, 'selected>') > 0) {
                matcher mt = create_matcher('selected>([^(]*) +[(]', rank);
                find(mt);
                rank = group(mt, 1);
            }
            c.rank = rank;
            string title = group(m, 5);
            if (index_of(title, 'value=') > 0) {
                matcher mt = create_matcher('value="([^"]*)"', title);
                find(mt);
                title = group(mt, 1);
            }
            c.title = title;
            clannies[c.id] = c;
        }
        if (clannies_found < 1)
            page = 1000000; // If no clannies found on this page, exit loop
        else 
            page = page + 1;
    }
    
    // ---- Parse the detailed clan roster ----    
    print("Parsing detailed roster...", "blue");
    buffer buf = visit_url("clan_detailedroster.php");
    matcher m = create_matcher('who=([0-9]*).*?<td[^>]*>([^<]*)</td>'
                               + '<td[^>]*>([^<]*)</td><td[^>]*>([^<]*)</td><td[^>]*>([^<]*)</td>'
                               + '<td[^>]*>([^<]*)</td><td[^>]*>([^<]*)</td><td[^>]*>([^<]*)</td>'
                               + '<td[^>]*>([^<]*)</td><td[^>]*>([^<]*)</td><td[^>]*>([^<]*)</td>', buf);
    while (find(m)) {
        int id = to_int(group(m, 1));
        if (clannies contains id) {
            clannie c = clannies[id];
            c.player_class =        group(m, 2);
            c.muscle =              to_int(group(m, 3));
            c.mysticality =         to_int(group(m, 4));
            c.moxie =               to_int(group(m, 5));
            c.hardcore_ascensions = to_int(group(m, 8));
            c.ascensions =          to_int(group(m, 7)) + c.hardcore_ascensions;
            c.pvp =                 to_int(group(m, 9));
            c.karma =               to_int(group(m, 11));
        }
    }
    
    // ---- Parse individual player pages if needed ----
    if (depth != DEPTH_NONE) {
        print("Parsing individual clannie pages...", "blue");
        foreach id, c in clannies {
            if (id == 0)  continue;     // skip header
            if ((depth == DEPTH_ALL) || (c.is_active)) {
                //print(id, "olive");
                buf = visit_url("showplayer.php?who=" + id);
                if (index_of(buf, "<b>(Hardcore)</b>") > 0)
                    c.restriction = "hardcore";
                else if (index_of(buf, "<b>(In Ronin)</b>") > 0)
                    c.restriction = "ronin";
                else if (index_of(buf, "Astral Spirit") > 0) 
                    c.restriction = "astral";
                else
                    c.restriction = "";
                // <tr><td align=right><b>Account Created:</b></td><td>August 24, 2017</td></tr>
                // <tr><td align=right><b>Last Login:</b></td><td>December 01, 2018</td></tr>
                matcher m = create_matcher("Account Created:[^,]*<td>([^<]*)</td>.*"
                                           + "Last Login:[^,]*<td>([^<]*)</td>", buf);
                if (find(m)) {
                    // If not found, may be on astral plane - no info available
                    c.created = parse_date(group(m, 1));
                    c.last_login = parse_date(group(m, 2));
                }
            }
        }
    }
    
    return clannies;
}


/*
    Save clannies table to disk.  The pathname is relative to KoLmafia's data directory.
*/
void save_clannies(clannie[int] clannies, string pathname)
{
    map_to_file(clannies, pathname);
}

void save_clannies(clannie[int] clannies)
{
    save_clannies(clannies, DEFAULT_SAVE_FILE);
}


/*
    Load clannies table from disk.  The pathname is relative to KoLmafia's data directory.
*/
clannie[int] load_clannies_from_disk(string pathname)
{
    clannie[int] clannies;
    file_to_map(pathname, clannies);
    return clannies;
}

clannie[int] load_clannies_from_disk()
{
    return load_clannies_from_disk(DEFAULT_SAVE_FILE);
}


// Record of a loot distribution event from a clan dungeon run
record distribution {
    string giver;
    string loot;
    string receiver;
};

// Record of a clan basement dungeon run
record dungeon_run {
    int id;
    int start_date;
    int end_date;
    int dungeon;    // 0 = Hobopolis, 1 = Slime, 2 = Sorority, 3 = Dread
    int turns;
    distribution[int] distribs;
};

/*
    Given an array of raidlogs (which doesn't have to be empty), processes the clan's raidlogs
    and stores into the array the raids that the array does not already have.  This is usable 
    because old raidlogs will not change, so processed versions can be retained, unlike the
    clannie information, which varies over time.
*/
void load_raidlogs(dungeon_run[int] raidlogs)
{
    buffer buf = visit_url("clan_oldraidlogs.php");
    matcher m = create_matcher("Showing [0-9-]* of ([0-9]*)", buf);
    if (! find(m)) {
        print("Run count not found", "red");
        return;
    }
    int runs = group(m, 1).to_int();
    print("Loading " + (runs - raidlogs.count()) + " raids into raidlogs array...", "blue");
    int which = runs;
    while (which > 0) {
        string td  = "<td[^>]*>([^<]*)</td>";
        string tdn = "<td[^>]*>([0-9,]*)[^<]*</td>";
        string tdl = '<td[^>]*>.<a href="[^=]*=([0-9]*)[^"]*">view logs</a>.</td>';
        matcher m = create_matcher("<tr>" + td + td + td + tdn + tdl + "</tr>", buf);
        while (find(m)) {
            if (raidlogs contains which) {
                which = 0;
                break;
            }
            //print("Adding raid #" + which);
            dungeon_run run;
            run.id = to_int(group(m, 5));
            run.start_date = parse_date(group(m, 1));
            run.end_date = parse_date(group(m, 2));
            run.turns = to_int(group(m, 4));
            switch (substring(group(m, 3), 0, 5)) {
            case "Hobop": run.dungeon = 0; break;
            case "The S": run.dungeon = 1; break;
            case "The H": run.dungeon = 2; break;
            case "Dread": run.dungeon = 3; break;
            default: run.dungeon = -1; break;
            }
            // Get individual run stats
            buffer rbuf = visit_url("clan_viewraidlog.php?viewlog=" + run.id + "&backstart=0");
            matcher rm 
                = create_matcher(">([^>(]*) .#[0-9]*. distributed <b>([^<]*)</b> to ([^(]*) .#[0-9]*.",
                                 rbuf);
            int i = 0;
            while (find(rm)) {
                distribution dist;
                dist.giver = group(rm, 1);
                dist.loot = group(rm, 2);
                dist.receiver = group(rm, 3);
                run.distribs[i] = dist;
                i = i+1;
            }
            raidlogs[which] = run;
            which = which - 1;
        }
        if (which > 0) 
            buf = visit_url("clan_oldraidlogs.php?startrow=" + to_string(runs - which));
    }
    print("Raid logs updated from clan records", "blue");
    return;
}

/*
    Process the clan raidlogs into an entirely new raidlog object, and return it.
*/
dungeon_run[int] load_raidlogs() 
{
    dungeon_run[int] result;
    load_raidlogs(result);
    return result;
}

/*
    Return an alphabetized array of the loot that the given player has received according to the 
    given raidlogs.
*/
string[int] players_loot(dungeon_run[int] raidlogs, string player)
{
    string[int] result;
    int i = 0;
    string p = to_lower_case(player);
    foreach n, drun in raidlogs {
        foreach n, dist in drun.distribs {
            if (to_lower_case(dist.receiver) == p) {
                result[i] = dist.loot;
                i = i+1;
            }
        }
    }
    sort result by to_lower_case(value);
    return result;
}


/*
main() only for testing
*/
void main()
{
    dungeon_run[int] runs;
    //file_to_map("tmp/partruns", runs);
    load_raidlogs(runs);
    map_to_file(runs, "tmp/runs");
    
    print("");
    print("Aventuristo has received:");
    foreach j, it in players_loot(runs, "aventuristo") {
        print(it);
    }
    print("");
    clannie[int] clannies = load_clannies(DEPTH_ACTIVE_ONLY);
    sort clannies by to_lower_case(value.name);
    foreach id, c in clannies {
        if (! c.is_active)  continue;
        print(c.name + " (#" + c.id + ") " + c.rank + ", last login " + c.last_login);
    }
    print("Done.");
    print('');
}
