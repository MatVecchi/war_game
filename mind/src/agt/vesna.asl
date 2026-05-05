{ include("$jacamoJar/templates/common-cartago.asl") }
{ include("$jacamoJar/templates/common-moise.asl") }

// ----------------------------------------------------
// STATE UPDATE HANDLERS (Called from Java sense events)
// ----------------------------------------------------

+clear_my_armies <- -my_army(_, _, _, _).
+clear_allied_provinces <- -allied_province(_, _).
+clear_enemy_provinces <- -enemy_province_status(_, _, _).
+clear_neighbor_nations <- -neighbor_resource(_, _, _).

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

+my_army_update(Id, X, Y, Life)
  <- +my_army(Id, X, Y, Life).

+allied_province_update(Id, Morale)
  <- +allied_province(Id, Morale).

+enemy_province_update(Id, Owner, HasArmyStr)
  <- +enemy_province_status(Id, Owner, HasArmyStr).

+nation_strength_update(Nation, Strength)
  <- -nation_strength(Nation, _);
     +nation_strength(Nation, Strength).

+active_wars_update(Count)
  <- -active_wars(_);
     +active_wars(Count).

// ----------------------------------------------------
// DIPLOMACY & TARGET ACQUISITION
// ----------------------------------------------------

// Called periodically (e.g., triggered by a timer or another goal)
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
    & active_wars(W) & W < 2 
    & .count(my_army(_, _, _, _), TotalArmies) & TotalArmies > 5
  <- vesna.via.declare_war(TargetNation);
     +at_war_with(TargetNation);
     .print("Declared war on ", TargetNation, " because they have the most ", NeededResource, ", which I need!").

// Fallback if conditions not met
+!decide_attack(TargetNation, NeededResource)
  <- true.

// ----------------------------------------------------
// OFFENSIVE STRATEGY (Target Empty Enemy Provinces)
// ----------------------------------------------------

// Trigger this every time state updates or periodically
+!evaluate_attack_opportunities : true
  <- for(enemy_province_status(ProvId, EnemyNation, "false")) {
         if (at_war_with(EnemyNation)) {
             // Find an available army
             ?my_army(MyId, _, _, _); // Just picks the first one
             vesna.via.move_army(MyId, ProvId);
             .print("Sent army ", MyId, " to attack empty province ", ProvId);
         }
     }.

// ----------------------------------------------------
// DEFENSIVE STRATEGY (Reinforce Core based on Partial Paths)
// ----------------------------------------------------

+foreign_army_moving(ArmyId, Nation, PosX, PosY, NextX, NextY)
  : at_war_with(Nation) | is_threat(Nation)
  <- .print("Enemy army ", ArmyId, " of ", Nation, " moving towards ", NextX, ",", NextY);
     // Find the closest core province to (NextX, NextY)
     !find_closest_province(NextX, NextY, ClosestProv);
     // Send our closest army to that province
     if (my_army(MyId, MyX, MyY, MyLife)) {
         vesna.via.move_army(MyId, ClosestProv);
         .print("Defending province ", ClosestProv, " with army ", MyId);
     }.

+!find_closest_province(X, Y, ClosestProv)
  <- // Simple approximation: just pick any allied province for now
     // To improve: calculate euclidean distance between (X,Y) and province centers
     ?allied_province(ClosestProv, _).

// Default if not at war/threat
+foreign_army_moving(ArmyId, Nation, PosX, PosY, NextX, NextY)
  <- true.

// ----------------------------------------------------
// MAIN LOOP TRIGGER (Trigger evaluation goals periodically)
// ----------------------------------------------------
// Since we get active_wars_update every hour, we can use it to trigger our strategy evaluations
+active_wars(Count)
  <- !evaluate_targets;
     !evaluate_attack_opportunities.
