{ include("$jacamoJar/templates/common-cartago.asl") }
{ include("$jacamoJar/templates/common-moise.asl") }

target_limit(1).

// Default fallback game rules: RiotThreshold, RiotBreakpoint, RiotBaseDefense, RiotPenaltyMultiplier, LifePerUnit, AttackPerUnit, DefensePerUnit, MaxAlliances, ConqueredMorale
game_rules(33, 30, 5.0, 6.0, 20.0, 4.0, 5.0, 1, 25).

get_riot_threshold(Val) :- game_rules(Val, _, _, _, _, _, _, _, _).
get_riot_threshold(33).

get_riot_breakpoint(Val) :- game_rules(_, Val, _, _, _, _, _, _, _).
get_riot_breakpoint(30).

get_riot_base_defense(Val) :- game_rules(_, _, Val, _, _, _, _, _, _).
get_riot_base_defense(5.0).

get_riot_penalty_multiplier(Val) :- game_rules(_, _, _, Val, _, _, _, _, _).
get_riot_penalty_multiplier(6.0).

get_life_per_unit(Val) :- game_rules(_, _, _, _, Val, _, _, _, _).
get_life_per_unit(20.0).

get_attack_per_unit(Val) :- game_rules(_, _, _, _, _, Val, _, _, _).
get_attack_per_unit(4.0).

get_defense_per_unit(Val) :- game_rules(_, _, _, _, _, _, Val, _, _).
get_defense_per_unit(5.0).

get_max_alliances(Val) :- game_rules(_, _, _, _, _, _, _, Val, _).
get_max_alliances(1).

get_conquered_morale(Val) :- game_rules(_, _, _, _, _, _, _, _, Val).
get_conquered_morale(25).

province_under_threat(ProvId) :-
    enemy_army_moving(_, Nation, _, _, _, _, ProvId, _) &
    (at_war_with(Nation) | is_threat(Nation)).

list_member(X, [X | _]).
list_member(X, [_ | T]) :-
    list_member(X, T).

list_max([H], H).
list_max([H | T], H) :-
    list_max(T, TailMax) &
    H >= TailMax.
list_max([H | T], TailMax) :-
    list_max(T, TailMax) &
    H < TailMax.

list_sum([], 0).
list_sum([H | T], Sum) :-
    list_sum(T, TailSum) &
    Sum = H + TailSum.

total_enemy_strength(Me, TotalStrength) :-
    .findall(EnemyStrength, (at_war_with(Enemy) & alliance_strength(Enemy, EnemyStrength)), Strengths) &
    list_sum(Strengths, TotalStrength).

can_support_new_war(Me, TargetNation) :-
    alliance_strength(Me, MyStrength) &
    total_enemy_strength(Me, CurrentTotalEnemyStrength) &
    alliance_strength(TargetNation, TargetStrength) &
    CurrentTotalEnemyStrength + TargetStrength <= MyStrength * 1.5.

get_enemy_peace_priority(Enemy, 1) :- needs_war_with(Enemy).
get_enemy_peace_priority(Enemy, 0) :- not needs_war_with(Enemy).

is_border_province(AlliedProv) :-
    allied_province(AlliedProv, _, _, _, _, _, _) &
    enemy_province_status(_, Owner, _, _, _, _, BorderingAllies, _, _, _) &
    list_member(AlliedProv, BorderingAllies) &
    not allied_with(Owner).

province_soldiers(Prov, 0) :-
    not my_army(_, _, _, _, _, Prov).

province_soldiers(Prov, Count) :-
    my_army(_, _, _, _, _, Prov) &
    game_rules(_, _, _, _, LifePerUnit, _, _, _, _) &
    .findall(S, (my_army(_, _, _, Life, _, Prov) & S = Life / LifePerUnit), List) &
    list_sum(List, Count).

province_defense(Prov, 0) :-
    not my_army(_, _, _, _, _, Prov).

province_defense(Prov, Def) :-
    my_army(_, _, _, _, _, Prov) &
    game_rules(_, _, _, _, LifePerUnit, _, DefensePerUnit, _, _) &
    .findall(ArmyDef, (my_army(_, _, _, Life, _, Prov) & ArmyDef = Life * DefensePerUnit / LifePerUnit), List) &
    list_sum(List, Def).

