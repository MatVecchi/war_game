{ include("$jacamoJar/templates/common-cartago.asl") }
{ include("$jacamoJar/templates/common-moise.asl") }

+!order(Id, Target)
    : my_armies(Armies)
    & member(army(Id, Pos), Armies)
    & province(Target, _, _)
<-  !find_army_by_id(Armies, Id, Army);
    vesna.order(Army, Target);
    .print("Army ordered").

@add_army_and_order
+!add_army_and_order(Id, Pos)
    : .my_name(Me) & my_armies(Q) & not member(army(Id, Pos), Q)
    <-
        !append_my_armies(Id, Pos);
        !order(Id, kiev).

@append[atomic]
+!append_my_armies(Id, Pos)
    : .my_name(Me) & my_armies(Q) & not member(army(Id, Pos), Q)
    <- 
        -my_armies(Q);
        +my_armies([army(Id, Pos) | Q]);
        ?my_armies(R);
        .print(R).

@append_already[atomic]
+!append_my_armies(Id, Pos)
    : .my_name(Me) & my_armies(Q) & member(army(Id, Pos), Q)
    <-      
        .print("already in list").

@pop_base[atomic]
+!pop([], Id, [])
    : .my_name(Me)
    <- .print(Id, " not found");
        ?my_armies(Q);  
        .print("Lista overtake: ", Q).

@pop_del[atomic]
+!pop( [army(Id, Pos) | Tail], Id, Tail)
    : .my_name(Me)
    <- .print("Elemento da eliminare trovato").

@pop[atomic]
+!pop( [Head | Tail], Id, [Head | Rest])
    : .my_name(Me) 
    <- 
        !pop(Tail, Id, Rest).

@find_by_id_base[atomic]
+!find_army_by_id([], Id, Result)
    : .my_name(Me)
    <- 
        Result = not_found;
        .print("army with Id ", Id, " not found").

@find_by_id_found[atomic]
+!find_army_by_id([army(Id, Pos) | _], Id, Result)
    : .my_name(Me)
    <- 
        Result = army(Id, Pos);
        .print("army(", Id, ", ", Pos, ") found").

@find_by_id_rec[atomic]
+!find_army_by_id([_ | Tail], Id, Result)
    : .my_name(Me)
    <- 
        !find_army_by_id(Tail, Id, Result).

+another_my_army(Id, Pos)
    : true
    <- 
        !add_army_and_order(Id, Pos).
