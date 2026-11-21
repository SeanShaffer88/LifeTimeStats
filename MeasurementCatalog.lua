-- Reviewed measurement-policy identities for the 992 advertised definitions.
-- Changes to definitions require explicit catalog review; unknown definitions fail coverage.
local _, ns = ...
local catalog = {}
ns.MeasurementCatalog = catalog
local function Family(family, quality, ids)
    for _, id in ipairs(ids) do catalog[id] = { family = family, quality = quality, provider = id } end
end

Family("collections", "observed", {
    "tally:players", "tally:killers", "tally:foughtenemies", "tally:hurtby",
    "tally:dungeonbook", "tally:sessionlog", "tally:bgwins", "tally:bglosses",
    "tally:bgobjectives", "tally:dungeonruns", "tally:guide_bosspull", "tally:guide_bosswipe",
    "tally:guide_bossdeath", "tally:guide_bosstime", "tally:guide_rundeath", "tally:guide_worldbosses",
    "tally:guide_firstkillmates", "tally:creaturetypes", "tally:creatureclass", "tally:deathhour",
    "tally:playweekdays", "tally:playhours", "tally:mailto", "tally:mailfrom",
    "tally:dungeonclears", "tally:killedwith", "tally:envdamage", "tally:damagetoenemy",
    "tally:standinfire", "tally:petdamage", "tally:bossdamage", "tally:bosses_party",
    "tally:bosses_raid", "tally:instances", "tally:citytime", "tally:continenttime",
    "tally:instancetime", "tally:killcolor", "tally:books", "tally:potions",
    "tally:loginhour", "tally:pets", "tally:gamehour", "tally:lowbiekillers",
    "tally:npcnames", "tally:reps", "tally:uierrors", "tally:epics",
    "tally:ex_recovery_ends", "tally:recordhistory", "unique:npcs", "unique:worn",
    "unique:trainers", "unique:bankers", "unique:auctioneers", "unique:bosses_party",
    "unique:bosses_raid", "unique:bosses_world", "unique:instances", "unique:books",
    "unique:pets", "unique:days_played", "unique:appearances",
})
Family("combat", "derived", {
    "combat:computed:Average damage per second", "combat:computed:Crit rate", "combat:computed:Dodge rate", "combat:computed:Your average share of group damage",
    "combat:computed:Battleground win rate", "combat:computed:Share of observed combat samples moving", "combat:computed:Observed fight survival rate (known outcomes)", "combat:computed:Kills per online hour",
    "combat:computed:Fights per online hour", "combat:computed:Successful casts per online hour", "combat:computed:Interrupts per online hour", "combat:computed:Dispels per online hour",
    "combat:computed:Effective healing per recorded heal", "combat:computed:Overhealing share of total healing", "combat:computed:Healing directed to others", "combat:computed:Healing directed to yourself",
    "combat:computed:Pet share of recorded damage", "combat:computed:Player share of recorded damage taken", "combat:computed:Fights won per fight entered", "combat:computed:Fights without a kill per fight entered",
})
Family("combat", "observed", {
    "adventure:counter:guide_boss_fight_time", "combat:counter:dmg_done", "combat:counter:dmg_taken", "combat:counter:dmg_taken_pvp",
    "combat:counter:fights", "combat:counter:dm_fight_time", "combat:counter:fights_won", "combat:counter:hits",
    "combat:counter:melee_hits", "combat:counter:spell_hits", "combat:counter:ranged_hits", "combat:counter:dot_ticks",
    "combat:counter:crits", "combat:counter:glancing_out", "combat:counter:out_miss", "combat:counter:out_dodge",
    "combat:counter:out_parry", "combat:counter:out_block", "combat:counter:out_resist", "combat:counter:out_absorb",
    "combat:counter:out_immune", "combat:counter:out_evade", "combat:counter:hits_taken", "combat:counter:crits_taken",
    "combat:counter:crushing_in", "combat:counter:in_dodge", "combat:counter:in_parry", "combat:counter:in_block",
    "combat:counter:blocks_partial_in", "combat:counter:in_miss", "combat:counter:in_resist", "combat:counter:in_absorb",
    "combat:counter:in_immune", "combat:counter:in_reflect", "combat:counter:heal_done", "combat:counter:heal_others",
    "combat:counter:heal_self", "combat:counter:overheal", "combat:counter:heals", "combat:counter:heal_crits",
    "combat:counter:heal_taken", "combat:counter:killing_blows", "combat:counter:critters_love_kill", "combat:counter:critter_kills",
    "combat:counter:hk_server", "combat:counter:honor_events", "combat:counter:casts_interrupted", "combat:counter:interrupts",
    "combat:counter:dispels", "combat:counter:overkill", "combat:counter:deadly_hits", "combat:counter:dm_fights_dmg",
    "combat:counter:dmg_pet", "combat:counter:dmg_avoidable", "combat:counter:fights_in_fire", "combat:counter:group_fights",
    "combat:counter:meter_topped", "combat:counter:allies_died", "combat:counter:buffs_given", "combat:counter:buffs_from_others",
    "combat:counter:debuffs_taken", "combat:counter:bg_won", "combat:counter:bg_lost", "combat:counter:bg_killing_blows",
    "combat:counter:bg_hks", "combat:counter:bg_deaths", "combat:counter:bg_honor", "combat:counter:bg_flags_captured",
    "combat:counter:bg_flags_returned", "combat:counter:bg_flags_picked", "combat:counter:bg_bases_assaulted", "combat:counter:bg_bases_defended",
    "combat:counter:ex_fights_observed", "combat:counter:ex_fights_survived", "combat:counter:ex_fights_ended_dead", "combat:counter:ex_fights_liveness_observed",
    "combat:counter:ex_fights_npc_kill", "combat:counter:ex_fights_pvp_kill", "combat:counter:ex_fights_incomplete", "combat:counter:cc_taken",
    "combat:counter:cc_time", "combat:counter:cc_stun", "combat:counter:cc_fear", "combat:counter:cc_root",
    "combat:counter:cc_silence", "combat:counter:cc_lockout", "combat:counter:cc_pacify", "combat:counter:cc_charm",
    "combat:counter:cc_confuse", "combat:counter:cc_disarm", "combat:counter:cc_other", "deaths:counter:death_overkill",
    "deaths:counter:dmg_env_drowning", "deaths:counter:dmg_env_lava", "deaths:counter:dmg_env_fatigue", "fastest:fight_fast",
    "first:critter_kill", "first:critter_loved", "life:counter:spirit_healer", "life:counter:fights_no_kill",
    "tally:spellheal", "tally:critters", "tally:critters_loved", "records:record:max_healpower",
    "records:record:max_crit_pct", "records:record:max_spellcrit_pct", "records:record:max_dodge_pct", "records:record:max_parry_pct",
    "records:record:max_block_pct", "records:record:max_hit", "records:record:max_crit", "records:record:max_health",
    "records:record:max_fight_avoidable", "records:record:max_crit_streak", "records:record:max_heal", "records:record:max_heal_crit",
    "records:record:max_heal_taken", "records:record:max_hit_taken", "records:record:max_crit_taken", "records:record:max_fight_damage",
    "records:record:max_fight_dps", "records:record:max_fight_heal", "records:record:max_fight_taken", "records:record:max_fight_kills",
    "records:record:ex_fight_distance", "records:record:ex_fight_casts", "records:record:ex_fight_moving", "records:record:ex_fight_stationary",
    "social:counter:critters_loved", "unique:critter_kinds", "unique:critters_loved",
})
Family("deaths", "derived", {
    "deaths:computed:Kills per death", "deaths:computed:Share of observed time alive", "deaths:computed:Deaths per online hour",
})
Family("deaths", "observed", {
    "deaths:counter:deaths", "deaths:counter:deaths_npc", "deaths:counter:deaths_drown", "deaths:counter:deaths_fatigue",
    "deaths:counter:deaths_lava", "deaths:counter:deaths_slime", "deaths:counter:recap_damage", "deaths:counter:deaths_swimming",
    "deaths:counter:deaths_afk", "deaths:counter:deaths_party", "deaths:counter:deaths_raid", "deaths:counter:deaths_world",
    "deaths:counter:deaths_bg", "deaths:counter:releases", "deaths:counter:corpse_runs", "deaths:counter:corpses_retrieved",
    "deaths:counter:rez_offered", "deaths:counter:rez_accepted", "deaths:counter:rezzed_in_place",
})
Family("economy", "derived", {
    "wealth:computed:Different players mailed", "wealth:computed:Different players traded with", "wealth:computed:Gold per hour (online)", "wealth:computed:Net gold per hour",
    "wealth:computed:Vendor: average observed visit", "wealth:computed:Bank: average observed visit", "wealth:computed:Mailbox: average observed visit", "wealth:computed:Auction house: average observed visit",
    "wealth:computed:Trade window: average observed visit", "wealth:computed:Items looted per online hour", "wealth:computed:Quest gold per completed quest", "wealth:computed:Loot gold per loot window",
    "wealth:computed:Items per loot window", "wealth:computed:Average recorded repair bill", "wealth:computed:Average recorded flight fare", "wealth:computed:Vendor income per visit",
    "wealth:computed:Vendor spending per visit", "wealth:computed:Auction income per visit", "wealth:computed:Auction spending per visit", "wealth:computed:Quest share of recorded income",
    "wealth:computed:Loot share of recorded income", "wealth:computed:Vendor share of recorded income", "wealth:computed:Auction share of recorded income", "wealth:computed:Mail share of recorded income",
    "wealth:computed:Repair share of recorded spending", "wealth:computed:Flight share of recorded spending", "wealth:computed:Training share of recorded spending", "wealth:computed:Auction share of recorded spending",
    "wealth:computed:Mail share of recorded spending",
})
Family("economy", "observed", {
    "life:counter:respec_gold", "tally:mailgold_to", "tally:mailgold_from", "tally:tradegold_to",
    "tally:tradegold_from", "records:record:max_money", "records:record:max_loot_money", "unique:vendors",
    "wealth:counter:money_in", "wealth:counter:loot_value", "wealth:counter:loot_value_q0", "wealth:counter:loot_value_q1",
    "wealth:counter:loot_value_q2", "wealth:counter:loot_value_q3", "wealth:counter:loot_value_q4", "wealth:record:max_loot_value",
    "wealth:record:max_gold_per_hour", "wealth:record:max_value_per_hour", "wealth:counter:mail_gold_sent", "wealth:counter:mail_items_taken",
    "wealth:counter:trade_gold_given", "wealth:counter:trade_gold_received", "wealth:counter:money_out", "wealth:counter:money_loot",
    "wealth:counter:money_quest", "wealth:counter:money_vendor_in", "wealth:counter:money_vendor_out", "wealth:counter:money_repair",
    "wealth:counter:repairs", "wealth:counter:money_taxi", "wealth:counter:money_train", "wealth:counter:money_ah_in",
    "wealth:counter:money_ah_out", "wealth:counter:money_mail_in", "wealth:counter:money_mail_out", "wealth:counter:vendor_visits",
    "wealth:counter:bank_visits", "wealth:counter:ah_visits", "wealth:counter:mailbox_opens", "wealth:counter:mails_sent",
    "wealth:counter:buybacks", "wealth:counter:money_barber", "wealth:counter:auctions_posted", "wealth:counter:auction_bids",
    "wealth:counter:mail_returned", "wealth:counter:rolls_need", "wealth:counter:rolls_greed", "wealth:counter:rolls_pass",
    "wealth:counter:rolls_won", "wealth:counter:ex_visits_merchant", "wealth:counter:ex_visits_bank", "wealth:counter:ex_visits_mail",
    "wealth:counter:ex_visits_auction",
})
Family("inventory", "observed", {
    "adventure:counter:guide_boss_loot", "adventure:counter:guide_boss_loot_q2", "adventure:counter:guide_boss_loot_q3", "adventure:counter:guide_boss_loot_q4",
    "adventure:counter:items_crafted", "life:record:mounts_owned", "life:record:pets_owned", "life:counter:items_used",
    "tally:guide_lootboss", "tally:zoneloot", "tally:itemsources", "tally:itemsrc_good",
    "tally:itemsfrom", "tally:gatheritems_zone", "tally:wornitems", "tally:hearthsowned",
    "tally:itemsused", "records:record:bag_filled_max", "social:counter:bags_opened", "social:counter:bags_sorted",
    "unique:items", "unique:itemsheld", "wealth:counter:loot_unpriced", "wealth:record:max_bag_slots",
    "wealth:counter:items_logged", "wealth:counter:items_logged_q2", "wealth:counter:items_logged_q3", "wealth:counter:items_logged_q4",
    "wealth:counter:items_logged_q5", "wealth:counter:gathered_items", "wealth:counter:trade_items_given", "wealth:counter:trade_items_received",
    "wealth:counter:loot_windows", "wealth:counter:items_looted", "wealth:counter:loot_q0", "wealth:counter:loot_q1",
    "wealth:counter:loot_q2", "wealth:counter:loot_q3", "wealth:counter:loot_q4", "wealth:counter:loot_q5",
    "wealth:counter:items_destroyed", "wealth:counter:bags_full", "wealth:counter:gear_changes", "wealth:counter:items_bought",
    "wealth:counter:items_sold", "wealth:counter:gear_broken_seen",
})
Family("kills", "observed", {
    "adventure:counter:boss_kills_party", "adventure:counter:guide_first_boss_kills", "adventure:counter:guide_boss_kills_solo", "adventure:counter:guide_boss_kills_duo",
    "adventure:counter:guide_boss_kills_trio", "adventure:counter:guide_boss_kills_party4", "adventure:counter:guide_boss_kills_party5", "adventure:counter:guide_boss_kills_raid",
    "adventure:counter:bestiary_entries", "adventure:counter:boss_kills_raid", "adventure:counter:boss_kills_world", "combat:counter:kills_npc",
    "combat:counter:kills_pvp", "combat:counter:kills_grey", "combat:counter:kills_green", "combat:counter:kills_yellow",
    "combat:counter:kills_orange", "combat:counter:kills_red", "combat:counter:kills_elite", "combat:counter:kills_rare",
    "combat:counter:runs_pvp", "deaths:counter:deaths_pvp", "fastest:ten_kills", "first:pvp_kill",
    "first:elite", "tally:creatures", "tally:zonecreatures", "tally:zonekills",
    "tally:rares", "tally:skills", "records:record:max_session_kills", "unique:creatures",
    "unique:pvp_victims", "unique:rares", "wealth:record:max_kills_per_hour",
})
Family("life", "derived", {
    "life:computed:Days adventured", "life:computed:Unique hearthstones owned", "life:computed:Different hearth locations", "life:computed:Professions learned",
    "life:computed:Different inns rested at", "life:computed:Innkeepers met", "life:computed:Zones in your travel log", "life:computed:Mounts ridden",
    "life:computed:Different pets", "life:computed:Book / item text: average observed visit",
})
Family("life", "observed", {
    "life:counter:times_drunk", "life:counter:drunk_tipsy", "life:counter:drunk_drunk", "life:counter:drunk_smashed",
    "life:counter:sobered_up", "life:counter:campfires", "life:counter:nights_camped", "life:counter:pets_learned",
    "life:counter:summons_accepted", "life:counter:abilities_learned", "life:counter:recipes_learned", "life:counter:books_read",
    "life:counter:potions", "life:counter:elixirs", "life:counter:food", "life:counter:drink",
    "life:counter:bandages", "life:counter:objects_opened", "life:counter:breath_held", "life:counter:fatigue_entered",
    "life:counter:well_fed", "life:counter:pets_summoned", "life:counter:times_naked", "life:counter:logins_dawn",
    "life:counter:logins_dusk", "life:counter:deaths_lowbie", "life:counter:ex_visits_book", "life:counter:cinematics_seen",
    "life:counter:movies_seen", "life:counter:cinematics_finished", "life:counter:cinematics_skipped", "life:counter:cinematic_time",
    "life:counter:respecs", "life:counter:talent_loadouts", "life:counter:spec_changes",
})
Family("milestones", "derived", {
    "records:computed:Adventurer score",
})
Family("milestones", "observed", {
    "fastest:corpse_fast", "fastest:first_death_session", "fastest:bg_win", "fastest:ex_retrieval_fastest",
    "first:kill", "first:death", "first:jump", "first:npc",
    "first:green", "first:blue", "first:epic", "first:dungeon",
    "first:boss", "first:raid", "first:bg_win", "first:drunk",
    "first:campfire", "first:book", "first:haircut", "first:rare",
    "first:appearance", "records:record:max_ilvl", "records:record:max_str", "records:record:max_agi",
    "records:record:max_sta", "records:record:max_int", "records:record:max_spi", "records:record:max_armor",
    "records:record:max_ap", "records:record:max_res_fire", "records:record:max_res_nature", "records:record:max_res_frost",
    "records:record:max_res_shadow", "records:record:max_res_arcane", "records:record:max_revered", "records:record:max_exalted",
    "records:record:max_session_time", "records:record:max_bg_streak", "records:record:max_bg_kb", "records:record:max_bg_hks",
    "records:record:max_boss_damage", "records:record:best_boss_dps", "records:record:max_killing_blow", "records:record:max_corpse_time",
    "records:record:max_dead_wait", "records:record:max_alive", "records:record:max_fight", "records:record:max_dm_fight",
    "records:record:max_streak", "records:record:max_session_deaths", "records:record:max_roll", "records:record:max_session",
    "records:record:max_drunk", "records:record:ex_longest_moving", "records:record:ex_longest_stationary", "records:record:ex_longest_foot_moving",
    "records:record:ex_longest_swim_moving", "records:record:ex_longest_combat_moving", "records:record:ex_farthest_combat_moving", "records:record:ex_longest_combat_stationary",
    "records:record:ex_longest_peace_moving", "records:record:ex_farthest_peace_moving", "records:record:ex_longest_afk_moving", "records:record:ex_farthest_afk_moving",
    "records:record:ex_longest_active_moving", "records:record:ex_farthest_active_moving", "records:record:ex_longest_indoor_moving", "records:record:ex_farthest_indoor_moving",
    "records:record:ex_longest_outdoor_moving", "records:record:ex_farthest_outdoor_moving", "records:record:ex_longest_solo_moving", "records:record:ex_farthest_solo_moving",
    "records:record:ex_longest_world_moving", "records:record:ex_farthest_world_moving", "records:record:ex_longest_dungeon_moving", "records:record:ex_farthest_dungeon_moving",
    "records:record:ex_longest_raid_moving", "records:record:ex_farthest_raid_moving", "records:record:ex_longest_bg_moving", "records:record:ex_farthest_bg_moving",
    "records:record:ex_longest_arena_moving", "records:record:ex_farthest_arena_moving", "records:record:ex_visit_longest_merchant", "records:record:ex_visit_longest_bank",
    "records:record:ex_visit_longest_mail", "records:record:ex_visit_longest_auction", "records:record:ex_visit_longest_trainer", "records:record:ex_visit_longest_gossip",
    "records:record:ex_visit_longest_book", "records:record:cc_longest", "records:record:cinematic_longest", "records:record:respec_cost_max",
})
Family("profession", "observed", {
    "adventure:counter:skillups", "adventure:counter:gather_herb", "adventure:counter:gather_mine", "adventure:counter:gather_skin",
    "adventure:counter:fish", "first:fish", "first:profession", "tally:guide_bosskill",
    "tally:herbzones", "tally:orezones", "tally:fishzones", "tally:herbs",
    "tally:ores", "tally:created", "records:record:max_honored", "records:record:max_hp_before_killing_blow",
    "records:record:max_skill", "social:counter:skill_milestones", "social:counter:players_ignored", "social:counter:unignored",
    "social:counter:macros_created", "unique:professions", "wealth:record:max_gather_per_hour",
})
Family("progress", "derived", {
    "adventure:computed:Quest completion rate", "adventure:computed:XP per hour (online)", "adventure:computed:Dungeons entered", "adventure:computed:Dungeons fully cleared",
    "adventure:computed:Forever's new dungeons cleared", "adventure:computed:Different items from bosses", "adventure:computed:Different players grouped with in instances", "adventure:computed:Creature types killed",
    "adventure:computed:Trainer: average observed visit", "adventure:computed:Quest dialog: average observed visit", "adventure:computed:Quests completed per online hour", "adventure:computed:Reputation gained per online hour",
    "adventure:computed:Herbs gathered per online hour", "adventure:computed:Ore mined per online hour", "adventure:computed:Skinning actions per online hour", "adventure:computed:Fish caught per online hour",
    "adventure:computed:Items crafted per online hour", "adventure:computed:XP per completed quest (observed)", "adventure:computed:Quest XP share", "adventure:computed:Kill XP share",
    "adventure:computed:Exploration XP share",
})
Family("progress", "observed", {
    "adventure:counter:quests_accepted", "adventure:counter:quests_done", "adventure:counter:quests_abandoned", "adventure:counter:xp",
    "adventure:counter:xp_quest", "adventure:counter:xp_kill", "adventure:counter:xp_explore", "adventure:counter:xp_group",
    "adventure:counter:levels", "adventure:counter:talents_spent", "adventure:counter:rep_gained", "adventure:counter:rep_lost",
    "adventure:counter:runs_party", "adventure:counter:runs_party_boss", "adventure:counter:dj_full_clears", "adventure:counter:dj_bosses_found",
    "adventure:counter:guide_pulls", "adventure:counter:guide_wipes", "adventure:record:max_boss_fight", "adventure:record:max_wipe_fight",
    "adventure:counter:guide_boss_deaths", "adventure:counter:guide_run_deaths", "adventure:counter:guide_runs_logged", "adventure:counter:guide_runs_solo",
    "adventure:counter:guide_runs_duo", "adventure:counter:guide_runs_trio", "adventure:counter:guide_runs_party4", "adventure:counter:guide_runs_party5",
    "adventure:counter:guide_runs_raid", "adventure:counter:dj_runs_under", "adventure:counter:dj_runs_in", "adventure:counter:dj_runs_over",
    "adventure:counter:dj_clears_under", "adventure:counter:runs_raid", "adventure:counter:runs_raid_boss", "adventure:counter:raid_clears",
    "adventure:counter:invites_in", "adventure:counter:conjured", "adventure:counter:trainer_visits", "adventure:counter:ex_visits_trainer",
    "adventure:counter:ex_visits_quest", "fastest:level_fast", "fastest:quest_fast", "first:quest",
    "first:levelup", "life:counter:rested_xp", "life:counter:quest_items_used", "tally:zonequests",
    "tally:levelzones", "tally:guide_deathlevel", "tally:questzones", "tally:questlevels",
    "tally:leveltime", "records:record:quest_slow", "records:record:level_slow", "records:record:max_level",
    "records:record:ex_visit_longest_quest", "social:counter:rep_levels_gained", "social:counter:rep_levels_6", "social:counter:rep_levels_7",
    "social:counter:rep_levels_8", "social:counter:rep_levels_lost", "social:counter:questions_asked", "social:counter:questlog_opens",
    "unique:quests", "wealth:record:max_xp_per_hour", "wealth:record:max_item_level_found",
})
Family("sampled", "derived", {
    "combat:computed:Low-health share of readable health time", "combat:computed:Full-health share of readable health time", "deaths:computed:Average fully observed recovery distance", "deaths:computed:Average fully observed recovery time",
    "deaths:computed:Fully observed recovery time spent moving", "deaths:computed:Share of observed time spent recovering", "social:computed:Camera zoom steps", "travel:computed:Steps taken",
})
Family("sampled", "estimated", {
    "adventure:counter:time_party", "adventure:counter:time_raid", "adventure:counter:time_pvp", "adventure:counter:time_grouped",
    "adventure:counter:ex_time_dungeon_moving", "adventure:counter:ex_dist_dungeon_moving", "adventure:counter:ex_time_raid_moving", "adventure:counter:ex_dist_raid_moving",
    "adventure:counter:ex_time_bg_moving", "adventure:counter:ex_dist_bg_moving", "adventure:counter:ex_time_arena_moving", "adventure:counter:ex_dist_arena_moving",
    "adventure:counter:ex_visit_time_trainer", "adventure:counter:ex_visit_time_quest", "combat:counter:time_combat", "combat:counter:ex_time_combat_moving",
    "combat:counter:ex_dist_combat_moving", "combat:counter:ex_time_combat_stationary", "combat:counter:ex_time_low_health", "combat:counter:ex_dist_low_health",
    "combat:counter:ex_time_full_health", "combat:counter:ex_dist_full_health", "combat:counter:ex_time_casting", "combat:counter:ex_dist_casting",
    "combat:counter:ex_time_channeling", "combat:counter:ex_dist_channeling", "combat:counter:cc_time_stun", "combat:counter:cc_time_fear",
    "combat:counter:cc_time_root", "combat:counter:cc_time_silence", "combat:counter:cc_time_lockout", "combat:counter:cc_time_pacify",
    "combat:counter:cc_time_charm", "combat:counter:cc_time_confuse", "combat:counter:cc_time_disarm", "combat:counter:cc_time_other",
    "deaths:counter:deaths_fall", "deaths:counter:time_dead", "deaths:counter:falls", "deaths:counter:falls_survived",
    "deaths:counter:dmg_fall", "deaths:counter:ex_recovery_distance", "deaths:counter:ex_retrieval_distance", "deaths:counter:ex_recovery_time",
    "deaths:counter:ex_recovery_moving_time", "deaths:counter:ex_recovery_idle_time", "deaths:counter:ex_recovery_started", "deaths:counter:ex_recovery_partial",
    "deaths:counter:ex_recovery_completed", "deaths:counter:ex_recovery_full", "deaths:counter:ex_retrieval_confirmed", "deaths:counter:ex_spirit_confirmed",
    "deaths:counter:ex_ghost_rez_confirmed", "deaths:counter:ex_recovery_unknown_end", "deaths:counter:ex_dead_body_time", "deaths:counter:ex_alive_time",
    "life:counter:time_wild", "life:counter:time_night", "life:counter:time_day", "life:counter:time_eating",
    "life:counter:time_drinking", "life:counter:time_naked", "life:counter:ex_visit_time_book", "tally:continentdist",
    "tally:zonedist", "tally:ex_recovery_zone_dist", "records:record:max_fall", "records:record:max_fall_survived",
    "records:record:max_fall_survived_pct", "records:record:max_fall_fatal", "records:record:max_airtime", "records:record:max_airtime_fatal",
    "records:record:max_corpse_dist", "records:record:max_speed", "records:record:max_wild", "records:record:ex_longest_fall_moving",
    "records:record:ex_farthest_fall_moving", "records:record:ex_longest_low_health", "records:record:ex_farthest_low_health", "records:record:ex_longest_full_health",
    "records:record:ex_farthest_full_health", "records:record:ex_longest_casting", "records:record:ex_farthest_casting", "records:record:ex_longest_channeling",
    "records:record:ex_farthest_channeling", "records:record:ex_recovery_longest", "records:record:ex_recovery_farthest", "social:counter:time_afk",
    "social:counter:ex_visit_time_gossip", "travel:counter:dist_total", "travel:counter:dist_foot", "travel:counter:dist_mount",
    "travel:counter:dist_swim", "travel:counter:dist_taxi", "travel:counter:dist_ghost", "travel:counter:airtime",
    "travel:counter:big_falls", "travel:counter:time_mounted", "travel:counter:time_swim", "travel:counter:time_taxi",
    "travel:counter:time_rest", "travel:counter:time_indoors", "travel:counter:time_outdoors", "travel:counter:ex_time_moving",
    "travel:counter:ex_time_stationary", "travel:counter:ex_time_foot_moving", "travel:counter:ex_time_mount_moving", "travel:counter:ex_time_swim_moving",
    "travel:counter:ex_time_peace_moving", "travel:counter:ex_dist_peace_moving", "travel:counter:ex_time_afk_moving", "travel:counter:ex_dist_afk_moving",
    "travel:counter:ex_time_active_moving", "travel:counter:ex_dist_active_moving", "travel:counter:ex_time_rest_moving", "travel:counter:ex_dist_rest_moving",
    "travel:counter:ex_time_indoor_moving", "travel:counter:ex_dist_indoor_moving", "travel:counter:ex_time_outdoor_moving", "travel:counter:ex_dist_outdoor_moving",
    "travel:counter:ex_time_group_moving", "travel:counter:ex_dist_group_moving", "travel:counter:ex_time_solo_moving", "travel:counter:ex_dist_solo_moving",
    "travel:counter:ex_time_world_moving", "travel:counter:ex_dist_world_moving", "travel:counter:ex_time_fall_moving", "travel:counter:ex_dist_fall_moving",
    "travel:counter:ex_visit_time_taximap", "wealth:counter:ex_visit_time_merchant", "wealth:counter:ex_visit_time_bank", "wealth:counter:ex_visit_time_mail",
    "wealth:counter:ex_visit_time_auction", "wealth:counter:ex_visit_time_trade",
})
Family("social", "derived", {
    "social:computed:People who whispered you", "social:computed:People you whispered", "social:computed:Things you overheard (/say, /yell)", "social:computed:Guilds joined",
    "social:computed:Critters loved and spared", "social:computed:Average roll", "social:computed:Active time (not AFK)", "social:computed:Play sessions",
    "social:computed:Average session", "social:computed:Average play per day played", "social:computed:Daily average, last 7 days", "social:computed:NPC conversation: average observed visit",
    "social:computed:Messages sent per online hour", "social:computed:Whispers received per online hour", "social:computed:Average typed bytes per public/channel message",
})
Family("social", "observed", {
    "adventure:counter:groups_joined", "combat:counter:duels_won", "combat:counter:duels_lost", "combat:counter:duels_started",
    "first:duel_won", "first:whisper_in", "first:whisper_out", "first:guild",
    "tally:guide_grouprun", "tally:guide_groupboss", "tally:tradewith", "tally:groupedtime",
    "tally:emotes", "tally:whisperers", "tally:whispered", "records:record:max_friendly",
    "records:record:max_group_share", "records:record:ex_longest_group_moving", "records:record:ex_farthest_group_moving", "records:record:ex_visit_longest_trade",
    "social:counter:chat_sent", "social:counter:people_met", "social:counter:people_groupings", "social:counter:factions_met",
    "social:counter:goals_reached", "social:counter:deaths_located", "social:counter:whispers_sent", "social:counter:whispers_in",
    "social:counter:whispers_afk", "social:counter:bn_whispers_in", "social:counter:bn_whispers_sent", "social:counter:chat_say",
    "social:counter:chat_yell", "social:counter:chat_party", "social:counter:chat_raid", "social:counter:chat_guild",
    "social:counter:chat_channel", "social:counter:chars_typed", "social:counter:lols", "social:counter:thanks_said",
    "social:counter:greetings", "social:counter:friends_added", "social:counter:friends_removed", "social:counter:invites_sent",
    "social:counter:invites_accepted", "social:counter:invites_declined", "social:counter:groups_left", "social:counter:guild_invites",
    "social:counter:ready_checks_seen", "social:counter:raid_marks", "social:counter:haircuts", "social:counter:barber_visits",
    "social:counter:emotes", "social:counter:emote_DANCE", "social:counter:emote_HUG", "social:counter:emote_WAVE",
    "social:counter:emote_LAUGH", "social:counter:emote_CHEER", "social:counter:emote_BOW", "social:counter:emote_CHICKEN",
    "social:counter:appearances", "social:counter:emote_LOVE", "social:counter:emote_RUDE", "social:counter:rolls",
    "social:counter:rolls_max", "social:counter:rolls_min", "social:counter:duels_asked", "social:counter:inspects",
    "social:counter:assists", "social:counter:targets", "social:counter:gossip_opens", "social:counter:afk_count",
    "social:counter:char_opens", "social:counter:spellbook_opens", "social:counter:talent_opens", "social:counter:friends_opens",
    "social:counter:map_opens", "social:counter:ui_errors", "social:counter:screenshots", "social:counter:logins",
    "social:counter:reloads", "social:counter:lts_opens", "social:counter:shares", "social:counter:ex_visits_gossip",
    "social:counter:map_pins", "social:counter:map_pins_cleared", "social:counter:who_searches", "social:counter:junk_sales",
    "social:counter:tracking_changes", "social:counter:walk_toggles", "social:counter:camera_zoom_in", "social:counter:camera_zoom_out",
    "social:counter:minimap_zoom_in", "social:counter:minimap_zoom_out", "social:counter:minimap_toggles", "social:counter:game_menu_opens",
    "social:counter:calendar_opens", "social:counter:collections_opens", "social:counter:achievement_opens", "social:counter:guild_opens",
    "social:counter:channels_opens", "social:counter:help_opens", "unique:groupmates", "unique:duelers",
    "unique:emotes", "unique:whisperers", "unique:whispered", "unique:guilds",
    "wealth:counter:trades", "wealth:counter:ex_visits_trade",
})
Family("spells", "observed", {
    "adventure:counter:spells_learned", "combat:counter:casts", "combat:counter:casts_failed", "deaths:counter:rezzes_cast",
    "tally:spelldamage", "tally:hurtbyspell", "tally:bandspells", "tally:spells",
    "tally:formtime", "tally:cc_spells", "tally:cc_spell_time", "records:record:max_spellpower",
    "records:record:max_mana", "records:record:max_spell_fight", "travel:counter:shapeshifts", "unique:spells",
})
Family("world", "derived", {
    "travel:top:citytime", "travel:top:continenttime", "travel:top:zonetime", "travel:computed:Flight map: average observed visit",
    "travel:computed:Share of readable movement time moving", "travel:computed:Share of readable movement time stationary", "travel:computed:Movement observation coverage", "travel:computed:Average moving speed (yd/s)",
})
Family("world", "observed", {
    "deaths:counter:deaths_mounted", "fastest:flight_fast", "first:mount", "first:flightpath",
    "first:hearthstone", "first:bindspot", "life:counter:nights_inn", "life:counter:hearth_moves",
    "life:counter:flightpaths_found", "life:record:flightpaths_known", "life:counter:mounts_learned", "life:counter:dismounts",
    "life:counter:inn_visits", "tally:zonevisits", "tally:zonetime", "tally:zonedeaths",
    "tally:campzones", "tally:campfirezones", "tally:drunkzones", "tally:hearthsused",
    "tally:bindspots", "tally:innvisits", "tally:mounts", "tally:ex_recovery_zone_time",
    "tally:ex_retrieval_zones", "records:record:flight_long", "records:record:ex_longest_mount_moving", "records:record:ex_longest_rest_moving",
    "records:record:ex_farthest_rest_moving", "records:record:ex_visit_longest_taximap", "travel:counter:jumps", "travel:counter:flights",
    "travel:counter:hearths", "travel:counter:hearth_binds", "travel:counter:mount_ups", "travel:counter:sits",
    "travel:counter:autoruns", "travel:counter:follows", "travel:counter:rest_entered", "travel:counter:zone_changes",
    "travel:counter:subzone_changes", "travel:counter:zones_discovered", "travel:counter:loading_screens", "travel:counter:ex_visits_taximap",
    "unique:flightmasters", "unique:zones", "unique:subzones", "unique:hearthstones",
    "unique:bindspots", "unique:inns", "unique:flightpoints", "unique:innkeepers",
    "unique:mounts",
})