nation_border_defense(BorderProv, Owner, SumDef) :-
    enemy_province_status(_, Owner, _, _, _, _, BorderingAllies, _, _, _) & 
    list_member(BorderProv, BorderingAllies) & 
    not allied_with(Owner) &
    .findall(EnemyDef, (enemy_province_status(FProv, Owner, _, EnemyDef, _, _, BAllies, _, _, _) & list_member(BorderProv, BAllies)), EnemyDefs) &
    list_sum(EnemyDefs, SumDef).

border_province_max_enemy_defense(BorderProv, 0) :-
    not (enemy_province_status(_, Owner, _, _, _, _, BorderingAllies, _, _, _) & list_member(BorderProv, BorderingAllies) & not allied_with(Owner)).

border_province_max_enemy_defense(BorderProv, MaxEnemyDef) :-
    enemy_province_status(_, Owner, _, _, _, _, BorderingAllies, _, _, _) & list_member(BorderProv, BorderingAllies) & not allied_with(Owner) &
    .findall(SumDef, (enemy_province_status(_, Own, _, _, _, _, BAllies, _, _, _) & list_member(BorderProv, BAllies) & not allied_with(Own) & nation_border_defense(BorderProv, Own, SumDef)), SumDefs) &
    list_max(SumDefs, MaxEnemyDef).

target_garrison(Prov, Target) :-
    is_border_province(Prov) &
    border_province_max_enemy_defense(Prov, EnemyDef) &
    game_rules(_, _, _, _, _, _, DefensePerUnit, _, _) &
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
    my_army_target(_, ProvId).

plans_to_attack(Nation) :-
    resource_trend(NeededResource, negative) &
    .findall(Amount, neighbor_resource(_, NeededResource, Amount), ListOfAmounts) &
    ListOfAmounts \== [] &
    .max(ListOfAmounts, MaxAmount) &
    neighbor_resource(Nation, NeededResource, MaxAmount).

needs_war_with(Enemy) :-
    resource_trend(NeededResource, negative) &
    neighbor_resource(Enemy, NeededResource, Amount) &
    Amount > 0.

are_allied(X, Y) :- allies(X, Y).
are_allied(X, Y) :- allies(Y, X).

is_war_block_representative(N) :-
    at_war_with(N) &
    not (at_war_with(O) & are_allied(N, O) & O < N).

alliance_strength(Nation, TotalStrength) :-
    .findall(Strength, (Nation = Member & nation_strength(Member, Strength)), SelfS) &
    .findall(Strength, (are_allied(Nation, Ally) & nation_strength(Ally, Strength)), AllyS) &
    .concat(SelfS, AllyS, AllS) &
    TotalStrength = math.sum(AllS).

remove_duplicates([], []).
remove_duplicates([Head | Tail], Result) :-
    .member(Head, Tail) &
    remove_duplicates(Tail, Result).
remove_duplicates([Head | Tail], [Head | Result]) :-
    not .member(Head, Tail) &
    remove_duplicates(Tail, Result).

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

+clear_my_armies <- 
    .abolish(my_army(_, _, _, _, _, _));
    .abolish(my_army_path_distance(_, _, _));
    .abolish(my_army_travelling(_));
    .abolish(my_army_target(_, _));
    .abolish(targeted_province(_)).
+clear_allied_provinces <- .abolish(allied_province(_, _, _, _, _, _, _)).
+clear_enemy_provinces <- .abolish(enemy_province_status(_, _, _, _, _, _, _, _, _, _)).
+clear_neighbor_nations <- .abolish(neighbor_resource(_, _, _)).
+clear_alliances <- .abolish(allies(_, _)).

+at_war_with_update(Nation)
  <- +at_war_with(Nation);
     -sent_alliance_request(Nation);
     -accepting_alliance(Nation);
     .count(at_war_with(_), Count);
     -active_wars(_);
     +active_wars(Count).

+peace_established_update(Nation)
  <- -at_war_with(Nation);
     -sent_peace_request(Nation);
     .abolish(war_target(Nation, _));
     .count(at_war_with(_), Count);
     -active_wars(_);
     +active_wars(Count);
     .print("Peace established with ", Nation).

