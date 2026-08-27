{ include("$jacamoJar/templates/common-cartago.asl") }
{ include("$jacamoJar/templates/common-moise.asl") }

target_limit(1).
active_wars(0).

// Default fallback game rules: RiotThreshold, RiotBreakpoint, RiotBaseDefense, RiotPenaltyMultiplier, LifePerUnit, AttackPerUnit, DefensePerUnit, MaxAlliances, ConqueredMorale
game_rules(33, 30, 5.0, 6.0, 20.0, 4.0, 5.0, 1, 25).

get_riot_threshold(Val)          :- game_rules(Val, _, _, _, _, _, _, _, _).
get_riot_breakpoint(Val)         :- game_rules(_, Val, _, _, _, _, _, _, _).
get_riot_base_defense(Val)        :- game_rules(_, _, Val, _, _, _, _, _, _).
get_riot_penalty_multiplier(Val) :- game_rules(_, _, _, Val, _, _, _, _, _).
get_life_per_unit(Val)           :- game_rules(_, _, _, _, Val, _, _, _, _).
get_attack_per_unit(Val)         :- game_rules(_, _, _, _, _, Val, _, _, _).
get_defense_per_unit(Val)        :- game_rules(_, _, _, _, _, _, Val, _, _).
get_max_alliances(Val)           :- game_rules(_, _, _, _, _, _, _, Val, _).
get_conquered_morale(Val)        :- game_rules(_, _, _, _, _, _, _, _, Val).

province_under_threat(ProvId) :-
    enemy_army_moving(_, Nation, _, _, _, _, ProvId, _) &
    at_war_with(Nation).

list_member(X, [X | _]).
list_member(X, [_ | T]) :-
    list_member(X, T).

total_enemy_strength(TotalStrength) :-
    .findall(EnemyStrength, (is_war_block_representative(Enemy) & alliance_strength(Enemy, EnemyStrength)), Strengths) &
    TotalStrength = math.sum(Strengths).

total_enemy_strength(Me, TotalStrength) :-
    total_enemy_strength(TotalStrength).

can_support_new_war(Me, TargetNation) :-
    alliance_strength(Me, MyStrength) &
    total_enemy_strength(CurrentTotalEnemyStrength) &
    alliance_strength(TargetNation, TargetStrength) &
    .count(allied_with(_), AllyCount) &
    MaxWars = 1 + AllyCount &
    .findall(Rep, is_war_block_representative(Rep), CurrentWarBlocks) &
    .length(CurrentWarBlocks, CurrentWarCount) &
    CurrentWarCount < MaxWars &
    CurrentTotalEnemyStrength + TargetStrength <= MyStrength * 1.5 &
    MyStrength >= TargetStrength.

can_sustain_war_against(TargetNation) :-
    .my_name(Me) &
    alliance_strength(Me, MyStrength) &
    total_enemy_strength(CurrentTotalEnemyStrength) &
    alliance_strength(TargetNation, TargetStrength) &
    .count(allied_with(_), AllyCount) &
    MaxWars = 1 + AllyCount &
    .findall(Rep, is_war_block_representative(Rep), CurrentWarBlocks) &
    .length(CurrentWarBlocks, CurrentWarCount) &
    CurrentWarCount <= MaxWars &
    CurrentTotalEnemyStrength <= MyStrength * 1.5 &
    MyStrength >= TargetStrength.

get_enemy_peace_priority(Enemy, 1) :- needs_war_with(Enemy).
get_enemy_peace_priority(Enemy, 0) :- not needs_war_with(Enemy).

is_border_province(AlliedProv) :-
    allied_province(AlliedProv, _, _, _, _, _, _) &
    enemy_province_status(_, Owner, _, _, _, _, BorderingAllies, _, _, _) &
    .member(AlliedProv, BorderingAllies) &
    not allied_with(Owner).

province_soldiers(Prov, 0) :-
    not my_army(_, _, _, _, _, Prov).

province_soldiers(Prov, Count) :-
    my_army(_, _, _, _, _, Prov) &
    get_life_per_unit(LifePerUnit) &
    .findall(Life / LifePerUnit, my_army(_, _, _, Life, _, Prov), List) &
    Count = math.sum(List).

nation_border_defense(BorderProv, Owner, SumDef) :-
    enemy_province_status(_, Owner, _, _, _, _, BorderingAllies, _, _, _) & 
    .member(BorderProv, BorderingAllies) & 
    not allied_with(Owner) &
    .findall(EnemyDef, (enemy_province_status(FProv, Owner, _, EnemyDef, _, _, BAllies, _, _, _) & .member(BorderProv, BAllies)), EnemyDefs) &
    SumDef = math.sum(EnemyDefs).

border_province_max_enemy_defense(BorderProv, 0) :-
    not (enemy_province_status(_, Owner, _, _, _, _, BorderingAllies, _, _, _) & .member(BorderProv, BorderingAllies) & not allied_with(Owner)).

border_province_max_enemy_defense(BorderProv, MaxEnemyDef) :-
    enemy_province_status(_, Owner, _, _, _, _, BorderingAllies, _, _, _) & .member(BorderProv, BorderingAllies) & not allied_with(Owner) &
    .findall(SumDef, (enemy_province_status(_, Own, _, _, _, _, BAllies, _, _, _) & .member(BorderProv, BAllies) & not allied_with(Own) & nation_border_defense(BorderProv, Own, SumDef)), SumDefs) &
    .max(SumDefs, MaxEnemyDef).

target_garrison(Prov, Target) :-
    is_border_province(Prov) &
    border_province_max_enemy_defense(Prov, EnemyDef) &
    get_defense_per_unit(DefensePerUnit) &
    EnemyDef > 0 &
    Target = (EnemyDef * 1.2 / DefensePerUnit) div 1 + 1.

target_garrison(Prov, 1) :-
    is_border_province(Prov) &
    border_province_max_enemy_defense(Prov, EnemyDef) &
    EnemyDef <= 0.

target_garrison(Prov, 0) :-
    not is_border_province(Prov).

province_garrison_deficit(Prov, Deficit) :-
    province_soldiers(Prov, OurSoldiers) &
    target_garrison(Prov, Target) &
    OurSoldiers < Target &
    Deficit = Target - OurSoldiers.

province_garrison_deficit(Prov, 0) :-
    province_soldiers(Prov, OurSoldiers) &
    target_garrison(Prov, Target) &
    OurSoldiers >= Target.

province_excess_soldiers(Prov, Excess) :-
    province_soldiers(Prov, OurSoldiers) &
    target_garrison(Prov, Target) &
    OurSoldiers > Target &
    Excess = OurSoldiers - Target.

province_excess_soldiers(Prov, 0) :-
    province_soldiers(Prov, OurSoldiers) &
    target_garrison(Prov, Target) &
    OurSoldiers <= Target.

capital_offset(true, 30).
capital_offset(false, 0).

double_offset(true, 20).
double_offset(false, 0).

resource_offset(Res, 15) :- resource_trend(Res, negative).
resource_offset(Res, 0) :- not resource_trend(Res, negative).

target_score(ProvId, EnemyNation, Score) :-
    enemy_province_status(ProvId, EnemyNation, _, DefenseValue, _, _, BorderingAllies, IsCapital, IsDouble, Resource) &
    capital_offset(IsCapital, CapOffset) &
    double_offset(IsDouble, DoubleOffset) &
    resource_offset(Resource, ResOffset) &
    Score = DefenseValue - CapOffset - DoubleOffset - ResOffset.