-- Reviewed computed-provider contracts from Stats.lua; helper-generated ratios
-- attach their exact concrete inputs in Expanded.lua. No runtime source parsing.
local function Computed(id, inputs, calculation)
    local definition = assert(catalog[id], id)
    definition.inputs, definition.calculation = inputs, calculation
    definition.computedPolicy = #inputs > 0 and "inputs" or "unknown-provider"
end
Computed("travel:computed:Steps taken", { "c:dist_foot" }, "On-foot distance / 0.75 m stride.")
Computed("travel:top:citytime", { "t:citytime" }, "Highest retained citytime tally value; zero for an empty tally.")
Computed("travel:top:continenttime", { "t:continenttime" }, "Highest retained continenttime tally value; zero for an empty tally.")
Computed("travel:top:zonetime", { "t:zonetime" }, "Highest retained zonetime tally value; zero for an empty tally.")
Computed("combat:computed:Average damage per second", { "c:dmg_done", "c:time_combat" }, "Damage done / time in combat.")
Computed("combat:computed:Crit rate", { "c:crits", "c:hits" }, "100 × critical hits / hits landed; zero when no hits are recorded.")
Computed("combat:computed:Dodge rate", { "c:in_dodge", "c:hits_taken", "c:in_parry", "c:in_block", "c:in_miss" }, "100 × dodges / (dodges + hits taken + parries + blocks + misses); zero when no incoming attacks are recorded.")
Computed("combat:computed:Your average share of group damage", { "c:group_dmg_mine", "c:group_dmg_all" }, "100 × your recorded group damage / all recorded group damage; zero for an empty denominator.")
Computed("combat:computed:Battleground win rate", { "c:bg_won", "c:bg_lost" }, "100 × wins / (wins + losses); zero when no battleground result is recorded.")
Computed("deaths:computed:Kills per death", { "c:deaths", "c:kills_npc", "c:kills_pvp" }, "(creature kills + player kills) / deaths; zero when no deaths are recorded.")
Computed("adventure:computed:Quest completion rate", { "c:quests_done", "c:quests_accepted" }, "100 × quests completed / quests accepted; zero when no acceptances are recorded.")
Computed("adventure:computed:XP per hour (online)", { "c:xp", "c:time_online" }, "Experience × 3600 / recorded online seconds; zero when online time is zero.")
Computed("adventure:computed:Dungeons entered", { "u:dungeons_seen" }, "Retained unique identity count: dungeons_seen. Saturation is reported separately.")
Computed("adventure:computed:Dungeons fully cleared", { "u:dungeons_cleared" }, "Retained unique identity count: dungeons_cleared. Saturation is reported separately.")
Computed("adventure:computed:Forever's new dungeons cleared", { "u:forever_dungeons_cleared" }, "Retained unique identity count: forever_dungeons_cleared. Saturation is reported separately.")
Computed("adventure:computed:Different items from bosses", { "u:guide_bossitems" }, "Retained unique identity count: guide_bossitems. Saturation is reported separately.")
Computed("adventure:computed:Different players grouped with in instances", { "u:guide_groupmates" }, "Retained unique identity count: guide_groupmates. Saturation is reported separately.")
Computed("adventure:computed:Creature types killed", { "u:bestiary_types" }, "Retained unique identity count: bestiary_types. Saturation is reported separately.")
Computed("wealth:computed:Different players mailed", { "u:mail_partners" }, "Retained unique identity count: mail_partners. Saturation is reported separately.")
Computed("wealth:computed:Different players traded with", { "u:trade_partners" }, "Retained unique identity count: trade_partners. Saturation is reported separately.")
Computed("wealth:computed:Gold per hour (online)", { "c:money_in", "c:time_online" }, "Recorded money earned × 3600 / online seconds, rounded down; zero when online time is zero.")
Computed("wealth:computed:Net gold per hour", { "c:money_in", "c:money_out", "c:time_online" }, "(Recorded money earned - money spent) × 3600 / online seconds; zero when online time is zero.")
Computed("social:computed:People who whispered you", { "u:whisperers" }, "Retained unique identity count: whisperers. Saturation is reported separately.")
Computed("social:computed:People you whispered", { "u:whispered" }, "Retained unique identity count: whispered. Saturation is reported separately.")
Computed("social:computed:Things you overheard (/say, /yell)", { "c:heard_say", "c:heard_yell" }, "Recorded say messages + recorded yell messages.")
Computed("social:computed:Guilds joined", { "u:guilds" }, "Retained unique identity count: guilds. Saturation is reported separately.")
Computed("social:computed:Critters loved and spared", { "c:critters_loved", "c:critters_love_kill" }, "max(0, critters loved - loved critters subsequently killed).")
Computed("social:computed:Average roll", { "c:roll_sum", "c:rolls" }, "Sum of recorded roll values / number of rolls; zero when no rolls are recorded.")
Computed("social:computed:Active time (not AFK)", { "c:time_online", "c:time_afk" }, "max(0, recorded online seconds - AFK seconds).")
Computed("social:computed:Play sessions", { "h:sessionlog" }, "Number of retained session log entries; reload continues the current session.")
Computed("social:computed:Average session", { "h:sessionlog" }, "Sum of retained session durations / retained session count; zero for an empty log.")
Computed("social:computed:Average play per day played", { "h:sessionlog" }, "Sum of retained session durations / distinct session dates; zero for an empty log.")
Computed("social:computed:Daily average, last 7 days", { "h:sessionlog" }, "Retained session durations starting within the last seven days / 7.")
Computed("life:computed:Days adventured", { "u:days_played" }, "Retained unique identity count: days_played. Saturation is reported separately.")
Computed("life:computed:Unique hearthstones owned", { "u:hearthstones" }, "Retained unique identity count: hearthstones. Saturation is reported separately.")
Computed("life:computed:Different hearth locations", { "u:bindspots" }, "Retained unique identity count: bindspots. Saturation is reported separately.")
Computed("life:computed:Professions learned", { "u:professions" }, "Retained unique identity count: professions. Saturation is reported separately.")
Computed("life:computed:Different inns rested at", { "u:inns" }, "Retained unique identity count: inns. Saturation is reported separately.")
Computed("life:computed:Innkeepers met", { "u:innkeepers" }, "Retained unique identity count: innkeepers. Saturation is reported separately.")
Computed("life:computed:Zones in your travel log", { "h:zonelog" }, "Count of retained zone identities in the travel log.")
Computed("life:computed:Mounts ridden", { "u:mounts" }, "Retained unique identity count: mounts. Saturation is reported separately.")
Computed("life:computed:Different pets", { "u:pets" }, "Retained unique identity count: pets. Saturation is reported separately.")
Computed("records:computed:Adventurer score", {  }, "One number for how far you have come: levels, quests, exploration, dungeons, achievements, professions, gear and gold, minus 25 per death. /lts score shows the breakdown.")