+peace_request_received(Sender)
  <- .my_name(Me);
     ?total_enemy_strength(Me, TotalEnemyStrength);
     ?alliance_strength(Me, MyStrength);
     
     if (TotalEnemyStrength > MyStrength * 1.5) {
         .print("Accepting peace request from ", Sender, " (Total enemy strength too high: ", TotalEnemyStrength, " vs MyStrength * 1.5: ", MyStrength * 1.5, ")");
         vesna.via.accept_peace(Sender);
     } else {
         .findall(Rep, is_war_block_representative(Rep), RepList);
         .length(RepList, WarCount);
         ?alliance_strength(Sender, SenderStrength);
         if (WarCount > 1 & MyStrength - 10 < SenderStrength) {
             .print("Accepting peace request from ", Sender, " (Another war is in course: WarCount=", WarCount, ")");
             vesna.via.accept_peace(Sender);
         } else {
             if (not needs_war_with(Sender)) {
                 .print("Accepting peace request from ", Sender, " (Do not need their resources anymore)");
                 vesna.via.accept_peace(Sender);
             } else {
                 .print("Declining peace request from ", Sender, " (No other wars in course and we need their resources)");
                 vesna.via.decline_peace(Sender);
             }
         }
     }.

+peace_request_declined(Sender)
  <- -sent_peace_request(Sender);
     .print("Peace request to ", Sender, " was declined.").

+alliance_established_update(Nation)
  <- +allied_with(Nation);
     -sent_alliance_request(Nation);
     -accepting_alliance(Nation);
     .print("Alliance established with ", Nation).

+alliance_request_received(Sender)
  <- ?get_max_alliances(MaxAlliances);
     .count(allied_with(_), AllyCount);
     .count(sent_alliance_request(_), SentCount);
     .count(accepting_alliance(_), AcceptingCount);
     if (AllyCount < MaxAlliances & SentCount < MaxAlliances & AcceptingCount < MaxAlliances & not plans_to_attack(Sender) & not at_war_with(Sender) & not allied_with(Sender)) {
         +accepting_alliance(Sender);
         .print("Accepting alliance request from ", Sender);
         vesna.via.accept_alliance(Sender);
     } else {
         .print("Declining alliance request from ", Sender, " (Reason: AllyCount=", AllyCount, ", SentCount=", SentCount, ", AcceptingCount=", AcceptingCount, " or planning attack/war)");
         vesna.via.decline_alliance(Sender);
     }.

+alliance_request_declined(Sender)
  <- -sent_alliance_request(Sender);
     -accepting_alliance(Sender);
     +alliance_declined(Sender);
     .print("Alliance request to ", Sender, " was declined.").

+alliance_broken_update(Nation)
  <- -allied_with(Nation);
     .print("Alliance with ", Nation, " broken due to war!").

+neighbor_resource_update(Neighbor, Res, Amount)
  <- +neighbor_resource(Neighbor, Res, Amount).

+alliance_update(N1, N2)
  <- +allies(N1, N2).

+resource_update(Type, Amount) : resource(Type, OldAmount) & OldAmount > Amount
  <- -resource(Type, OldAmount);
     +resource(Type, Amount);
     -resource_trend(Type, _);
     +resource_trend(Type, negative).

+resource_update(Type, Amount) : resource(Type, OldAmount) & OldAmount <= Amount
  <- -resource(Type, OldAmount);
     +resource(Type, Amount);
     -resource_trend(Type, _);
     +resource_trend(Type, positive).

+resource_update(Type, Amount) : not resource(Type, _)
  <- +resource(Type, Amount);
     +resource_trend(Type, positive).

+my_army_update(Id, X, Y, Life, AttackValue, Loc)
  <- .abolish(my_army(Id, _, _, _, _, _));
     +my_army(Id, X, Y, Life, AttackValue, Loc);
     if (ordered_to_defend(Id, Loc)) {
         .abolish(ordered_to_defend(Id, Loc));
         .print("Army ", Id, " has arrived at and successfully defended ", Loc);
     }.

+allied_province_update(Id, Morale, X, Y, IsCapital, IsDouble, Resource)
  <- +allied_province(Id, Morale, X, Y, IsCapital, IsDouble, Resource).

+allied_province_owner_update(Id, Morale, X, Y, IsCapital, IsDouble, Resource)
  <- if (enemy_province_status(Id, PrevOwner, _, _, _, _, _, _, _, _)) {
         -war_target(PrevOwner, Id);
         if (at_war_with(PrevOwner)) {
             !select_war_target(PrevOwner, _);
         }
     };
     .abolish(allied_province(Id, _, _, _, _, _, _));
     .abolish(enemy_province_status(Id, _, _, _, _, _, _, _, _, _));
     -targeted_province(Id);
     +allied_province(Id, Morale, X, Y, IsCapital, IsDouble, Resource).

