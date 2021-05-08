/*
    CLANLIB - Collection of utilities for collecting, examining, and saving stats of clan members
    
*/

//since r19904;    // template string support
since r20474;    // time support


// Simple name-id pair
record cl_name_id {
    string name;
    int id;
};

// Record of a player
record cl_player {
    // Obtainable from Clan Recruiter displays
    int id;
    string name;
    string title;
    int level;
    boolean is_hardcore;
    boolean is_ronin;
    // Obtainable from public user page
    int ascensions;
    int turns_total;
    int turns_run;
    int tattoos;
    int trophies;
    int familiars;
    int created;    // timestamp
    int last_login; // timestamp
};

string to_string(cl_player p)
{
    return "[player " + p.id + " " + p.name + " " 
           + (p.is_ronin ? "RONIN " : "") + (p.is_hardcore ? "HARDCORE " : "")
           + p.ascensions + " " + p.turns_total + " " + p.turns_run + " (" 
           + p.tattoos + "+" + p.trophies + "+" + p.familiars + "="
           + (p.tattoos + p.trophies + p.familiars) + ") "
           + timestamp_to_date(p.created*1000, "MMMM dd, yyyy") + " " 
           + timestamp_to_date(p.last_login*1000, "MMMM dd, yyyy") + "]";
}


// Record of a clanmate
record cl_clannie {
    // Obtainable from Clan Roster
    int id;
    string name;
    string rank;
    string title;
    boolean is_active;
    // Obtainable from detailed member stats
    string player_class;
    int muscle;
    int mysticality;
    int moxie;
    int ascensions;     # INCLUDES hardcore
    int hardcore_ascensions;
    int pvp;
    int karma;    
};

