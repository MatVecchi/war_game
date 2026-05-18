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

    private void handle_state_update(JSONObject sight) {
        try {
            // Update resources
            JSONObject resources = sight.getJSONObject("resources");
            for (String key : resources.keySet()) {
                sense(createLiteral("resource_update", createAtom(key), createNumber(resources.getInt(key))));
            }

            // Update my_armies
            org.json.JSONArray myArmies = sight.getJSONArray("my_armies");
            sense(createLiteral("clear_my_armies"));
            for (int i = 0; i < myArmies.length(); i++) {
                JSONObject army = myArmies.getJSONObject(i);
                String loc = army.has("location") ? army.getString("location") : "";
                sense(createLiteral("my_army_update", createNumber(army.getLong("id")), createNumber(army.getDouble("x")), createNumber(army.getDouble("y")), createNumber(army.getDouble("life")), createNumber(army.getDouble("attack_value")), createAtom(loc.isEmpty() ? "unknown" : loc)));
            }

            // Update allied provinces
            org.json.JSONArray allied = sight.getJSONArray("allied_provinces");
            sense(createLiteral("clear_allied_provinces"));
            for (int i = 0; i < allied.length(); i++) {
                JSONObject prov = allied.getJSONObject(i);
                sense(createLiteral("allied_province_update", createAtom(prov.getString("id")), createNumber(prov.getInt("morale"))));
            }

            // Update enemy provinces
            org.json.JSONArray enemies = sight.getJSONArray("enemy_provinces");
            sense(createLiteral("clear_enemy_provinces"));
            for (int i = 0; i < enemies.length(); i++) {
                JSONObject prov = enemies.getJSONObject(i);
                
                org.json.JSONArray borders = prov.getJSONArray("bordering_allies");
                jason.asSyntax.ListTerm bordersList = new jason.asSyntax.ListTermImpl();
                jason.asSyntax.ListTerm tail = bordersList;
                for (int j = 0; j < borders.length(); j++) {
                    tail = tail.append(createAtom(borders.getString(j)));
                }

                sense(createLiteral("enemy_province_update", createAtom(prov.getString("id")), createAtom(prov.getString("owner")), createAtom(prov.getBoolean("has_army") ? "true" : "false"), createNumber(prov.getDouble("defense_value")), createNumber(prov.getDouble("x")), createNumber(prov.getDouble("y")), bordersList));
            }

            // Update nation strengths
            JSONObject strengths = sight.getJSONObject("nation_strengths");
            for (String key : strengths.keySet()) {
                sense(createLiteral("nation_strength_update", createAtom(key), createNumber(strengths.getInt(key))));
            }
            
            // Update neighbor nations resources
            if (sight.has("neighbor_nations")) {
                sense(createLiteral("clear_neighbor_nations"));
                JSONObject neighborsData = sight.getJSONObject("neighbor_nations");
                for (String neighborName : neighborsData.keySet()) {
                    JSONObject neighborRes = neighborsData.getJSONObject(neighborName);
                    for (String resName : neighborRes.keySet()) {
                        sense(createLiteral("neighbor_resource_update", createAtom(neighborName), createAtom(resName), createNumber(neighborRes.getInt(resName))));
                    }
                }
            }
            
            // Update active wars
            sense(createLiteral("active_wars_update", createNumber(sight.getInt("active_wars"))));

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_foreign_army_moving(JSONObject sight) {
        try {
            long id = sight.getLong("id");
            String owner = sight.getString("owner");
            double x = sight.getDouble("x");
            double y = sight.getDouble("y");
            double nextX = sight.getDouble("next_x");
            double nextY = sight.getDouble("next_y");
            sense(createLiteral("foreign_army_moving", createNumber(id), createAtom(owner), createNumber(x), createNumber(y), createNumber(nextX), createNumber(nextY)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    protected void handle_sight(JSONObject sight) {
        String object = sight.getString("type");
        switch (object) {
            case "state_update":
                handle_state_update(sight);
                break;
            case "foreign_army_moving":
                handle_foreign_army_moving(sight);
                break;
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