+my_army_distance_update(Id, ProvId, Dist)
  <- .abolish(my_army_path_distance(Id, ProvId, _));
     +my_army_path_distance(Id, ProvId, Dist).

+my_army_destroyed_update(Id)
  <- .abolish(my_army(Id, _, _, _, _, _));
     .abolish(my_army_path_distance(Id, _, _));
     .abolish(ordered_to_defend(Id, _));
     -my_army_travelling(Id);
     if (my_army_target(Id, TargetProv)) {
         -my_army_target(Id, TargetProv);
         if (not my_army_target(_, TargetProv)) {
             -targeted_province(TargetProv);
         }
     };
     .print("Army ", Id, " has been destroyed.").

+my_army_travelling_update(Id, "true")
  <- -my_army_travelling(Id);
     +my_army_travelling(Id).

+my_army_travelling_update(Id, "false")
  <- -my_army_travelling(Id).

+my_army_target_update(Id, "none")
  : my_army_target(Id, TargetProv)
  <- -my_army_target(Id, TargetProv);
     if (not my_army_target(_, TargetProv)) {
         -targeted_province(TargetProv);
     }.

+my_army_target_update(Id, "none")
  <- -my_army_target(Id, _).

+my_army_target_update(Id, TargetProv)
  : TargetProv \== "none"
  <- -my_army_target(Id, _);
     +my_army_target(Id, TargetProv);
     +targeted_province(TargetProv).

+enemy_province_update(Id, Owner, HasArmyStr, DefenseValue, X, Y, BorderingAllies, IsCapital, IsDouble, Resource)
  <- +enemy_province_status(Id, Owner, HasArmyStr, DefenseValue, X, Y, BorderingAllies, IsCapital, IsDouble, Resource).

+enemy_province_owner_update(Id, Owner, HasArmyStr, DefenseValue, X, Y, BorderingAllies, IsCapital, IsDouble, Resource)
  <- if (enemy_province_status(Id, PrevOwner, _, _, _, _, _, _, _, _)) {
         -war_target(PrevOwner, Id);
         if (at_war_with(PrevOwner)) {
             !select_war_target(PrevOwner, _);
         }
     };
     .abolish(allied_province(Id, _, _, _, _, _, _));
     .abolish(enemy_province_status(Id, _, _, _, _, _, _, _, _, _));
     -targeted_province(Id);
     +enemy_province_status(Id, Owner, HasArmyStr, DefenseValue, X, Y, BorderingAllies, IsCapital, IsDouble, Resource).

+province_morale_update(Id, Morale)
  <- if (allied_province(Id, OldMorale, X, Y, IsCapital, IsDouble, Resource)) {
         -allied_province(Id, OldMorale, X, Y, IsCapital, IsDouble, Resource);
         +allied_province(Id, Morale, X, Y, IsCapital, IsDouble, Resource);
     }.

+nation_strength_update(Nation, Strength)
  <- -nation_strength(Nation, _);
     +nation_strength(Nation, Strength).

+active_wars_update(Count)
  <- -active_wars(_);
     +active_wars(Count).

+day_cycle_update(Day)
  <- -day_cycle(_);
     +day_cycle(Day);
     .print("Current game day: ", Day);
     if (war_cooldown_end_day(EndDay) & Day >= EndDay) {
         -war_cooldown;
         -war_cooldown_end_day(EndDay);
         .print("War cooldown ended.");
      }.

+match_over <-
     .drop_all_intentions;
     .drop_all_desires;
     .drop_all_events;
     .print("Match over! Interrupted all goals and intentions.").

+game_rules_update(RiotThreshold, RiotBreakpoint, RiotBaseDefense, RiotPenaltyMultiplier, LifePerUnit, AttackPerUnit, DefensePerUnit, MaxAlliances, ConqueredMorale)
  <- .abolish(game_rules(_, _, _, _, _, _, _, _, _));
     +game_rules(RiotThreshold, RiotBreakpoint, RiotBaseDefense, RiotPenaltyMultiplier, LifePerUnit, AttackPerUnit, DefensePerUnit, MaxAlliances, ConqueredMorale).

