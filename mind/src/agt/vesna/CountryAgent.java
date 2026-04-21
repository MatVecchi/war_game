package vesna;

import jason.JasonException;
import jason.asSemantics.*;
import jason.asSyntax.*;
import jason.runtime.RuntimeServicesFactory;

import static jason.asSyntax.ASSyntax.*;

import java.net.URI;

import org.gradle.internal.impldep.org.apache.commons.lang.StringUtils;
import org.json.JSONObject;

// VesnaAgent class extends the Agent class making the agent embodied;
// It connects to the body using a WebSocket connection;
// It needs two beliefs: address( ADDRESS ) and port( PORT ) that describe the address and port of the WebSocket server;
// In order to use it you should add to your .jcm:
// > agent alice:alice.asl {
// >      beliefs: address( localhost )
// >               port( 8080 )
// >      ag-class: vesna.VesnaAgent    
// > }

public class CountryAgent extends VesnaAgent {
    
    /*
        {
            "type": "sight",
            "sender": [sender],
            "receiver": vesna,
            "data": {
                "type": "another_new_my_armies",
                "id": [id],
                "position": {
                    "x": [position.x],
                    "y": [position.y]
                }
            }
        }
    */
    private void handle_another_new_my_armie(JSONObject sight){
        long id = sight.getLong("id");
        JSONObject coords = sight.getJSONObject("position");
        Literal bel = createLiteral("another_my_army", createNumber(id), createLiteral("pos", createNumber(coords.getDouble("x")), createNumber(coords.getDouble("y"))));
        
        try {
            addBel(bel);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /*
        {
            "type": "sight",
            "sender": [sender],
            "receiver": vesna,
            "data": {
                "type": [uknown],
                ...
            }
        }
    */
    private void handle_general_sight(JSONObject sight){
        String object = sight.getString("sight");
        long id = sight.getLong("id");
        String operation = sight.getString("operation");
        Literal sight_belief = createLiteral("sight", createLiteral(object), createNumber(id));
        if (operation.equals("add")) {
            try {
                addBel(sight_belief);
            } catch (Exception e) {
                e.printStackTrace();
            }
        } else if (operation.equals("remove")) {
            try {
                delBel(sight_belief);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    @Override
    protected void handle_sight(JSONObject sight) {
        String object = sight.getString("type");
        switch (object) {
            case "another_new_my_armie":
                handle_another_new_my_armie(sight);
                break;
            default:
                handle_general_sight(sight);
                break;
        }

    }

    // handle_event takes all the data from an event and senses a perception
    @Override
    protected void handle_event( JSONObject event ) {
        String event_type = event.getString( "type" );
        String event_status = event.getString( "status" );
        String event_reason = event.getString( "reason" );
        Literal perception = createLiteral( event_type, createLiteral( event_status ), createLiteral( event_reason ) );
        sense(perception);
    }

    // this function handles incoming messages from the body
    // available types are: signal, sight
    @Override
    public void vesna_handle_msg(String msg) {
        System.out.println("Received message: " + msg);
        JSONObject log = new JSONObject(msg);
        String sender = log.getString("sender");
        String receiver = log.getString("receiver");
        String type = log.getString("type");
        JSONObject data = log.getJSONObject("data");
        switch (type) {
            case "signal":
                handle_event(data);
                break;
            case "sight":
                handle_sight(data);
                break;
            default:
                System.out.println("Unknown message type: " + type);
        }
    }
}