has_army_at_or_moving_to(ProvId) :-
    my_army(_, _, _, _, _, ProvId).
has_army_at_or_moving_to(ProvId) :-
    my_army_target(MyId, ProvId) & my_army_travelling(MyId) & ProvId \== none & ProvId \== "none".

plans_to_attack(Nation) :-
    resource_trend(NeededResource, negative) &
    .findall(Amount, (neighbor_resource(_, NeededResource, Amount) & Amount > 0), ListOfAmounts) &
    ListOfAmounts \== [] &
    .max(ListOfAmounts, MaxAmount) &
    neighbor_resource(Nation, NeededResource, MaxAmount).

needs_war_with(Enemy) :-
    resource_trend(NeededResource, negative) &
    neighbor_resource(Enemy, NeededResource, Amount) &
    Amount > 0.

needs_war_with(Enemy) :-
    resource_trend(NeededResource, negative) &
    are_allied(Enemy, Ally) &
    neighbor_resource(Ally, NeededResource, Amount) &
    Amount > 0.

are_allied(X, Y) :- allies(X, Y).
are_allied(X, Y) :- allies(Y, X).

is_war_block_representative(N) :-
    at_war_with(N) &
    not (at_war_with(O) & are_allied(N, O) & O < N).

alliance_strength(Nation, TotalStrength) :-
    .findall(Member, (Nation = Member | are_allied(Nation, Member)), RawMembers) &
    .union(RawMembers, [], Members) &
    .findall(Strength, (.member(M, Members) & nation_strength(M, Strength)), Strengths) &
    TotalStrength = math.sum(Strengths).

is_defending_riot_province(MyId) :-
    my_army(MyId, _, _, _, _, Loc) &
    allied_province(Loc, Morale, _, _, _, _, _) &
    get_riot_threshold(RiotThreshold) &
    Morale < RiotThreshold.

is_defending_riot_province(MyId) :-
    ordered_to_defend(MyId, DefProv) &
    allied_province(DefProv, Morale, _, _, _, _, _) &
    get_riot_threshold(RiotThreshold) &
    Morale < RiotThreshold.

my_army_path_distance(ArmyId, ProvId, Dist) :-
    my_army(ArmyId, _, _, _, _, Loc) &
    Loc \== unknown & Loc \== "" & Loc \== none & Loc \== "none" &
    province_distance(Loc, ProvId, Dist).

my_army_path_distance(ArmyId, ProvId, Dist) :-
    my_army(ArmyId, AX, AY, _, _, Loc) &
    (Loc == unknown | Loc == "" | Loc == none | Loc == "none" | not province_distance(Loc, ProvId, _)) &
    (allied_province(ProvId, _, PX, PY, _, _, _) | enemy_province_status(ProvId, _, _, _, PX, PY, _, _, _, _)) &
    Dist = math.sqrt((AX - PX)*(AX - PX) + (AY - PY)*(AY - PY)).

+clear_my_armies <- 
    .abolish(my_army(_, _, _, _, _, _));
    .abolish(my_army_travelling(_));
    .abolish(my_army_target(_, _));
    .abolish(targeted_province(_)).
+clear_allied_provinces <- .abolish(allied_province(_, _, _, _, _, _, _)).
+clear_enemy_provinces <- .abolish(enemy_province_status(_, _, _, _, _, _, _, _, _, _)).
+clear_neighbor_nations <- .abolish(neighbor_resource(_, _, _)).
+clear_alliances <- .abolish(allies(_, _)).

+at_war_with_update(Nation)
  <- .abolish(at_war_with(Nation));
     +at_war_with(Nation);
     .abolish(sent_alliance_request(Nation));
     .abolish(accepting_alliance(Nation));
     .abolish(allied_with(Nation));
     .count(at_war_with(_), Count);
     .abolish(active_wars(_));
     +active_wars(Count).

+peace_established_update(Nation)
  <- .abolish(at_war_with(Nation));
     .abolish(sent_peace_request(Nation));
     .abolish(alliance_declined(Nation));
     .abolish(war_target(Nation, _));
     .count(at_war_with(_), Count);
     .abolish(active_wars(_));
     +active_wars(Count);
     .print("Peace established with ", Nation);
     for (my_army_target(ArmyId, ProvId)) {
         if (my_army_travelling(ArmyId) & (enemy_province_status(ProvId, Nation, _, _, _, _, _, _, _, _) | not at_war_with(_))) {
             !retreat_army(ArmyId, "peace established with target's owner");
         }
     }.

+peace_request_received(Sender)
  <- if (needs_war_with(Sender) & can_sustain_war_against(Sender)) {
         .print("Declining peace request from ", Sender, " (We need resources from ", Sender, " or their coalition and can sustain the war)");
         vesna.via.decline_peace(Sender);
     } else {
         .print("Accepting peace request from ", Sender, " (Do not need their resources or unable to sustain war)");
         vesna.via.accept_peace(Sender);
     }.

+peace_request_declined(Sender)
  <- .abolish(sent_peace_request(Sender));
     .print("Peace request to ", Sender, " was declined.").

+alliance_established_update(N1, N2)
  <- .abolish(allies(N1, N2));
     .abolish(allies(N2, N1));
     +allies(N1, N2);
     .my_name(Me);
     if (N1 == Me) {
         .abolish(allied_with(N2));
         +allied_with(N2);
         .abolish(sent_alliance_request(_));
         .abolish(accepting_alliance(_));
         .abolish(alliance_declined(N2));
         .print("Alliance established with ", N2);
     };
     if (N2 == Me) {
         .abolish(allied_with(N1));
         +allied_with(N1);
         .abolish(sent_alliance_request(_));
         .abolish(accepting_alliance(_));
         .abolish(alliance_declined(N1));
         .print("Alliance established with ", N1);
     };
     if (N1 \== Me & N2 \== Me) {
         .print("Observed alliance established between ", N1, " and ", N2);
     }.

+alliance_established_update(Nation)
  <- .my_name(Me);
     +alliance_established_update(Me, Nation).

+alliance_request_received(Sender)
  <- ?get_max_alliances(MaxAlliances);
     .count(allied_with(_), AllyCount);
     .count(accepting_alliance(_), AcceptingCount);
     if (AllyCount < MaxAlliances & AcceptingCount < MaxAlliances & not plans_to_attack(Sender) & not at_war_with(Sender) & not allied_with(Sender) & (sent_alliance_request(Sender) | not sent_alliance_request(_))) {
         .abolish(accepting_alliance(Sender));
         +accepting_alliance(Sender);
         .abolish(sent_alliance_request(Sender));
         .print("Accepting alliance request from ", Sender);
         vesna.via.accept_alliance(Sender);
     } else {
         .print("Declining alliance request from ", Sender, " (Reason: AllyCount=", AllyCount, ", AcceptingCount=", AcceptingCount, " or waiting for another nation or planning attack/war)");
         vesna.via.decline_alliance(Sender);
     }.

+alliance_request_declined(Sender) : allied_with(Sender)
  <- .abolish(sent_alliance_request(Sender));
     .abolish(accepting_alliance(Sender)).

