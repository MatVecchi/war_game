{ include( "vesna.asl" ) }
{ include( "playgrounds/office.asl" ) }

+!start
    :   .my_name( Me )
    <-  +my_armies([]);
        +my_resources([]);
        +known_armies([]);
        +perfectly_known_armies([]).