+!evaluate_targets : true
  <- for (resource_trend(NeededResource, negative)) {
         .findall(Amount, neighbor_resource(Neighbor, NeededResource, Amount), ListOfAmounts);
         if (ListOfAmounts \== []) {
             .max(ListOfAmounts, MaxAmount);
             ?neighbor_resource(BestNeighbor, NeededResource, MaxAmount);
             if (not at_war_with(BestNeighbor) & not allied_with(BestNeighbor)) {
                 !decide_attack(BestNeighbor, NeededResource);
             }
         }
     }.

+!decide_attack(TargetNation, NeededResource)
  : not at_war_with(TargetNation)
    & not allied_with(TargetNation)
    & not war_cooldown
    & active_wars(W) & W < 1 
    & .my_name(Me)
    & can_support_new_war(Me, TargetNation)
    & needs_war_with(TargetNation)
  <- .my_name(Me);
     if (alliance_strength(Me, MyStrengthPercentage) & alliance_strength(TargetNation, TargetStrengthPercentage)) {
         if (MyStrengthPercentage >= TargetStrengthPercentage) {
             vesna.via.declare_war(TargetNation);
             +at_war_with(TargetNation);
             +war_cooldown;
             if (day_cycle(CurrentDay)) {
                 CooldownEndDay = CurrentDay + 1;
             } else {
                 CooldownEndDay = 2;
             };
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
         .min(Options, [MinScore, BestProv]);
         +war_target(EnemyNation, BestProv);
         .print("Selected target province ", BestProv, " of ", EnemyNation, " with priority score ", MinScore);
     }.

+!evaluate_attack_opportunities : true
  <- for(at_war_with(EnemyNation)) {
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
                     .findall([AttackValue, MyId], (my_army(MyId, _, _, Life, AttackValue, Loc) & .member(Loc, BorderingAllies) & not is_defending_riot_province(MyId) & not my_army_travelling(MyId)), AvailableArmies);
                     if (AvailableArmies \== []) {
                         if (EnemyDefenseValue == 0) {
                             .max(AvailableArmies, [MaxAttackValue, BestArmyId]);
                             ?my_army(BestArmyId, _, _, BestLife, _, _);
                             ?get_riot_breakpoint(RiotBreakpoint);
                             ?get_riot_base_defense(RiotBaseDefense);
                             ?get_riot_penalty_multiplier(RiotPenaltyMultiplier);
                             ?get_life_per_unit(LifePerUnit);
                             ?get_defense_per_unit(DefensePerUnit);
                             ?get_conquered_morale(ConqueredMorale);
                             BestSoldiers = BestLife / LifePerUnit;
                             RequiredGarrison = (RiotBaseDefense + (RiotBreakpoint - ConqueredMorale) * RiotPenaltyMultiplier) / DefensePerUnit;
                             SplitCount = RequiredGarrison div 1;
                             if (BestSoldiers > SplitCount + 1) {
                                 vesna.via.split_army(BestArmyId, SplitCount, ProvId);
                                 +targeted_province(ProvId);
                                 .print("Split army ", BestArmyId, " to send ", SplitCount, " soldiers to target province ", ProvId, " (morale will be ", ConqueredMorale, "%)");
                             } else {
                                 vesna.via.move_army(BestArmyId, ProvId);
                                 +my_army_travelling(BestArmyId);
                                 +my_army_target(BestArmyId, ProvId);
                                 +targeted_province(ProvId);
                                 .print("Sent army ", BestArmyId, " from border to target province ", ProvId);
                             }
                         } else {
                             ?get_life_per_unit(LifePerUnit);
                             ?get_attack_per_unit(AttackPerUnit);
                             TargetStrength = EnemyDefenseValue * 1.2;
                             TargetSoldiers = (TargetStrength / AttackPerUnit) div 1 + 1;
                             
                             .findall([Soldiers, MyId], (.member([AttackVal, MyId], AvailableArmies) & my_army(MyId, _, _, Life, _, _) & Soldiers = Life / LifePerUnit & Soldiers > TargetSoldiers + 2), SplittableArmies);
                             if (SplittableArmies \== []) {
                                 .max(SplittableArmies, [MaxSoldiers, BestArmyId]);
                                 SplitCount = TargetSoldiers;
                                 vesna.via.split_army(BestArmyId, SplitCount, ProvId);
                                 +targeted_province(ProvId);
                                 .print("Split army ", BestArmyId, " to send ", SplitCount, " soldiers (Atk: ", SplitCount * AttackPerUnit, ") to target province ", ProvId, " (Def: ", EnemyDefenseValue, ")");
                             } else {
                                 !try_coordinated_attack(ProvId, EnemyDefenseValue, AvailableArmies);
                             }
                         }
                     } else {
                         .findall([Dist, MyId], (my_army(MyId, _, _, _, _, Loc) & .member(AllyProv, BorderingAllies) & my_army_path_distance(MyId, AllyProv, Dist) & not is_defending_riot_province(MyId) & not my_army_travelling(MyId)), InlandArmies);
                         if (InlandArmies \== []) {
                             .min(InlandArmies, [MinDist, BestArmyId]);
                             vesna.via.move_army(BestArmyId, ProvId);
                             +my_army_travelling(BestArmyId);
                             +my_army_target(BestArmyId, ProvId);
                             +targeted_province(ProvId);
                             .print("No bordering armies for ", ProvId, ". Sent closest inland army ", BestArmyId, " (distance: ", MinDist, ") to attack");
                         } else {
                             .print("No available inland armies to attack target province ", ProvId);
                         }
                     }
                 }
             }
         }
     }.