+alliance_request_declined(Sender) : not allied_with(Sender)
  <- .abolish(sent_alliance_request(Sender));
     .abolish(accepting_alliance(Sender));
     .abolish(alliance_declined(Sender));
     +alliance_declined(Sender);
     .print("Alliance request to ", Sender, " was declined.").

+alliance_broken_update(N1, N2)
  <- .abolish(allies(N1, N2));
     .abolish(allies(N2, N1));
     .my_name(Me);
     if (N1 == Me) {
         .abolish(allied_with(N2));
         .abolish(sent_alliance_request(N2));
         .abolish(accepting_alliance(N2));
         .print("Alliance with ", N2, " broken!");
     };
     if (N2 == Me) {
         .abolish(allied_with(N1));
         .abolish(sent_alliance_request(N1));
         .abolish(accepting_alliance(N1));
         .print("Alliance with ", N1, " broken!");
     };
     if (N1 \== Me & N2 \== Me) {
         .print("Observed alliance broken between ", N1, " and ", N2);
     }.

+alliance_broken_update(Nation)
  <- .my_name(Me);
     +alliance_broken_update(Me, Nation).

+neighbor_resource_update(Neighbor, Res, Amount)
  <- .abolish(neighbor_resource(Neighbor, Res, _));
     +neighbor_resource(Neighbor, Res, Amount).

+alliance_update(N1, N2)
  <- .abolish(allies(N1, N2));
     +allies(N1, N2);
     .my_name(Me);
     if (N1 == Me) { .abolish(allied_with(N2)); +allied_with(N2); };
     if (N2 == Me) { .abolish(allied_with(N1)); +allied_with(N1); }.

+resource_update(Type, Amount) : resource(Type, OldAmount) & OldAmount > Amount
  <- .abolish(resource(Type, _));
     +resource(Type, Amount);
     .abolish(resource_trend(Type, _));
     +resource_trend(Type, negative).

+resource_update(Type, Amount) : resource(Type, OldAmount) & OldAmount <= Amount
  <- .abolish(resource(Type, _));
     +resource(Type, Amount);
     .abolish(resource_trend(Type, _));
     +resource_trend(Type, positive).

+resource_update(Type, Amount) : not resource(Type, _)
  <- .abolish(resource(Type, _));
     +resource(Type, Amount);
     .abolish(resource_trend(Type, _));
     +resource_trend(Type, positive).

+my_army_update(Id, X, Y, Life, AttackValue, Loc)
  <- .abolish(my_army(Id, _, _, _, _, _));
     +my_army(Id, X, Y, Life, AttackValue, Loc);
     if (ordered_to_defend(Id, Loc)) {
         .abolish(ordered_to_defend(Id, Loc));
         .print("Army ", Id, " has arrived at and successfully defended ", Loc);
     }.

+allied_province_update(Id, Morale, X, Y, IsCapital, IsDouble, Resource)
  <- .abolish(allied_province(Id, _, _, _, _, _, _));
     +allied_province(Id, Morale, X, Y, IsCapital, IsDouble, Resource).

+allied_province_owner_update(Id, Morale, X, Y, IsCapital, IsDouble, Resource)
  <- .abolish(war_target(_, Id));
     .abolish(targeted_province(Id));
     .abolish(allied_province(Id, _, _, _, _, _, _));
     .abolish(enemy_province_status(Id, _, _, _, _, _, _, _, _, _));
     +allied_province(Id, Morale, X, Y, IsCapital, IsDouble, Resource);
     .print("Province ", Id, " is now allied! Evaluating new targets...");
     !check_eliminated_nations;
     for (my_army_target(ArmyId, Id)) {
         if (my_army_travelling(ArmyId)) {
             !retreat_army(ArmyId, "target province is already allied territory");
         }
     };
     !evaluate_attack_opportunities.

+my_army_destroyed_update(Id)
  <- .abolish(my_army(Id, _, _, _, _, _));
     .abolish(ordered_to_defend(Id, _));
     .abolish(my_army_travelling(Id));
     if (my_army_target(Id, TargetProv)) {
         .abolish(my_army_target(Id, _));
         if (not my_army_target(_, TargetProv)) {
             .abolish(targeted_province(TargetProv));
         }
     }.

+my_army_travelling_update(Id, true)
  <- .abolish(my_army_travelling(Id));
     +my_army_travelling(Id).

+my_army_travelling_update(Id, false)
  <- .abolish(my_army_travelling(Id)).

+my_army_travelling_update(Id, "true")
  <- .abolish(my_army_travelling(Id));
     +my_army_travelling(Id).

+my_army_travelling_update(Id, "false")
  <- .abolish(my_army_travelling(Id)).

+my_army_target_update(Id, none)
  : my_army_target(Id, TargetProv)
  <- .abolish(my_army_target(Id, _));
     if (TargetProv \== none & TargetProv \== "none" & not my_army_target(_, TargetProv)) {
         .abolish(targeted_province(TargetProv));
     }.

+my_army_target_update(Id, none)
  <- .abolish(my_army_target(Id, _)).

+my_army_target_update(Id, "none")
  : my_army_target(Id, TargetProv)
  <- .abolish(my_army_target(Id, _));
     if (TargetProv \== none & TargetProv \== "none" & not my_army_target(_, TargetProv)) {
         .abolish(targeted_province(TargetProv));
     }.

+my_army_target_update(Id, "none")
  <- .abolish(my_army_target(Id, _)).

+my_army_target_update(Id, TargetProv)
  : TargetProv \== none & TargetProv \== "none"
  <- .abolish(my_army_target(Id, _));
     +my_army_target(Id, TargetProv);
     .abolish(targeted_province(TargetProv));
     +targeted_province(TargetProv).

+enemy_province_update(Id, Owner, HasArmyStr, DefenseValue, X, Y, BorderingAllies, IsCapital, IsDouble, Resource)
  <- .abolish(enemy_province_status(Id, _, _, _, _, _, _, _, _, _));
     +enemy_province_status(Id, Owner, HasArmyStr, DefenseValue, X, Y, BorderingAllies, IsCapital, IsDouble, Resource).

+enemy_province_defense_update(Id, HasArmyStr, DefenseValue)
  : enemy_province_status(Id, Owner, _, _, X, Y, BorderingAllies, IsCapital, IsDouble, Resource)
  <- .abolish(enemy_province_status(Id, _, _, _, _, _, _, _, _, _));
     +enemy_province_status(Id, Owner, HasArmyStr, DefenseValue, X, Y, BorderingAllies, IsCapital, IsDouble, Resource).

+enemy_province_defense_update(Id, HasArmyStr, DefenseValue)
  <- true.

+enemy_province_owner_update(Id, Owner, HasArmyStr, DefenseValue, X, Y, BorderingAllies, IsCapital, IsDouble, Resource)
  <- .abolish(war_target(_, Id));
     .abolish(targeted_province(Id));
     .abolish(allied_province(Id, _, _, _, _, _, _));
     .abolish(enemy_province_status(Id, _, _, _, _, _, _, _, _, _));
     +enemy_province_status(Id, Owner, HasArmyStr, DefenseValue, X, Y, BorderingAllies, IsCapital, IsDouble, Resource);
     !check_eliminated_nations;
     if (not at_war_with(Owner)) {
         for (my_army_target(ArmyId, Id)) {
             if (my_army_travelling(ArmyId)) {
                 !retreat_army(ArmyId, "target province captured by neutral or non-enemy nation");
             }
         }
     };
     if (at_war_with(Owner)) {
         !evaluate_attack_opportunities;
     }.

