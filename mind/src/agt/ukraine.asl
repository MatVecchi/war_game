{ include( "vesna.asl" ) }
{ include( "ambient/map.asl") }
/* { include( "playgrounds/office.asl" ) }
 */

+!start
    :   .my_name( Me )
    <-  +my_armies([]);
        +known_armies([]);
        +perfectly_known_armies([]);