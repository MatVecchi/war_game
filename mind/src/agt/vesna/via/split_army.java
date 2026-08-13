package vesna.via;

import jason.asSemantics.*;
import jason.asSyntax.*;
import org.json.JSONObject;
import vesna.VesnaAgent;

public class split_army extends DefaultInternalAction {

    // vesna.via.split_army( ArmyId, SoldiersCount, "TargetProvince" )
    @Override
    public Object execute( TransitionSystem ts, Unifier un, Term[] args ) throws Exception {

        if ( args.length != 3 || !args[0].isNumeric() || !args[1].isNumeric() )
            return false;

        long armyId = (long)((NumberTerm)args[0]).solve();
        int soldiers = (int)((NumberTerm)args[1]).solve();
        String targetProvince = args[2].toString();
        if (targetProvince.startsWith("\"") && targetProvince.endsWith("\"")) {
            targetProvince = targetProvince.substring(1, targetProvince.length() - 1);
        }

        JSONObject data = new JSONObject();
        data.put( "action_type", "split_army" );
        data.put( "army_id", armyId );
        data.put( "soldiers", soldiers );
        data.put( "target_province", targetProvince );

        JSONObject action = new JSONObject();
        action.put( "sender", ts.getAgArch().getAgName() );
        action.put( "receiver", "body" );
        action.put( "type", "action" );
        action.put( "data", data );

        VesnaAgent ag = ( VesnaAgent ) ts.getAg();
        ag.perform( action.toString() );

        return true;
    }
}