+province_morale_update(Id, Morale)
  : allied_province(Id, _, X, Y, IsCapital, IsDouble, Resource)
  <- .abolish(allied_province(Id, _, _, _, _, _, _));
     +allied_province(Id, Morale, X, Y, IsCapital, IsDouble, Resource).

+province_morale_update(Id, Morale)
  <- true.

+nation_strength_update(Nation, Strength)
  <- .abolish(nation_strength(Nation, _));
     +nation_strength(Nation, Strength).

+active_wars_update(Count)
  <- .abolish(active_wars(_));
     +active_wars(Count).

+day_cycle_update(Day)
  <- .abolish(day_cycle(_));
     +day_cycle(Day);
     .print("Current game day: ", Day);
     !check_eliminated_nations;
     if (war_cooldown_end_day(EndDay) & Day >= EndDay) {
         .abolish(war_cooldown);
         .abolish(war_cooldown_end_day(_));
         .print("War cooldown ended.");
      }.

+match_over <-
     .drop_all_intentions;
     .drop_all_desires;
     .drop_all_events;
     .print("Match over! Interrupted all goals and intentions.").

+game_rules_update(RiotThreshold, RiotBreakpoint, RiotBaseDefense, RiotPenaltyMultiplier, LifePerUnit, AttackPerUnit, DefensePerUnit, MaxAlliances, ConqueredMorale)
  <- .abolish(game_rules(_, _, _, _, _, _, _, _, _));
     +game_rules(RiotThreshold, RiotBreakpoint, RiotBaseDefense, RiotPenaltyMultiplier, LifePerUnit, AttackPerUnit, DefensePerUnit, MaxAlliances, ConqueredMorale);
     if (not evaluation_loop_started) {
         +evaluation_loop_started;
         .wait(1000);
         !!periodic_evaluation;
     }.

+!evaluate_targets : not war_cooldown
  <- .findall([Amount, NeededResource, Neighbor], 
              (resource_trend(NeededResource, negative) & 
               neighbor_resource(Neighbor, NeededResource, Amount) & 
               Amount > 0 & 
               not at_war_with(Neighbor) & 
               not allied_with(Neighbor)), Opportunities);
     if (Opportunities \== []) {
         .max(Opportunities, [MaxAmount, _, _]);
         .findall([Resource, Neighbor], .member([MaxAmount, Resource, Neighbor], Opportunities), RawTopOpportunities);
         .union(RawTopOpportunities, [], TopOpportunities);
         .shuffle(TopOpportunities, ShuffledOpportunities);
         ShuffledOpportunities = [[BestResource, BestNeighbor] | _];
         !decide_attack(BestNeighbor, BestResource);
     }.

+!evaluate_targets : war_cooldown
  <- true.

+!decide_attack(TargetNation, NeededResource)
  : not at_war_with(TargetNation)
    & not allied_with(TargetNation)
    & not war_cooldown
    & .my_name(Me)
    & can_support_new_war(Me, TargetNation)
    & needs_war_with(TargetNation)
  <- .my_name(Me);
     if (alliance_strength(Me, MyStrengthPercentage) & alliance_strength(TargetNation, TargetStrengthPercentage)) {
         if (MyStrengthPercentage >= TargetStrengthPercentage) {
             vesna.via.declare_war(TargetNation);
             .abolish(at_war_with(TargetNation));
             +at_war_with(TargetNation);
             .abolish(war_cooldown);
             +war_cooldown;
             if (day_cycle(CurrentDay)) {
                 CooldownEndDay = CurrentDay + 1;
             } else {
                 CooldownEndDay = 2;
             };
             .abolish(war_cooldown_end_day(_));
             +war_cooldown_end_day(CooldownEndDay);
             .print("Declared war on ", TargetNation, " because they have the most ", NeededResource, ", which I need! (MyStrength: ", MyStrengthPercentage, "%, TargetStrength: ", TargetStrengthPercentage, "%). War cooldown started, ending on day ", CooldownEndDay);
         } else {
             .print("Decided NOT to declare war on ", TargetNation, " because they are stronger than me (MyStrength: ", MyStrengthPercentage, "%, TargetStrength: ", TargetStrengthPercentage, "%).");
         }
     } else {
         .print("Decided NOT to declare war on ", TargetNation, " because strength info is missing.");
     }.

+!decide_attack(TargetNation, NeededResource)
  <- true.

+!select_war_target(EnemyNation, BestProv)
  <- .findall([Score, ProvId], (enemy_province_status(ProvId, EnemyNation, _, _, _, _, BorderingAllies, _, _, _) & BorderingAllies \== [] & not war_target(EnemyNation, ProvId) & target_score(ProvId, EnemyNation, Score)), Options);
     if (Options \== []) {
         .min(Options, [MinScore, _]);
         .findall(Prov, .member([MinScore, Prov], Options), RawTopProvs);
         .union(RawTopProvs, [], TopProvs);
         .shuffle(TopProvs, ShuffledProvs);
         ShuffledProvs = [BestProv | _];
         .abolish(war_target(EnemyNation, BestProv));
         +war_target(EnemyNation, BestProv);
         .print("Selected target province ", BestProv, " of ", EnemyNation, " with priority score ", MinScore);
     }.