string to_string(cl_clannie c)
{
    string active = "";
    if (! c.is_active) 
        active = " INACTIVE";
    return `[clannie {c.id} {c.name}{active} ({c.rank}) ({c.title}) {c.player_class} ({c.muscle},{c.mysticality},{c.moxie}) {c.ascensions}({c.hardcore_ascensions}) {c.pvp} {c.karma}]` ;
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


string rstrip(string s)
{
    int i = s.length() - 1;
    while ((i >= 0) && (substring(s, i, i+1) <= " ")) {
        i = i - 1;
    }
    return substring(s, 0, i+1);
}


/*
    Join the named clan, if not already in that clan.  Returns false if the attempt to join failed. 
*/
boolean join_clan(string name)
{
    string my_clan = get_clan_name();
    name = to_lower_case(name);
    if (to_lower_case(my_clan) == name) {
        return true;
    }
    buffer clansignup = visit_url("clan_signup.php");
    matcher wlmatcher = create_matcher("Whitelist List: .*whitelisted", clansignup);
    if (! find(wlmatcher)) {
        print("Whitelist list not found", "red");
        return false;
    }
    string wls = group(wlmatcher, 0);
    #print(wls);
    matcher clanmatcher = create_matcher("option value\=([0-9]*)>([^<]*)</option", wls);
    string clanid = "";
    string[string] whitelists;
    while (find(clanmatcher)) {
        string id = group(clanmatcher, 1);
        string clan = group(clanmatcher, 2);
        whitelists[clan] = clanid;
        if (name == to_lower_case(clan)) {
            clanid = id;
            break;
        }
    }
    if (clanid == "") {
        print(`Clan {name} not found.`, "red");
        print("You are whitelisted in:", "red");
        foreach clan, clanid in whitelists {
            print("* " + clan, "red");
        }
        return false;
    }
    buffer showclan = visit_url("showclan.php?recruiter=1&whichclan=" + clanid);
    buffer showclan2 = visit_url("showclan.php?action=joinclan&whichclan=" + clanid 
                                             + "&confirm=1");
    return true;    
}

/*
Get name and ID of a clan, given the clan's name (case-insensitive)
*/
cl_name_id lookup_clan_id(string name)
{
    cl_name_id result;
    buffer html = visit_url("clan_signup.php?whichfield=1&searchstring=" 
                            + name + "&action=search");
    matcher m = create_matcher("<a href=.showclan.php.recruiter=1&whichclan=([0-9]*).>([^<]*)</a>", html);
    string lcname = to_lower_case(name);
    while (find(m)) {
        if (to_lower_case(group(m, 2)) == lcname) {
            result.name = group(m, 2);
            result.id = to_int(group(m, 1));
            break;
        }
    }
    return result;
}


/*
Retrieve list of members of a clan by going to the Clan Recruiter and getting a list of members.
Data available this way: name, id, title, level, hardcore, ronin
*/
cl_player[int] clan_members(int clanid)
{
    cl_player[int] result;
    buffer chtml = visit_url("showclan.php?recruiter=1&whichclan=" + clanid);
    matcher m = create_matcher("bgcolor=blue><b>([^<]*)</b>", chtml);
    if (! find(m)) {
        print("No clan with ID " + clanid);
        return result;
    }
    string clan_name = group(m, 1);
    while (true) {
        matcher m = create_matcher('nounder href=.showplayer.php[?]who=([0-9]*)">([^<]*)</a></b>&nbsp;</td><td class=small>([^<]*)</td><td class=small>([0-9]*)( [(][HR][)])?<', chtml);
        while (find(m)) {
            cl_player p;
            p.id = to_int(group(m, 1));
            p.name = group(m, 2);
            p.title = to_string(replace_string(group(m, 3), '&nbsp;', ''));
            p.level = to_int(group(m, 4));
            string note = group(m, 5);
            p.is_ronin = (note == ' (R)');
            p.is_hardcore = (note == ' (H)');
            result[count(result)] = p;
        }
        if (count(result) > 150)
            break;
        m = create_matcher('(showclan.php[^"]*)">next page', chtml);
        if (! find(m))
            break;
        chtml.set_length(0);
        chtml = visit_url(group(m, 1), false);  // must be false or I get the same thing over & over
    }
    print(`{count(result)} players found.`);
    return result;
}

string get_datum(buffer html, string qual)
{
    matcher m = create_matcher(qual + ":<.b><.td><td>([^<]*)", html);
    if (! find(m))  return "";
    return group(m, 1);
}

int count_familiars(int id)
{
    int result = 0;
    buffer phtml = visit_url("showfamiliars.php?who=" + to_string(id));
    matcher m = create_matcher("does not currently have a familiar", phtml);
    if (! find(m))
        result++;
    m = create_matcher("contains the following creatures.*<a href..showplayer", phtml);
    if (! find(m))
        return 0;
    string tbl = group(m, 0);
    m = create_matcher("<tr>", tbl);
    while (find(m))  result++;
    return result;
}

void load_player_page_info(cl_player p)
{
    buffer phtml = visit_url("showplayer.php?who=" + to_string(p.id));
    string d = get_datum(phtml, "Ascensions<.a>");
    if (d != "") {
        // ascensions
        p.ascensions = to_int(d);
        d = get_datum(phtml, "Turns Played .total.");
        if (d != "")  p.turns_total = to_int(d);
        d = get_datum(phtml, "Turns Played .this run.");       
        if (d != "")  p.turns_run = to_int(d);
    } else {
        // no ascensions
        d = get_datum(phtml, "Turns Played");
        if (d != "") {
            int t = to_int(d);
            p.turns_total = t;
            p.turns_run = t;
        }
    }
    d = get_datum(phtml, "Trophies Collected");       
    if (d != "")  p.trophies = to_int(d);
    d = get_datum(phtml, "Tattoos Collected");       
    if (d != "")  p.tattoos = to_int(d);
    p.familiars = count_familiars(p.id);
    d = get_datum(phtml, "Account Created");
    if (d != "")  p.created = date_to_timestamp("MMMM dd, yyyy", d)/1000;
    d = get_datum(phtml, "Last Login");
    if (d != "")  p.last_login = date_to_timestamp("MMMM dd, yyyy", d)/1000;
}

boolean is_active(cl_player p)
{
    int forty_days_ago = (now_to_int()/1000) - (40*86400);
    return (p.last_login > forty_days_ago);
}

/*
Return array of members of your current clan, indexed by the player's id.
*/
cl_clannie[int] get_clannies()
{
    cl_clannie[int] clannies;
    // ---- Add "header" to record when list created ----
    //cl_clannie header;
    //header.name = "   Date created   ";
    //header.created = to_int(today_to_string());
    //clannies[0] = header;
    
    // ---- Parse the clan roster ----
    int page = 1;
    print("Parsing clan roster...", "blue");
    while (page < 99999) {
        buffer buf = visit_url("clan_members.php?begin=" + page);
        matcher m = create_matcher('who=([0-9]*)">([^<]*)</a>(.*?)</td><td>(.*?)</td><td>(.*?)</td></tr>', buf);
        int clannies_found = 0;
        while (find(m)) {
            clannies_found = clannies_found + 1;
            cl_clannie c;
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
            cl_clannie c = clannies[id];
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
    /*
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
    */
    return clannies;
}

// ============================================================

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
            run.start_date = date_to_timestamp("MMMM dd, yyyy", group(m, 1))/1000;
            run.end_date = date_to_timestamp("MMMM dd, yyyy", group(m, 2))/1000;
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
string[string] players_loot(dungeon_run[int] raidlogs, string player)
{
    string[string] result;
    int i = 0;
    string p = to_lower_case(player);
    foreach n, drun in raidlogs {
        foreach n, dist in drun.distribs {
            if (to_lower_case(dist.receiver) == p) {
                string dt = timestamp_to_date(drun.start_date*1000, "yyyy-MM-dd");
                result[dt + " " + to_string(i)] = dist.loot;
                i = i+1;
            }
        }
    }
    return result;
}

// ==============================================================

// Is this a faxbot?
boolean is_faxbot(string player_and_id)
{
    return (player_and_id == "CheeseFax"
            || player_and_id == "Easyfax");
}

// Get name of activity log file
string activity_file_name()
{
    return get_clan_name().replace_string(' ', '_') + "_activty.txt";
}

// Get name of stash activity log file
string stash_activity_file_name()
{
    return get_clan_name().replace_string(' ', '_') + "_stash.txt";
}

// Convert MM/dd/yy, hh:mma to human-readable int
int clan_date_to_int(string yymmdd)
{
    int ts = date_to_timestamp("MM/dd/yy, hh:mma", yymmdd);
    //print(ts);
    string result = timestamp_to_date(ts, "yyMMddHHmm");
    return to_int(result);
}

// Add element to array
void add(string[string][int][string][string][int] activity,
         string category, int when, string who, string what, string whom)
{
    activity[category][when][who][what][count(activity[category][when][who][what])] = whom;
}

void add(string[string][int][string][string][int] activity,
         string category, int when, string who, string what)
{
    activity[category][when][who][what][count(activity[category][when][who][what])] = '-';
}

void add(int[int][string][item] stash_activity,
         int when, string who, item it, int quantity)
{
    stash_activity[when][who][it] = stash_activity[when][who][it] + quantity;
}

int count(string[string][int][string][string][int] activity)
{
    int n = 0;
    foreach a, b, c, d, e in activity {
        n = n + 1;
    }
    return n; 
}

int count(int[int][string][item] stash_activity)
{
    int n = 0;
    foreach a, b, c, d in stash_activity {
        n = n + 1;
    }
    return n; 
}

// Try to read the entire activity log in one go
void add_clan_activity_from_kol(string[string][int][string][string][int] activity,
                                int[int][string][item] stash_activity)
{
    string DTREG = "([0-9][0-9]/[0-9][0-9]/[0-9][0-9], [0-9]*:[0-9]*[APM]*): ";
    string PLREG = "([^(]*?) [(][^)]*[)].";

    // What is the latest date already in the arrays?  We'll add nothing at that time or earlier
    int only_after = 0;
    int stash_only_after = 0;
    foreach cat, when, x in activity {
        if (when > only_after) {
            only_after = when;
        }
    }
    foreach when, x in stash_activity {
        if (when > stash_only_after) {
            stash_only_after = when;
        }
    }
    
    buffer log_buf = visit_url("clan_log.php");
    // Replace every <br> and </b> with a special line break character
    string buf = log_buf.replace_string("<br>", "\001");
    buf = buf.replace_string("</b>", "\001");
    // Replace <b> with special section beginning marker
    buf = buf.replace_string("<b>", "\002");
    // Replace hyperlinks with plain text
    buffer b;
    matcher anchor = create_matcher("<[/]?a[^>]*>", buf);
    while (anchor.find()) {
        anchor.append_replacement(b, "");
    }
    anchor.append_tail(b);
    buf = b.to_string();
    // Process activity log by sections
    matcher section_match = create_matcher("\002([^\001]*)[\001]([^\002]*)", buf);
    while (section_match.find()) {
        string section = group(section_match, 1);
        string section_body = group(section_match, 2);
        switch (section) {
        case "Clan Activity Log:":
            string cal_pattern = DTREG + PLREG + "((faxed in a ([^\001]*))|(added "
                + PLREG + "to the clan's whitelist)|([^\001]*))";
            matcher cal_match = create_matcher(cal_pattern, section_body);
            while (find(cal_match)) {
                int when = clan_date_to_int(group(cal_match, 1));
                if (when <= only_after)
                    continue;
                string who = (group(cal_match, 2));
                if (who.is_faxbot()) { 
                    // Don't care about faxbots
                    continue;
                }
                if (group(cal_match, 4) != "") {
                    activity.add('gen', when, who, 'faxed', group(cal_match, 5));
                } else if (group(cal_match, 6) != "") {
                    activity.add('gen', when, who, 'whitelisted', group(cal_match, 7));
                } else {
                    print(`Unrecognized line: {group(cal_match, 8)}`, "red");
                    activity.add('gen', when, who, '?', group(cal_match, 8));
                }
            }
            break;
        case "Comings and Goings:":
            string cag_pattern = DTREG + PLREG + "((joined another clan)"
                + "|(was accepted into the clan .whitelist.)"
                + "|(accepted " + PLREG + "into the clan)"
                + "|(left the clan)"
                + "|([^\001]*))";
            matcher cag_match = create_matcher(cag_pattern, section_body);
            while (find(cag_match)) {
                int when = clan_date_to_int(group(cag_match, 1));
                if (when <= only_after)
                    continue;
                string who = (group(cag_match, 2));
                if (who.is_faxbot()) { 
                    // Don't care about faxbots
                    continue;
                }
                if (group(cag_match, 4) != "") {
                    activity.add('inout', when, who, 'otherclan');
                } else if (group(cag_match, 5) != "") {
                    activity.add('inout', when, who, 'rejoined');
                } else if (group(cag_match, 6) != "") {
                    activity.add('inout', when, who, 'admitted', group(cag_match, 7));
                } else if (group(cag_match, 8) != "") {
                    activity.add('inout', when, who, 'left');
                } else {
                    print(`Unrecognized line: {group(cag_match, 9)}`, "red");
                    activity.add('inout', when, who, '?', group(cag_match, 9));
                }
            }
            break;
        case "Stash Activity:":
            // Make table mapping plurals to singulars
            string[string] singular;
            foreach i in $items[] {
                singular[i.plural.to_lower_case()] = to_string(i).to_lower_case();
            }
            // Parse activity section as usual
            string sa_pattern = DTREG + PLREG + "(((added|took) ([0-9,]*) ([^\001]*?)[.][\001])"
                + "|(contributed ([0-9,]*) Meat)"
                + "|([^\001]*))";
            matcher sa_match = create_matcher(sa_pattern, section_body);
            while (find(sa_match)) {
                int when = clan_date_to_int(group(sa_match, 1));
                if (when <= stash_only_after)
                    continue;
                string who = (group(sa_match, 2));
                if (group(sa_match, 4) != "") {
                    int n = to_int(group(sa_match, 6));
                    string itstr = to_lower_case(group(sa_match, 7));
                    item it;
                    if (n == 1) {
                        it = to_item(itstr);
                    } else {
                        it = to_item(singular[itstr]);
                    }
                    if (group(sa_match, 5) == "took") {
                        n = -n;
                    }
                    stash_activity.add(when, who, it, n);
                } else if (group(sa_match, 8) != "") {
                    int n = to_int(group(sa_match, 9));
                    stash_activity.add(when, who, $item[none], n);
                } else {
                    print(`Unrecognized line: {group(sa_match, 10)}`, "red");
                    activity.add('stash', when, who, '?', group(sa_match, 10));
                }
            }
            break;
        case "Miscellaneous:":
            string m_pattern = DTREG + PLREG + "((posted an announcement)"
                + "|(changed Rank for " + PLREG + ")" 
                + "|(changed title for " + PLREG + ".[(]([^)]*)[)])"
                + "|(applied to the clan)"
                + "|(modified a Rank [(]([^)]*)[)])"
                + "|(transferred leadership to " + PLREG + ")"
                + "|([^\001]*))";
            matcher m_match = create_matcher(m_pattern, section_body);
            while (find(m_match)) {
                int when = clan_date_to_int(group(m_match, 1));
                if (when <= only_after)
                    continue;
                string who = (group(m_match, 2));
                if (group(m_match, 4) != "") {
                    activity.add('misc', when, who, 'posted');
                } else if (group(m_match, 5) != "") {
                    activity.add('misc', when, who, 'chgrank', group(m_match, 6));
                } else if (group(m_match, 7) != "") {
                    activity.add('misc', when, who, 'chgtitle', 
                                 group(m_match, 8) + "->" + group(m_match, 9));
                } else if (group(m_match, 10) != "") {
                    activity.add('misc', when, who, 'applied');
                } else if (group(m_match, 11) != "") {
                    activity.add('misc', when, who, 'modrank', group(m_match, 12));
                } else if (group(m_match, 13) != "") {
                    activity.add('misc', when, who, 'xfrlead', group(m_match, 14));
                } else {
                    print(`Unrecognized line: {group(m_match, 15)}`, "red");
                    activity.add('misc', when, who, '?', group(m_match, 15));
                }
            }
            break;
        case "Basement Stuff:":
            string bs_pattern = DTREG + PLREG + "((recovered ([0-9,]*) Meat from Hobopolis)"
                + "|(opened up ([^.\001]*))"
                + "|((shut down|sealed|flooded) ([^.\001]*))"
                + "|([^\001]*))";
            matcher bs_match = create_matcher(bs_pattern, section_body);
            while (find(bs_match)) {
                int when = clan_date_to_int(group(bs_match, 1));
                if (when <= only_after)
                    continue;
                string who = (group(bs_match, 2));
                if (group(bs_match, 4) != "") {
                    activity.add('basement', when, who, 'meat', group(bs_match, 5));
                } else if (group(bs_match, 6) != "") {
                    activity.add('basement', when, who, 'opened', group(bs_match, 7));
                } else if (group(bs_match, 8) != "") {
                    activity.add('basement', when, who, 'closed', group(bs_match, 10));
                } else {
                    print(`Unrecognized line: {group(bs_match, 11)}`, "red");
                    activity.add('basement', when, who, '?', group(bs_match, 11));
                }
            }
            break;
        case "Lounge Activity:":
            string la_pattern = DTREG + "(.*?) ((fabricated a (.*?) at the Floundry)"
                + "|(ate a ([^.\001]*)))";
            matcher la_match = create_matcher(la_pattern, section_body);
            while (find(la_match)) {
                int when = clan_date_to_int(group(la_match, 1));
                if (when <= only_after)
                    continue;
                string who = (group(la_match, 2));
                if (group(la_match, 4) != "") {
                    activity.add('lounge', when, who, 'fabricated', group(la_match, 5));
                } else if (group(la_match, 6) != "") {
                    activity.add('lounge', when, who, 'ate', group(la_match, 7));
                } else {
                    print(`Unrecognized line: {group(la_match, 8)}`, "red");
                    activity.add('lounge', when, who, '?', group(la_match, 8));
                }
            }
            break;
        default:
            break;
        }
    }
}

void get_clan_activity(string[string][int][string][string][int] activity,
                       int[int][string][item] stash_activity)
{
    // Get activity that has been saved so far
    file_to_map(activity_file_name(), activity);
    file_to_map(stash_activity_file_name(), stash_activity);
    int c = activity.count();
    int c2 = stash_activity.count();
    print(`{c} records loaded from activity file`);
    print(`{c2} records loaded from stash activity file`);
    // Add activity from KoL that we don't already have
    add_clan_activity_from_kol(activity, stash_activity);
    print(`{activity.count() - c} new activity records loaded from KoL`);
    print(`{stash_activity.count() - c2} new stash activity records loaded from KoL`);
    // Save to file and return
    map_to_file(activity, activity_file_name());
    map_to_file(stash_activity, stash_activity_file_name());
}

// ===============================================================

void main(string op)
{
    dungeon_run[int] raidlogs;
    matcher m = create_matcher("([A-Za-z-]*) *(.*)", op);
    if (! find(m)) {
        print("Error: Could not parse '" + op, "red");
        return;
    }
    string cmd = to_lower_case(group(m, 1));
    string arg = group(m, 2);
    switch (cmd) {
    case "clan":
        foreach id, c in get_clannies() {
            print(to_string(c));
        }
        break;
    case "clan-active":
        foreach id, c in get_clannies() {
            if (c.is_active)
                print(to_string(c));
        }
        break;
    /*case "player":
        player p = lookup_player(to_int(arg));
        print(to_string(p));
        break;*/
    case "join":
        join_clan(arg);
        break;
    case "loot":
        print("Loading raidlogs from ISMO...");
        string saved_clan = get_clan_name();
        join_clan("ISMO");
        dungeon_run[int] raidlogs_i = load_raidlogs();
        print("Loading raidlogs from CLAN WHERE COOL PEOPLE GO!!!...");
        join_clan("CLAN WHERE COOL PEOPLE GO!!!");
        dungeon_run[int] raidlogs_c = load_raidlogs();
        join_clan(saved_clan);
        /* */
        int[string][string] totals;
        foreach n, drun in raidlogs_i {
            foreach n, dist in drun.distribs {
                string r = to_lower_case(dist.receiver);
                string l = to_lower_case(dist.loot);
                totals[l][r] = totals[l][r] + 1;
            }
        }
        foreach n, drun in raidlogs_c {
            foreach n, dist in drun.distribs {
                string r = to_lower_case(dist.receiver);
                string l = to_lower_case(dist.loot);
                totals[l][r] = totals[l][r] + 1;
            }
        }
        string last_header = "";
        foreach loot, player, n in totals {
            if (loot != last_header) {
                print(`==== {loot} ====`);
                last_header = loot;
            }
            print(`{n} {player}`);
        }
        break;
    case "myloot":
        print("Loading raidlogs...");
        raidlogs = load_raidlogs();
        print("Extracting " + my_name() + "...");
        string[string] my_loot = players_loot(raidlogs, my_name());
        foreach n, it in my_loot {
            print(`{n} {it}`);
        }
        break;
    case "members":
        cl_name_id c = lookup_clan_id(arg);
        print(`Clan {c.name} has id {c.id}`);
        cl_player[int] members = clan_members(c.id);
        sort members by value.id;
        foreach n, p in members {
            load_player_page_info(p);
            if (is_active(p))
                print(to_string(p));
        }
        break;
    case "dump":
        string[string][int][string][string][int] clan_activity;
        int[int][string][item] stash_activity;
        get_clan_activity(clan_activity, stash_activity);
        // Dump results
        //foreach cat, when, who, what, n, whom in clan_activity {
        //    print(`[{cat}] {when}: {who} {what} {whom}`);
        //}
        // What items get taken out of the stash?
        int[string] demand;
        foreach when, who, it, n in stash_activity {
            if (n < 0) {
                string s = to_lower_case(to_string(it));
                demand[s] = demand[s] - n;
            }
        }
        print("Total Demand:");
        foreach it, d in demand {
            print(`{d} {it}`);
        }
        break;
    case "stash":
        int[item] stash = get_stash();
        int[string] sorted_stash;
        foreach it, q in stash {
            sorted_stash[to_lower_case(to_string(it))] = q;
        }
        foreach it, q in sorted_stash {
            print(`{q} {it}`);
        }
        if (put_stash(2, $item[2-ball])) {
            print("Put " + 2, "olive");
        }
        if (take_stash(2, $item[2-ball])) {
            print("Got " + 2, "olive");
        }
        break;
    default:
        print("Command '" + cmd + "' unknown", "red");
        break;
    }
    print("Done.");
    print("");
}
