package vesna.via;

import jason.asSemantics.*;
import jason.asSyntax.*;
import org.json.JSONObject;
import vesna.VesnaAgent;

public class accept_alliance extends DefaultInternalAction {

    // vesna.via.accept_alliance( "CountryName" )
    @Override
    public Object execute( TransitionSystem ts, Unifier un, Term[] args ) throws Exception {

        if ( args.length != 1 || !args[0].isString() && !args[0].isAtom() )
            return false;

        String target = args[0].toString();
        if (target.startsWith("\"") && target.endsWith("\"")) {
            target = target.substring(1, target.length() - 1);
        }

        JSONObject data = new JSONObject();
        data.put( "action_type", "accept_alliance" );
        data.put( "target", target );

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