+!evaluate_attack_opportunities : true
  <- for(war_target(EnemyNation, TargetProv)) {
         if (allied_province(TargetProv, _, _, _, _, _, _) | not enemy_province_status(TargetProv, EnemyNation, _, _, _, _, _, _, _, _) | not at_war_with(EnemyNation)) {
             .abolish(war_target(EnemyNation, TargetProv));
             .abolish(targeted_province(TargetProv));
             .print("Removed stale war target ", TargetProv, " for ", EnemyNation);
         }
     };
     for(at_war_with(EnemyNation)) {
         .count(war_target(EnemyNation, _), CurrentTargetCount);
         ?target_limit(Limit);
         if (CurrentTargetCount < Limit) {
             !select_war_target(EnemyNation, _);
         }
     };
     for(war_target(EnemyNation, ProvId)) {
         if (at_war_with(EnemyNation) & not has_army_at_or_moving_to(ProvId)) {
             if (enemy_province_status(ProvId, EnemyNation, _, EnemyDefenseValue, _, _, BorderingAllies, _, _, _)) {
                 if (BorderingAllies \== []) {
                     ?get_life_per_unit(LifePerUnit);
                     ?get_attack_per_unit(AttackPerUnit);
                     ?get_defense_per_unit(DefensePerUnit);
                     ?get_riot_breakpoint(RiotBreakpoint);
                     ?get_riot_base_defense(RiotBaseDefense);
                     ?get_riot_penalty_multiplier(RiotPenaltyMultiplier);
                     ?get_conquered_morale(ConqueredMorale);

                     if (ConqueredMorale >= RiotBreakpoint) {
                         RiotGarrison = RiotBaseDefense / DefensePerUnit;
                     } else {
                         RiotGarrison = (RiotBaseDefense + (RiotBreakpoint - ConqueredMorale) * RiotPenaltyMultiplier) / DefensePerUnit;
                     };
                     MinGarrisonSoldiers = math.max(2, (RiotGarrison div 1) + 1);

                     if (EnemyDefenseValue > 0) {
                         CombatSoldiers = (EnemyDefenseValue * 1.3 / AttackPerUnit) div 1 + 1;
                         TargetSoldiers = CombatSoldiers + MinGarrisonSoldiers;
                         TargetStrength = TargetSoldiers * AttackPerUnit;
                     } else {
                         TargetSoldiers = MinGarrisonSoldiers;
                         TargetStrength = TargetSoldiers * AttackPerUnit;
                     };

                     .findall([AttackValue, MyId], (my_army(MyId, _, _, Life, AttackValue, Loc) & .member(Loc, BorderingAllies) & not is_defending_riot_province(MyId) & not my_army_travelling(MyId) & not (my_army_target(MyId, T) & T \== none & T \== "none")), AvailableArmies);
                     if (AvailableArmies \== []) {
                         // 1. Check if any single border army can split off TargetSoldiers while keeping a safe garrison (at least 2 soldiers left behind)
                         .findall([Soldiers, MyId], (.member([AttackVal, MyId], AvailableArmies) & my_army(MyId, _, _, Life, _, _) & Soldiers = Life / LifePerUnit & Soldiers > TargetSoldiers + 2), SplittableArmies);
                         if (SplittableArmies \== []) {
                             .max(SplittableArmies, [MaxSoldiers, BestArmyId]);
                             SplitCount = TargetSoldiers;
                             vesna.via.split_army(BestArmyId, SplitCount, ProvId);
                             .abolish(targeted_province(ProvId));
                             +targeted_province(ProvId);
                             .print("Split army ", BestArmyId, " to send ", SplitCount, " soldiers (Atk: ", SplitCount * AttackPerUnit, ") to target province ", ProvId, " (Def: ", EnemyDefenseValue, ")");
                         } else {
                             // 2. Check if any single border army is strong enough on its own without splitting
                             .findall([Soldiers, MyId], (.member([AttackVal, MyId], AvailableArmies) & my_army(MyId, _, _, Life, _, _) & Soldiers = Life / LifePerUnit & Soldiers >= TargetSoldiers), StrongSingleArmies);
                             if (StrongSingleArmies \== []) {
                                 .max(StrongSingleArmies, [MaxS, SingleArmyId]);
                                 vesna.via.move_army(SingleArmyId, ProvId);
                                 .abolish(my_army_travelling(SingleArmyId));
                                 +my_army_travelling(SingleArmyId);
                                 .abolish(my_army_target(SingleArmyId, _));
                                 +my_army_target(SingleArmyId, ProvId);
                                 .abolish(targeted_province(ProvId));
                                 +targeted_province(ProvId);
                                 .print("Sent full army ", SingleArmyId, " (", MaxS, " soldiers, Atk: ", MaxS * AttackPerUnit, ") to attack target province ", ProvId, " (Def: ", EnemyDefenseValue, ")");
                             } else {
                                 // 3. Try coordinating multiple border armies or calling reinforcements to the border
                                 !try_coordinated_attack(ProvId, TargetStrength, TargetSoldiers, AvailableArmies, BorderingAllies);
                             }
                         }
                     } else {
                         // No bordering armies available: mobilize inland armies to the border or attack if already strong enough
                         .findall([Dist, AllyProv, MyId], (my_army(MyId, _, _, _, _, Loc) & not .member(Loc, BorderingAllies) & .member(AllyProv, BorderingAllies) & my_army_path_distance(MyId, AllyProv, Dist) & not is_defending_riot_province(MyId) & not my_army_travelling(MyId) & not (my_army_target(MyId, T) & T \== none & T \== "none")), InlandArmies);
                         if (InlandArmies \== []) {
                             .min(InlandArmies, [MinDist, TargetAllyProv, BestArmyId]);
                             ?my_army(BestArmyId, _, _, InlandLife, InlandAtk, _);
                             InlandSoldiers = InlandLife / LifePerUnit;
                             if (InlandSoldiers >= TargetSoldiers) {
                                 if (InlandSoldiers > TargetSoldiers + 2) {
                                     vesna.via.split_army(BestArmyId, TargetSoldiers, ProvId);
                                     .abolish(targeted_province(ProvId));
                                     +targeted_province(ProvId);
                                     .print("No bordering armies for ", ProvId, ". Split strong inland army ", BestArmyId, " sending ", TargetSoldiers, " soldiers to attack ", ProvId);
                                 } else {
                                     vesna.via.move_army(BestArmyId, ProvId);
                                     .abolish(my_army_travelling(BestArmyId));
                                     +my_army_travelling(BestArmyId);
                                     .abolish(my_army_target(BestArmyId, _));
                                     +my_army_target(BestArmyId, ProvId);
                                     .abolish(targeted_province(ProvId));
                                     +targeted_province(ProvId);
                                     .print("No bordering armies for ", ProvId, ". Sent strong inland army ", BestArmyId, " (", InlandSoldiers, " soldiers) to attack ", ProvId);
                                 }
                             } else {
                                 vesna.via.move_army(BestArmyId, TargetAllyProv);
                                 .abolish(my_army_travelling(BestArmyId));
                                 +my_army_travelling(BestArmyId);
                                 .abolish(my_army_target(BestArmyId, _));
                                 +my_army_target(BestArmyId, TargetAllyProv);
                                 .print("No bordering armies for ", ProvId, ". Sent inland army ", BestArmyId, " (", InlandSoldiers, " soldiers) to stage at border ", TargetAllyProv);
                             }
                         } else {
                             .print("No available inland armies to attack target province ", ProvId);
                         }
                     }
                 }
             }
         }
     }.

+!try_coordinated_attack(ProvId, TargetStrength, TargetSoldiers, AvailableArmies, BorderingAllies)
  <- !accumulate_attackers(ProvId, TargetStrength, TargetSoldiers, AvailableArmies, 0, [], BorderingAllies).