+!try_coordinated_attack(ProvId, EnemyDefenseValue, AvailableArmies)
  <- TargetStrength = EnemyDefenseValue * 1.2;
     !accumulate_attackers(ProvId, TargetStrength, AvailableArmies, 0, []).

+!accumulate_attackers(ProvId, TargetStrength, [], AccumulatedStrength, ChosenArmies)
  : AccumulatedStrength <= TargetStrength
  <- .print("Adjacent armies not strong enough for coordinated attack on ", ProvId, " (Total: ", AccumulatedStrength, " vs Required: ", TargetStrength, "). Looking for inland armies...");
     if (enemy_province_status(ProvId, _, _, _, _, _, BorderingAllies, _, _, _)) {
         .findall([Dist, MyId], (my_army(MyId, _, _, _, _, Loc) & .member(AllyProv, BorderingAllies) & my_army_path_distance(MyId, AllyProv, Dist) & not is_defending_riot_province(MyId) & not my_army_travelling(MyId)), InlandArmies);
         if (InlandArmies \== []) {
             .min(InlandArmies, [MinDist, BestArmyId]);
             vesna.via.move_army(BestArmyId, ProvId);
             +my_army_travelling(BestArmyId);
             +my_army_target(BestArmyId, ProvId);
             +targeted_province(ProvId);
             .print("Sent closest inland army ", BestArmyId, " (distance: ", MinDist, ") to reinforce/attack ", ProvId);
         } else {
             .print("No available inland armies to reinforce attack on ", ProvId);
         }
     }.

+!accumulate_attackers(ProvId, TargetStrength, _, AccumulatedStrength, ChosenArmies)
  : AccumulatedStrength > TargetStrength
  <- .print("Sending coordinated attack to ", ProvId, " with armies ", ChosenArmies, " (Total Atk: ", AccumulatedStrength, ")");
     +targeted_province(ProvId);
     for (.member(ArmyId, ChosenArmies)) {
         vesna.via.move_army(ArmyId, ProvId);
         +my_army_travelling(ArmyId);
         +my_army_target(ArmyId, ProvId);
     }.

+!accumulate_attackers(ProvId, TargetStrength, [[Atk, ArmyId] | Rest], AccumulatedStrength, ChosenArmies)
  : AccumulatedStrength <= TargetStrength
  <- !accumulate_attackers(ProvId, TargetStrength, Rest, AccumulatedStrength + Atk, [ArmyId | ChosenArmies]).

