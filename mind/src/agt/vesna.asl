{ include("$jacamoJar/templates/common-cartago.asl") }
{ include("$jacamoJar/templates/common-moise.asl") }

+clear_my_armies <- 
    .retractall(my_army(_, _, _, _, _, _));
    .retractall(my_army_path_distance(_, _, _)).
+clear_allied_provinces <- .retractall(allied_province(_, _, _, _)).
+clear_enemy_provinces <- .retractall(enemy_province_status(_, _, _, _, _, _, _)).
+clear_neighbor_nations <- .retractall(neighbor_resource(_, _, _)).

+neighbor_resource_update(Neighbor, Res, Amount)
  <- +neighbor_resource(Neighbor, Res, Amount).

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
  <- +my_army(Id, X, Y, Life, AttackValue, Loc).

+allied_province_update(Id, Morale, X, Y)
  <- +allied_province(Id, Morale, X, Y).

+my_army_distance_update(Id, ProvId, Dist)
  <- +my_army_path_distance(Id, ProvId, Dist).

+enemy_province_update(Id, Owner, HasArmyStr, DefenseValue, X, Y, BorderingAllies)
  <- +enemy_province_status(Id, Owner, HasArmyStr, DefenseValue, X, Y, BorderingAllies).

+nation_strength_update(Nation, Strength)
  <- -nation_strength(Nation, _);
     +nation_strength(Nation, Strength).

+active_wars_update(Count)
  <- -active_wars(_);
     +active_wars(Count).

+!evaluate_targets : true
  <- for (resource_trend(NeededResource, negative)) {
         .findall(Amount, neighbor_resource(Neighbor, NeededResource, Amount), ListOfAmounts);
         if (ListOfAmounts \== []) {
             .max(ListOfAmounts, MaxAmount);
             ?neighbor_resource(BestNeighbor, NeededResource, MaxAmount);
             if (not at_war_with(BestNeighbor)) {
                 !decide_attack(BestNeighbor, NeededResource);
             }
         }
     }.

+!decide_attack(TargetNation, NeededResource)
  : not at_war_with(TargetNation)
    & not war_cooldown
    & active_wars(W) & W < 2 
    & .count(my_army(_, _, _, _, _, _), TotalArmies) & TotalArmies > 5
  <- vesna.via.declare_war(TargetNation);
     +at_war_with(TargetNation);
     +war_cooldown;
     .print("Declared war on ", TargetNation, " because they have the most ", NeededResource, ", which I need!");
     !!manage_war_cooldown.

+!manage_war_cooldown
  <- .wait(30000);
     -war_cooldown;
     .print("War cooldown ended.").

+!decide_attack(TargetNation, NeededResource)
  <- true.

+!evaluate_attack_opportunities : true
  <- for(enemy_province_status(ProvId, EnemyNation, _, EnemyDefenseValue, ProvX, ProvY, BorderingAllies)) {
         if (at_war_with(EnemyNation) & BorderingAllies \== []) {
             .findall([AttackValue, MyId], (my_army(MyId, _, _, _, AttackValue, Loc) & .member(Loc, BorderingAllies)), AvailableArmies);
             if (AvailableArmies \== []) {
                 if (EnemyDefenseValue == 0) {
                     .max(AvailableArmies, [MaxAttackValue, BestArmyId]);
                     vesna.via.move_army(BestArmyId, ProvId);
                     .print("Sent army ", BestArmyId, " from border to conquer empty nearby province ", ProvId);
                 } else {
                     !try_coordinated_attack(ProvId, EnemyDefenseValue, AvailableArmies);
                 }
             }
         }
     }.

+!try_coordinated_attack(ProvId, EnemyDefenseValue, AvailableArmies)
  <- !accumulate_attackers(ProvId, EnemyDefenseValue * 1.2, AvailableArmies, 0, []).

+!accumulate_attackers(ProvId, TargetStrength, [], AccumulatedStrength, ChosenArmies)
  : AccumulatedStrength <= TargetStrength
  <- true.

+!accumulate_attackers(ProvId, TargetStrength, _, AccumulatedStrength, ChosenArmies)
  : AccumulatedStrength > TargetStrength
  <- .print("Sending coordinated attack to ", ProvId, " with armies ", ChosenArmies, " (Total Atk: ", AccumulatedStrength, ")");
     for (.member(ArmyId, ChosenArmies)) {
         vesna.via.move_army(ArmyId, ProvId);
     }.

+!accumulate_attackers(ProvId, TargetStrength, [[Atk, ArmyId] | Rest], AccumulatedStrength, ChosenArmies)
  : AccumulatedStrength <= TargetStrength
  <- !accumulate_attackers(ProvId, TargetStrength, Rest, AccumulatedStrength + Atk, [ArmyId | ChosenArmies]).

+foreign_army_moving(ArmyId, Nation, PosX, PosY, NextX, NextY)
  : at_war_with(Nation) | is_threat(Nation)
  <- .print("Enemy army ", ArmyId, " of ", Nation, " moving towards ", NextX, ",", NextY);
     // Find the closest core province to (NextX, NextY)
     !find_closest_province(NextX, NextY, ClosestProv);
     // Find our army with the absolute minimum A* path distance to ClosestProv
     .findall([PathDist, MyId], (my_army(MyId, _, _, _, _, Loc) & my_army_path_distance(MyId, ClosestProv, PathDist) & Loc \== ClosestProv & not ordered_to_defend(MyId, ClosestProv)), ArmiesWithDist);
     if (ArmiesWithDist \== []) {
         .min(ArmiesWithDist, [MinDist, BestArmyId]);
         .retractall(ordered_to_defend(BestArmyId, _));
         +ordered_to_defend(BestArmyId, ClosestProv);
         vesna.via.move_army(BestArmyId, ClosestProv);
         .print("Sending A* closest army ", BestArmyId, " to defend province ", ClosestProv, " (Path Dist: ", MinDist, ")");
     }.

+!find_closest_province(TargetX, TargetY, ClosestProv)
  <- .findall([Dist, ProvId], (allied_province(ProvId, _, ProvX, ProvY) & Dist = (TargetX - ProvX)**2 + (TargetY - ProvY)**2), Distances);
     if (Distances \== []) {
         .min(Distances, [MinDist, ClosestProv]);
     } else {
         ?allied_province(ClosestProv, _, _, _);
     }.

+foreign_army_moving(ArmyId, Nation, PosX, PosY, NextX, NextY)
  <- true.

+active_wars(Count)
  <- !evaluate_targets;
     !evaluate_attack_opportunities.