+!accumulate_attackers(ProvId, TargetStrength, TargetSoldiers, [], AccumulatedStrength, ChosenArmies, BorderingAllies)
  : AccumulatedStrength < TargetStrength
  <- .print("Adjacent armies not strong enough for attack on ", ProvId, " (Total: ", AccumulatedStrength, " vs Required: ", TargetStrength, "). Reinforcing border...");
     .findall([Dist, AllyProv, MyId], (my_army(MyId, _, _, Life, AtkVal, Loc) & not .member(Loc, BorderingAllies) & .member(AllyProv, BorderingAllies) & my_army_path_distance(MyId, AllyProv, Dist) & not is_defending_riot_province(MyId) & not my_army_travelling(MyId) & not (my_army_target(MyId, T) & T \== none & T \== "none")), InlandArmies);
     if (InlandArmies \== []) {
         .min(InlandArmies, [MinDist, TargetAllyProv, BestArmyId]);
         ?my_army(BestArmyId, _, _, InlandLife, InlandAtk, _);
         ?get_life_per_unit(LPU);
         InlandSoldiers = InlandLife / LPU;
         if (InlandSoldiers >= TargetSoldiers) {
             if (InlandSoldiers > TargetSoldiers + 2) {
                 vesna.via.split_army(BestArmyId, TargetSoldiers, ProvId);
                 .abolish(targeted_province(ProvId));
                 +targeted_province(ProvId);
                 .print("Split inland army ", BestArmyId, " to send ", TargetSoldiers, " soldiers directly to attack ", ProvId);
             } else {
                 vesna.via.move_army(BestArmyId, ProvId);
                 .abolish(my_army_travelling(BestArmyId));
                 +my_army_travelling(BestArmyId);
                 .abolish(my_army_target(BestArmyId, _));
                 +my_army_target(BestArmyId, ProvId);
                 .abolish(targeted_province(ProvId));
                 +targeted_province(ProvId);
                 .print("Sent strong inland army ", BestArmyId, " (", InlandSoldiers, " soldiers) directly to attack ", ProvId);
             }
         } else {
             vesna.via.move_army(BestArmyId, TargetAllyProv);
             .abolish(my_army_travelling(BestArmyId));
             +my_army_travelling(BestArmyId);
             .abolish(my_army_target(BestArmyId, _));
             +my_army_target(BestArmyId, TargetAllyProv);
             .print("Sent inland army ", BestArmyId, " (", InlandSoldiers, " soldiers, distance: ", MinDist, ") to reinforce border province ", TargetAllyProv);
         }
     } else {
         .print("No available inland armies to reinforce attack on ", ProvId);
     }.

+!accumulate_attackers(ProvId, TargetStrength, TargetSoldiers, _, AccumulatedStrength, ChosenArmies, _)
  : AccumulatedStrength >= TargetStrength
  <- .print("Sending coordinated attack to ", ProvId, " with armies ", ChosenArmies, " (Total Atk: ", AccumulatedStrength, " vs Required: ", TargetStrength, ")");
     .abolish(targeted_province(ProvId));
     +targeted_province(ProvId);
     for (.member(ArmyId, ChosenArmies)) {
         vesna.via.move_army(ArmyId, ProvId);
         .abolish(my_army_travelling(ArmyId));
         +my_army_travelling(ArmyId);
         .abolish(my_army_target(ArmyId, _));
         +my_army_target(ArmyId, ProvId);
     }.

+!accumulate_attackers(ProvId, TargetStrength, TargetSoldiers, [[Atk, ArmyId] | Rest], AccumulatedStrength, ChosenArmies, BorderingAllies)
  : AccumulatedStrength < TargetStrength
  <- !accumulate_attackers(ProvId, TargetStrength, TargetSoldiers, Rest, AccumulatedStrength + Atk, [ArmyId | ChosenArmies], BorderingAllies).

+foreign_army_moving(ArmyId, Nation, PosX, PosY, NextX, NextY, TargetProv, AttackValue)
  <- .abolish(enemy_army_moving(ArmyId, Nation, _, _, _, _, _, _));
     if (TargetProv \== none & TargetProv \== "none") {
         +enemy_army_moving(ArmyId, Nation, PosX, PosY, NextX, NextY, TargetProv, AttackValue);
     };
     if (at_war_with(Nation) & TargetProv \== none & TargetProv \== "none" & allied_province(TargetProv, _, _, _, _, _, _)) {
         .print("Enemy army ", ArmyId, " of ", Nation, " moving towards my province ", TargetProv, " (Atk: ", AttackValue, ")");
         if (not ordered_to_defend(_, TargetProv)) {
             .findall([PathDist, MyId], (my_army(MyId, _, _, _, _, Loc) & my_army_path_distance(MyId, TargetProv, PathDist) & Loc \== TargetProv & not ordered_to_defend(MyId, _) & not is_defending_riot_province(MyId) & not my_army_travelling(MyId)), SafeArmies);
             .findall([PathDist, MyId], (my_army(MyId, _, _, _, _, Loc) & my_army_path_distance(MyId, TargetProv, PathDist) & Loc \== TargetProv & not ordered_to_defend(MyId, _) & is_defending_riot_province(MyId) & not my_army_travelling(MyId)), RiotArmies);
             
             ?get_life_per_unit(LifePerUnit);
             ?get_defense_per_unit(DefensePerUnit);
             RequiredSoldiers = (AttackValue * 1.2) / DefensePerUnit;
             SplitCount = RequiredSoldiers div 1 + 1;
             
             if (SafeArmies \== []) {
                 .min(SafeArmies, [MinDist, BestArmyId]);
                 ?my_army(BestArmyId, _, _, Life, _, _);
                 Soldiers = Life / LifePerUnit;
                 if (Soldiers > SplitCount + 2) {
                     vesna.via.split_army(BestArmyId, SplitCount, TargetProv);
                     .abolish(ordered_to_defend(BestArmyId, _));
                     +ordered_to_defend(BestArmyId, TargetProv);
                     .abolish(targeted_province(TargetProv));
                     +targeted_province(TargetProv);
                     .print("Split safe army ", BestArmyId, " to send ", SplitCount, " soldiers to defend province ", TargetProv, " (Path Dist: ", MinDist, ")");
                 } else {
                     .abolish(ordered_to_defend(BestArmyId, _));
                     +ordered_to_defend(BestArmyId, TargetProv);
                     vesna.via.move_army(BestArmyId, TargetProv);
                     .abolish(my_army_travelling(BestArmyId));
                     +my_army_travelling(BestArmyId);
                     .abolish(my_army_target(BestArmyId, _));
                     +my_army_target(BestArmyId, TargetProv);
                     .abolish(targeted_province(TargetProv));
                     +targeted_province(TargetProv);
                     .print("Sending closest safe army ", BestArmyId, " to defend province ", TargetProv, " (Path Dist: ", MinDist, ")");
                 }
             } else {
                 if (RiotArmies \== []) {
                     .min(RiotArmies, [MinDist, BestArmyId]);
                     ?my_army(BestArmyId, _, _, Life, _, _);
                     Soldiers = Life / LifePerUnit;
                     if (Soldiers > SplitCount + 2) {
                         vesna.via.split_army(BestArmyId, SplitCount, TargetProv);
                         .abolish(ordered_to_defend(BestArmyId, _));
                         +ordered_to_defend(BestArmyId, TargetProv);
                         .abolish(targeted_province(TargetProv));
                         +targeted_province(TargetProv);
                         .print("Split riot-guarding army ", BestArmyId, " to send ", SplitCount, " soldiers to defend province ", TargetProv, " (Path Dist: ", MinDist, ") as a last resort");
                     } else {
                         .abolish(ordered_to_defend(BestArmyId, _));
                         +ordered_to_defend(BestArmyId, TargetProv);
                         vesna.via.move_army(BestArmyId, TargetProv);
                         .abolish(my_army_travelling(BestArmyId));
                         +my_army_travelling(BestArmyId);
                         .abolish(my_army_target(BestArmyId, _));
                         +my_army_target(BestArmyId, TargetProv);
                         .abolish(targeted_province(TargetProv));
                         +targeted_province(TargetProv);
                         .print("Sending closest riot-guarding army ", BestArmyId, " to defend province ", TargetProv, " (Path Dist: ", MinDist, ") as a last resort");
                     }
                 }
             }
         }
     };
     !evaluate_defenses.

+foreign_army_destroyed_update(Id, Nation)
  : Nation \== unknown
  <- .abolish(enemy_army_moving(Id, Nation, _, _, _, _, _, _));
     !evaluate_defenses.