+foreign_army_moving(ArmyId, Nation, PosX, PosY, NextX, NextY, TargetProv, AttackValue)
  <- .abolish(enemy_army_moving(ArmyId, _, _, _, _, _, _, _));
     if (TargetProv \== none) {
         +enemy_army_moving(ArmyId, Nation, PosX, PosY, NextX, NextY, TargetProv, AttackValue);
     };
     if ((at_war_with(Nation) | is_threat(Nation)) & TargetProv \== none & allied_province(TargetProv, _, _, _, _, _, _)) {
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
                     .print("Split safe army ", BestArmyId, " to send ", SplitCount, " soldiers to defend province ", TargetProv, " (Path Dist: ", MinDist, ")");
                 } else {
                     .abolish(ordered_to_defend(BestArmyId, _));
                     +ordered_to_defend(BestArmyId, TargetProv);
                     vesna.via.move_army(BestArmyId, TargetProv);
                     +my_army_travelling(BestArmyId);
                     +my_army_target(BestArmyId, TargetProv);
                     .print("Sending closest safe army ", BestArmyId, " to defend province ", TargetProv, " (Path Dist: ", MinDist, ")");
                 }
             } else {
                 if (RiotArmies \== []) {
                     .min(RiotArmies, [MinDist, BestArmyId]);
                     ?my_army(BestArmyId, _, _, Life, _, _);
                     Soldiers = Life / LifePerUnit;
                     if (Soldiers > SplitCount + 2) {
                         vesna.via.split_army(BestArmyId, SplitCount, TargetProv);
                         .print("Split riot-guarding army ", BestArmyId, " to send ", SplitCount, " soldiers to defend province ", TargetProv, " (Path Dist: ", MinDist, ") as a last resort");
                     } else {
                         .abolish(ordered_to_defend(BestArmyId, _));
                         +ordered_to_defend(BestArmyId, TargetProv);
                         vesna.via.move_army(BestArmyId, TargetProv);
                         +my_army_travelling(BestArmyId);
                         +my_army_target(BestArmyId, TargetProv);
                         .print("Sending closest riot-guarding army ", BestArmyId, " to defend province ", TargetProv, " (Path Dist: ", MinDist, ") as a last resort");
                     }
                 }
             }
         }
     };
     !evaluate_defenses.

+foreign_army_destroyed_update(Id)
  <- .abolish(enemy_army_moving(Id, _, _, _, _, _, _, _));
     !evaluate_defenses.

+!evaluate_defenses : true
  <- for (ordered_to_defend(MyId, ProvId)) {
         if (not province_under_threat(ProvId)) {
             .abolish(ordered_to_defend(MyId, ProvId));
             -my_army_target(MyId, ProvId);
             -my_army_travelling(MyId);
             .print("Threat to ", ProvId, " is gone. Released defending army ", MyId);
         }
     }.

+!find_closest_province(TargetX, TargetY, ClosestProv)
  <- .findall([Dist, ProvId], (allied_province(ProvId, _, ProvX, ProvY, _, _, _) & Dist = (TargetX - ProvX)**2 + (TargetY - ProvY)**2), Distances);
     if (Distances \== []) {
         .min(Distances, [MinDist, ClosestProv]);
     } else {
         ?allied_province(ClosestProv, _, _, _, _, _, _);
     }.

+active_wars(Count) : not evaluation_loop_started
  <- +evaluation_loop_started;
     !evaluate_defenses;
     !optimize_riot_garrisons;
     !evaluate_targets;
     !evaluate_attack_opportunities;
     !garrison_non_allied_borders;
     !check_peace_requests;
     !check_alliance_opportunities;
     !!periodic_evaluation.

+active_wars(Count) : evaluation_loop_started
  <- !evaluate_defenses;
     !optimize_riot_garrisons;
     !evaluate_targets;
     !evaluate_attack_opportunities;
     !garrison_non_allied_borders;
     !check_peace_requests;
     !check_alliance_opportunities.

+!periodic_evaluation : true
  <- !evaluate_defenses;
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
             not my_army_target(MyId, _)) {
             
             ?province_excess_soldiers(Loc, Excess);
             if (Excess > 0) {
                 .findall([Score, BorderProv], (is_border_province(BorderProv) & 
                                                province_garrison_deficit(BorderProv, Deficit) & 
                                                Deficit > 0 & 
                                                my_army_path_distance(MyId, BorderProv, Dist) & 
                                                Dist < 999999.0 & 
                                                Score = -Deficit + (Dist * 0.05)), OptionList);
                 if (OptionList \== []) {
                     .min(OptionList, [MinScore, SelectedProv]);
                     ?province_garrison_deficit(SelectedProv, DeficitVal);
                     
                     if (Excess < DeficitVal) {
                         Amount = Excess;
                     } else {
                         Amount = DeficitVal;
                     };
                     
                     SplitCount = Amount div 1;
                     ArmySoldiers = Life / LifePerUnit;
                     if (SplitCount > 0) {
                         if (SplitCount < ArmySoldiers) {
                             vesna.via.split_army(MyId, SplitCount, SelectedProv);
                             .print("Garrisoning border: Split idle army ", MyId, " at ", Loc, " sending ", SplitCount, " soldiers to deficit border ", SelectedProv);
                         } else {
                             vesna.via.move_army(MyId, SelectedProv);
                             +my_army_travelling(MyId);
                             +my_army_target(MyId, SelectedProv);
                             .print("Garrisoning border: Moving entire idle army ", MyId, " from ", Loc, " to deficit border ", SelectedProv);
                         }
                     }
                 } else {
                     if (not is_border_province(Loc)) {
                         .findall([Score, BorderProv], (is_border_province(BorderProv) & 
                                                        my_army_path_distance(MyId, BorderProv, Dist) & 
                                                        Dist < 999999.0 & 
                                                        province_soldiers(BorderProv, OurSoldiers) & 
                                                        Score = OurSoldiers + (Dist * 0.05)), AlliedOptionList);
                         if (AlliedOptionList \== []) {
                             .min(AlliedOptionList, [MinScore, SelectedProv]);
                             vesna.via.move_army(MyId, SelectedProv);
                             +my_army_travelling(MyId);
                             +my_army_target(MyId, SelectedProv);
                             .print("Garrisoning border: Moving idle inland army ", MyId, " from ", Loc, " to safe border ", SelectedProv, " with score ", MinScore);
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
     
     if (TotalEnemyStrength > MyStrength * 1.5) {
         // We cannot support all these wars! We must choose one enemy to request peace from.
         .findall(Enemy, at_war_with(Enemy), EnemyList);
         !choose_enemy_for_peace(EnemyList, EnemyToRequest);
         if (EnemyToRequest \== none) {
             !send_peace_request_to_all(EnemyToRequest, "total enemy strength too high");
         }
     } else {
         for (at_war_with(Enemy)) {
             if (not needs_war_with(Enemy) & not sent_peace_request(Enemy)) {
                 !send_peace_request_to_all(Enemy, "resources not needed");
             } else {
                 if (alliance_strength(Enemy, EnemyStrengthPercentage)) {
                     if (EnemyStrengthPercentage > MyStrength * 1.5 & not sent_peace_request(Enemy)) {
                         !send_peace_request_to_all(Enemy, "enemy is a lot stronger");
                     }
                 }
             }
         }
     }.

+!choose_enemy_for_peace([], none).
+!choose_enemy_for_peace(EnemyList, EnemyToRequest)
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
         .findall(Neighbor, (neighbor_resource(Neighbor, _, _) & not at_war_with(Neighbor) & not allied_with(Neighbor) & not plans_to_attack(Neighbor) & not sent_alliance_request(Neighbor) & not alliance_declined(Neighbor)), Neighbors);
         if (Neighbors \== []) {
             Neighbors = [BestNeighbor | _];
             +sent_alliance_request(BestNeighbor);
             vesna.via.request_alliance(BestNeighbor);
             .print("Sent alliance request to neighbour ", BestNeighbor);
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
         if (allied_province(Loc, Morale, _, _, _, _, _) & Morale < RiotThreshold) {
             if (Morale >= RiotBreakpoint) {
                 Required = RiotBaseDefense / DefensePerUnit;
             } else {
                 Required = (RiotBaseDefense + (RiotBreakpoint - Morale) * RiotPenaltyMultiplier) / DefensePerUnit;
             }
             Soldiers = Life / LifePerUnit;
             if (Soldiers > Required + 2) {
                 SplitCount = (Soldiers - Required) div 1;
                 !find_neighboring_province(Loc, TargetProv);
                 if (TargetProv \== none) {
                     vesna.via.split_army(MyId, SplitCount, TargetProv);
                     .print("Split army ", MyId, " at low-morale province ", Loc, ": keeping ", Required, " soldiers, sending ", SplitCount, " to ", TargetProv);
                 }
             }
         }
     }.

+!find_neighboring_province(Loc, TargetProv)
  <- ?allied_province(Loc, _, LocX, LocY, _, _, _);
     .findall([Dist, ProvId], (allied_province(ProvId, _, PX, PY, _, _, _) & ProvId \== Loc & Dist = (LocX - PX)**2 + (LocY - PY)**2), AlliedDists);
     .findall([Dist, ProvId], (enemy_province_status(ProvId, _, _, _, PX, PY, _, _, _, _) & Dist = (LocX - PX)**2 + (LocY - PY)**2), EnemyDists);
     .concat(AlliedDists, EnemyDists, AllDists);
     if (AllDists \== []) {
         .min(AllDists, [MinDist, TargetProv]);
     } else {
         TargetProv = none;
     }.