+foreign_army_destroyed_update(Id, unknown)
  <- .abolish(enemy_army_moving(Id, _, _, _, _, _, _, _));
     !evaluate_defenses.

+!evaluate_defenses : true
  <- for (ordered_to_defend(MyId, ProvId)) {
         if (not province_under_threat(ProvId)) {
             .abolish(ordered_to_defend(MyId, ProvId));
             .abolish(my_army_target(MyId, _));
             .abolish(my_army_travelling(MyId));
             .print("Threat to ", ProvId, " is gone. Released defending army ", MyId);
         }
     }.

+active_wars(Count) <- true.

+!check_eliminated_nations : true
  <- .my_name(Me);
     for (at_war_with(Nation)) {
         if (Nation \== Me & not enemy_province_status(_, Nation, _, _, _, _, _, _, _, _)) {
             .abolish(at_war_with(Nation));
             .abolish(war_target(Nation, _));
             .abolish(sent_peace_request(Nation));
             .abolish(peace_request_received(Nation));
             .abolish(sent_alliance_request(Nation));
             .abolish(accepting_alliance(Nation));
             .abolish(allied_with(Nation));
             .abolish(allies(Nation, _));
             .abolish(allies(_, Nation));
             .abolish(alliance_declined(Nation));
             .abolish(neighbor_resource(Nation, _, _));
             .count(at_war_with(_), WarCount);
             .abolish(active_wars(_));
             +active_wars(WarCount);
             .print("Nation ", Nation, " has no remaining territories and is eliminated. War and diplomatic ties cleared.");
         }
     };
     for (allied_with(Nation)) {
         if (Nation \== Me & not enemy_province_status(_, Nation, _, _, _, _, _, _, _, _)) {
             .abolish(allied_with(Nation));
             .abolish(allies(Nation, _));
             .abolish(allies(_, Nation));
             .abolish(sent_alliance_request(Nation));
             .abolish(accepting_alliance(Nation));
             .abolish(neighbor_resource(Nation, _, _));
             .print("Allied nation ", Nation, " has no remaining territories and is eliminated.");
         }
     };
     for (neighbor_resource(Nation, _, _)) {
         if (Nation \== Me & not enemy_province_status(_, Nation, _, _, _, _, _, _, _, _)) {
             .abolish(neighbor_resource(Nation, _, _));
         }
     }.

+!periodic_evaluation : true
  <- !check_eliminated_nations;
     !evaluate_defenses;
     !optimize_riot_garrisons;
     !evaluate_targets;
     !evaluate_attack_opportunities;
     !garrison_non_allied_borders;
     !check_peace_requests;
     !check_alliance_opportunities;
     .wait(5000);
     !!periodic_evaluation.

+!garrison_non_allied_borders : true
  <- ?get_life_per_unit(LifePerUnit);
     for (my_army(MyId, _, _, Life, _, Loc)) {
         if (not my_army_travelling(MyId) & 
             not ordered_to_defend(MyId, _) & 
             not is_defending_riot_province(MyId) & 
             not (my_army_target(MyId, T) & T \== none & T \== "none")) {
             
             ArmySoldiers = (Life / LifePerUnit) div 1;
             
             if (not is_border_province(Loc) & ArmySoldiers > 0) {
                 .findall([Score, BorderProv], (is_border_province(BorderProv) & 
                                                BorderProv \== Loc &
                                                province_garrison_deficit(BorderProv, Deficit) & 
                                                Deficit > 0 & 
                                                my_army_path_distance(MyId, BorderProv, Dist) & 
                                                Dist < 999999.0 & 
                                                Score = -Deficit + (Dist * 0.05)), OptionList);
                 if (OptionList \== []) {
                     .min(OptionList, [MinScore, SelectedProv]);
                     vesna.via.move_army(MyId, SelectedProv);
                     .abolish(my_army_travelling(MyId));
                     +my_army_travelling(MyId);
                     .abolish(my_army_target(MyId, _));
                     +my_army_target(MyId, SelectedProv);
                     .print("Garrisoning border: Moving entire idle inland army ", MyId, " (", ArmySoldiers, " soldiers) from ", Loc, " to deficit border ", SelectedProv);
                 } else {
                     .findall([Score, BorderProv], (is_border_province(BorderProv) & 
                                                    BorderProv \== Loc &
                                                    my_army_path_distance(MyId, BorderProv, Dist) & 
                                                    Dist < 999999.0 & 
                                                    province_soldiers(BorderProv, OurSoldiers) & 
                                                    Score = OurSoldiers + (Dist * 0.05)), AlliedOptionList);
                     if (AlliedOptionList \== []) {
                         .min(AlliedOptionList, [MinScore, SelectedProv]);
                         vesna.via.move_army(MyId, SelectedProv);
                         +my_army_travelling(MyId);
                         +my_army_target(MyId, SelectedProv);
                         .print("Garrisoning border: Moving entire idle inland army ", MyId, " (", ArmySoldiers, " soldiers) from ", Loc, " to safe border ", SelectedProv);
                     }
                 }
             } else {
                 if (is_border_province(Loc)) {
                     ?province_excess_soldiers(Loc, Excess);
                     if (Excess >= 6 & ArmySoldiers >= 6) {
                         .findall([Score, BorderProv], (is_border_province(BorderProv) & 
                                                        BorderProv \== Loc &
                                                        province_garrison_deficit(BorderProv, Deficit) & 
                                                        Deficit >= 6 & 
                                                        my_army_path_distance(MyId, BorderProv, Dist) & 
                                                        Dist < 999999.0 & 
                                                        Score = -Deficit + (Dist * 0.05)), BorderOptionList);
                         if (BorderOptionList \== []) {
                             .min(BorderOptionList, [MinScore, SelectedProv]);
                             ?province_garrison_deficit(SelectedProv, DeficitVal);
                             SendAmount = math.min(Excess, math.min(DeficitVal, ArmySoldiers - 2)) div 1;
                             if (SendAmount >= 5) {
                                 vesna.via.split_army(MyId, SendAmount, SelectedProv);
                                 .print("Garrisoning border: Split large surplus at border ", Loc, " (army ", MyId, "), sending ", SendAmount, " soldiers to border ", SelectedProv);
                             }
                         }
                     }
                 }
             }
         }
     }.

+!check_peace_requests : true
   <- .my_name(Me);
      ?total_enemy_strength(Me, TotalEnemyStrength);
      ?alliance_strength(Me, MyStrength);
      .count(allied_with(_), AllyCount);
      MaxWars = 1 + AllyCount;
      .findall(Enemy, at_war_with(Enemy), EnemyList);
      .findall(Rep, is_war_block_representative(Rep), WarBlockList);
      .length(WarBlockList, WarCount);
      
      if (WarCount > MaxWars & TotalEnemyStrength > MyStrength * 1.5) {
          // Overwhelmed by wars exceeding alliance capacity: choose an enemy to make peace with
          !choose_enemy_for_peace(EnemyList, EnemyToRequest);
          if (EnemyToRequest \== none & not sent_peace_request(EnemyToRequest)) {
              !send_peace_request_to_all(EnemyToRequest, "overwhelmed on multiple fronts");
          }
      } else {
          for (.member(Enemy, EnemyList)) {
              if (not (needs_war_with(Enemy) & can_sustain_war_against(Enemy)) & not sent_peace_request(Enemy)) {
                  !send_peace_request_to_all(Enemy, "no strategic desire or capacity for war");
              }
          }
      }.

+!choose_enemy_for_peace([], none).
+!choose_enemy_for_peace(EnemyList, EnemyToRequest)
  : EnemyList \== []
  <- .findall([Priority, MinusStrength, Enemy], 
              (.member(Enemy, EnemyList) & 
               get_enemy_peace_priority(Enemy, Priority) & 
               alliance_strength(Enemy, Strength) & 
               MinusStrength = -Strength), Options);
     if (Options \== []) {
         .min(Options, [_, _, EnemyToRequest]);
     } else {
         EnemyToRequest = none;
     }.

+!send_peace_request_to_all(Enemy, Reason) : true
  <- .findall(Ally, (are_allied(Enemy, Ally) & at_war_with(Ally)), WarAllies);
     Targets = [Enemy | WarAllies];
     for (.member(T, Targets)) {
         if (not sent_peace_request(T)) {
             .abolish(sent_peace_request(T));
             +sent_peace_request(T);
             vesna.via.request_peace(T);
             .print("Sent peace request to ", T, " (Reason: ", Reason, ")");
         }
     }.

+!check_alliance_opportunities : true
  <- ?get_max_alliances(MaxAlliances);
     .count(allied_with(_), AllyCount);
     .count(sent_alliance_request(_), SentCount);
     .count(accepting_alliance(_), AcceptingCount);
     if (AllyCount < MaxAlliances & SentCount < MaxAlliances & AcceptingCount < MaxAlliances) {
         .findall([Strength, Neighbor], (neighbor_resource(Neighbor, _, _) & not at_war_with(Neighbor) & not allied_with(Neighbor) & not plans_to_attack(Neighbor) & not sent_alliance_request(Neighbor) & not alliance_declined(Neighbor) & nation_strength(Neighbor, Strength)), CandidateAllies);
         if (CandidateAllies \== []) {
             .max(CandidateAllies, [BestStrength, _]);
             .findall(Candidate, .member([BestStrength, Candidate], CandidateAllies), RawTopCandidates);
             .union(RawTopCandidates, [], TopCandidates);
             .shuffle(TopCandidates, ShuffledCandidates);
             ShuffledCandidates = [BestNeighbor | _];
             .abolish(sent_alliance_request(BestNeighbor));
             +sent_alliance_request(BestNeighbor);
             vesna.via.request_alliance(BestNeighbor);
             .print("Sent alliance request to strongest neighbour ", BestNeighbor, " (Strength: ", BestStrength, "%)");
         }
     }.

+!optimize_riot_garrisons : true
  <- ?get_riot_threshold(RiotThreshold);
     ?get_riot_breakpoint(RiotBreakpoint);
     ?get_riot_base_defense(RiotBaseDefense);
     ?get_riot_penalty_multiplier(RiotPenaltyMultiplier);
     ?get_life_per_unit(LifePerUnit);
     ?get_defense_per_unit(DefensePerUnit);
     for (my_army(MyId, _, _, Life, _, Loc)) {
         if (not my_army_travelling(MyId) & not ordered_to_defend(MyId, _) & not (my_army_target(MyId, T) & T \== none & T \== "none")) {
             if (allied_province(Loc, Morale, _, _, _, _, _) & Morale < RiotThreshold) {
                 if (Morale >= RiotBreakpoint) {
                     RiotRequired = RiotBaseDefense / DefensePerUnit;
                 } else {
                     RiotRequired = (RiotBaseDefense + (RiotBreakpoint - Morale) * RiotPenaltyMultiplier) / DefensePerUnit;
                 };
                 ?target_garrison(Loc, BorderTarget);
                 KeepRequired = math.max(RiotRequired, BorderTarget);
                 Soldiers = Life / LifePerUnit;
                 if (Soldiers > KeepRequired + 2) {
                     SplitCount = (Soldiers - KeepRequired) div 1;
                     !find_destination_for_excess_garrison(Loc, TargetProv);
                     if (TargetProv \== none) {
                         vesna.via.split_army(MyId, SplitCount, TargetProv);
                         .print("Split army ", MyId, " at low-morale province ", Loc, ": keeping ", KeepRequired, " soldiers (Riot: ", RiotRequired, ", Border: ", BorderTarget, "), sending ", SplitCount, " to allied ", TargetProv);
                     }
                 }
             }
         }
     }.

+!find_destination_for_excess_garrison(Loc, TargetProv)
  <- ?get_riot_threshold(RiotThreshold);
     ?allied_province(Loc, _, LocX, LocY, _, _, _);
     // 1. Prioritize a border province that has an active garrison deficit and safe morale
     .findall([Score, BorderProv], 
              (is_border_province(BorderProv) & 
               BorderProv \== Loc & 
               allied_province(BorderProv, BMorale, BX, BY, _, _, _) & 
               BMorale >= RiotThreshold & 
               province_garrison_deficit(BorderProv, Deficit) & 
               Deficit > 0 & 
               Dist = (LocX - BX)**2 + (LocY - BY)**2 & 
               Score = -Deficit + (Dist * 0.0001)), DeficitBorderOptions);
     if (DeficitBorderOptions \== []) {
         .min(DeficitBorderOptions, [_, TargetProv]);
     } else {
         // 2. Otherwise find the closest safe allied province (morale >= RiotThreshold)
         .findall([Dist, ProvId], 
                  (allied_province(ProvId, Morale, PX, PY, _, _, _) & 
                   ProvId \== Loc & 
                   Morale >= RiotThreshold & 
                   Dist = (LocX - PX)**2 + (LocY - PY)**2), SafeAlliedDists);
         if (SafeAlliedDists \== []) {
             .min(SafeAlliedDists, [MinDist, TargetProv]);
         } else {
             TargetProv = none;
         }
     }.


+!retreat_army(ArmyId, Reason) : true
  <- !find_retreat_province(ArmyId, RetreatProv);
     if (RetreatProv \== none) {
         .abolish(my_army_target(ArmyId, _));
         +my_army_target(ArmyId, RetreatProv);
         .abolish(my_army_travelling(ArmyId));
         +my_army_travelling(ArmyId);
         vesna.via.move_army(ArmyId, RetreatProv);
         .print("Mind decision: Army ", ArmyId, " retreating to safe allied province ", RetreatProv, " (Reason: ", Reason, ")");
     } else {
         .print("Mind decision: Army ", ArmyId, " needs to retreat, but no allied province found.");
     }.

+!find_retreat_province(ArmyId, RetreatProv) : true
  <- .findall([Dist, ProvId], (allied_province(ProvId, _, _, _, _, _, _) & my_army_path_distance(ArmyId, ProvId, Dist) & Dist < 999999.0), Options);
     if (Options \== []) {
         .min(Options, [_, RetreatProv]);
     } else {
         .findall([Dist, ProvId], (allied_province(ProvId, _, PX, PY, _, _, _) & my_army(ArmyId, _, AX, AY, _, _) & Dist = (AX - PX)**2 + (AY - PY)**2), FallbackOptions);
         if (FallbackOptions \== []) {
             .min(FallbackOptions, [_, RetreatProv]);
         } else {
             RetreatProv = none;
         }
     }.
