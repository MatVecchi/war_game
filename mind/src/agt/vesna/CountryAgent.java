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
            org.json.JSONArray allied = sight.getJSONArray("allied_provinces");
            sense(createLiteral("clear_allied_provinces"));
            for (int i = 0; i < allied.length(); i++) {
                JSONObject prov = allied.getJSONObject(i);
                sense(createLiteral("allied_province_update", 
                    createAtom(prov.getString("id")), 
                    createNumber(prov.getInt("morale")), 
                    createNumber(prov.getDouble("x")), 
                    createNumber(prov.getDouble("y")),
                    createAtom(prov.getBoolean("is_capital") ? "true" : "false"),
                    createAtom(prov.getBoolean("is_double") ? "true" : "false"),
                    createAtom(prov.getString("resource"))
                ));
            }

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

                sense(createLiteral("enemy_province_update", 
                    createAtom(prov.getString("id")), 
                    createAtom(prov.getString("owner")), 
                    createAtom(prov.getBoolean("has_army") ? "true" : "false"), 
                    createNumber(prov.getDouble("defense_value")), 
                    createNumber(prov.getDouble("x")), 
                    createNumber(prov.getDouble("y")), 
                    bordersList,
                    createAtom(prov.getBoolean("is_capital") ? "true" : "false"),
                    createAtom(prov.getBoolean("is_double") ? "true" : "false"),
                    createAtom(prov.getString("resource"))
                ));
            }

            JSONObject rules = sight.getJSONObject("game_rules");
            sense(createLiteral("game_rules_update",
                createNumber(rules.getInt("riot_threshold")),
                createNumber(rules.getInt("riot_breakpoint")),
                createNumber(rules.getDouble("riot_base_defense")),
                createNumber(rules.getDouble("riot_penalty_multiplier")),
                createNumber(rules.getDouble("life_per_unit")),
                createNumber(rules.getDouble("attack_per_unit")),
                createNumber(rules.getDouble("defense_per_unit")),
                createNumber(rules.getInt("max_alliances")),
                createNumber(rules.getInt("conquered_morale"))
            ));

            JSONObject strengths = sight.getJSONObject("nation_strengths");
            for (String key : strengths.keySet()) {
                sense(createLiteral("nation_strength_update", createAtom(key), createNumber(strengths.getInt(key))));
            }

            sense(createLiteral("clear_neighbor_nations"));
            JSONObject neighborsData = sight.getJSONObject("neighbor_nations");
            for (String neighborName : neighborsData.keySet()) {
                JSONObject neighborRes = neighborsData.getJSONObject(neighborName);
                for (String resName : neighborRes.keySet()) {
                    sense(createLiteral("neighbor_resource_update", createAtom(neighborName), createAtom(resName), createNumber(neighborRes.getInt(resName))));
                }
            }

            if (sight.has("province_distances")) {
                JSONObject provDists = sight.getJSONObject("province_distances");
                for (String p1 : provDists.keySet()) {
                    JSONObject p1Map = provDists.getJSONObject(p1);
                    for (String p2 : p1Map.keySet()) {
                        double d = p1Map.getDouble(p2);
                        try {
                            addBel(createLiteral("province_distance", createAtom(p1), createAtom(p2), createNumber(d)));
                        } catch (Exception e) {
                            e.printStackTrace();
                        }
                    }
                }
            }

            sense(createLiteral("day_cycle_update", createNumber(sight.getInt("day"))));

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_resource_change(JSONObject sight) {
        try {
            String key = sight.getString("resource");
            int amount = sight.getInt("amount");
            sense(createLiteral("resource_update", createAtom(key), createNumber(amount)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_war_declared(JSONObject sight) {
        try {
            String nation = sight.getString("nation");
            sense(createLiteral("at_war_with_update", createAtom(nation)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_peace_request_received(JSONObject sight) {
        try {
            String sender = sight.getString("sender");
            sense(createLiteral("peace_request_received", createAtom(sender)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_peace_request_declined(JSONObject sight) {
        try {
            String sender = sight.getString("sender");
            sense(createLiteral("peace_request_declined", createAtom(sender)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_peace_established(JSONObject sight) {
        try {
            String nation = sight.getString("nation");
            sense(createLiteral("peace_established_update", createAtom(nation)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_alliance_request_received(JSONObject sight) {
        try {
            String sender = sight.getString("sender");
            sense(createLiteral("alliance_request_received", createAtom(sender)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_alliance_request_declined(JSONObject sight) {
        try {
            String sender = sight.getString("sender");
            sense(createLiteral("alliance_request_declined", createAtom(sender)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_alliance_established(JSONObject sight) {
        try {
            if (sight.has("nation1") && sight.has("nation2")) {
                String n1 = sight.getString("nation1");
                String n2 = sight.getString("nation2");
                sense(createLiteral("alliance_established_update", createAtom(n1), createAtom(n2)));
            } else if (sight.has("nation")) {
                String nation = sight.getString("nation");
                sense(createLiteral("alliance_established_update", createAtom(nation)));
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_alliance_broken(JSONObject sight) {
        try {
            if (sight.has("nation1") && sight.has("nation2")) {
                String n1 = sight.getString("nation1");
                String n2 = sight.getString("nation2");
                sense(createLiteral("alliance_broken_update", createAtom(n1), createAtom(n2)));
            } else if (sight.has("nation")) {
                String nation = sight.getString("nation");
                sense(createLiteral("alliance_broken_update", createAtom(nation)));
            }
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
            String targetProv = sight.has("target_province") ? sight.getString("target_province") : "";
            double attackVal = sight.has("attack_value") ? sight.getDouble("attack_value") : 0.0;
            
            sense(createLiteral("foreign_army_moving", 
                createNumber(id), 
                createAtom(owner), 
                createNumber(x), 
                createNumber(y), 
                createNumber(nextX), 
                createNumber(nextY), 
                createAtom(targetProv.isEmpty() ? "none" : targetProv),
                createNumber(attackVal)
            ));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_foreign_army_destroyed(JSONObject sight) {
        try {
            long id = sight.getLong("id");
            String owner = sight.has("owner") ? sight.getString("owner") : "";
            sense(createLiteral("foreign_army_destroyed_update", createNumber(id), createAtom(owner.isEmpty() ? "unknown" : owner)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_enemy_province_defense_update(JSONObject sight) {
        try {
            String id = sight.getString("id");
            double defenseValue = sight.getDouble("defense_value");
            boolean hasArmy = sight.getBoolean("has_army");
            sense(createLiteral("enemy_province_defense_update", createAtom(id), createAtom(hasArmy ? "true" : "false"), createNumber(defenseValue)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_province_morale_update(JSONObject sight) {
        try {
            String id = sight.getString("id");
            int morale = sight.getInt("morale");
            sense(createLiteral("province_morale_update", createAtom(id), createNumber(morale)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_province_owner_update(JSONObject sight) {
        try {
            String id = sight.getString("id");
            String owner = sight.getString("owner");
            int morale = sight.getInt("morale");
            double x = sight.getDouble("x");
            double y = sight.getDouble("y");
            boolean hasArmy = sight.getBoolean("has_army");
            double defenseValue = sight.getDouble("defense_value");
            boolean isCapital = sight.getBoolean("is_capital");
            boolean isDouble = sight.getBoolean("is_double");
            String resource = sight.getString("resource");
            
            org.json.JSONArray borders = sight.getJSONArray("bordering_allies");
            jason.asSyntax.ListTerm bordersList = new jason.asSyntax.ListTermImpl();
            jason.asSyntax.ListTerm tail = bordersList;
            for (int j = 0; j < borders.length(); j++) {
                tail = tail.append(createAtom(borders.getString(j)));
            }

            String myName = getTS().getAgArch().getAgName();
            if (owner.equals(myName)) {
                sense(createLiteral("allied_province_owner_update", 
                    createAtom(id), 
                    createNumber(morale), 
                    createNumber(x), 
                    createNumber(y),
                    createAtom(isCapital ? "true" : "false"),
                    createAtom(isDouble ? "true" : "false"),
                    createAtom(resource)
                ));
            } else {
                sense(createLiteral("enemy_province_owner_update", 
                    createAtom(id), 
                    createAtom(owner), 
                    createAtom(hasArmy ? "true" : "false"), 
                    createNumber(defenseValue), 
                    createNumber(x), 
                    createNumber(y), 
                    bordersList,
                    createAtom(isCapital ? "true" : "false"),
                    createAtom(isDouble ? "true" : "false"),
                    createAtom(resource)
                ));
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_my_army_update(JSONObject sight) {
        try {
            long id = sight.getLong("id");
            double x = sight.getDouble("x");
            double y = sight.getDouble("y");
            double life = sight.getDouble("life");
            double attackValue = sight.getDouble("attack_value");
            String loc = sight.has("location") ? sight.getString("location") : "";
            boolean travelling = sight.has("travelling") ? sight.getBoolean("travelling") : false;
            String targetProv = sight.has("target_province") ? sight.getString("target_province") : "";
            
            sense(createLiteral("my_army_update", createNumber(id), createNumber(x), createNumber(y), createNumber(life), createNumber(attackValue), createAtom(loc.isEmpty() ? "unknown" : loc)));
            sense(createLiteral("my_army_travelling_update", createNumber(id), createAtom(travelling ? "true" : "false")));
            sense(createLiteral("my_army_target_update", createNumber(id), createAtom(targetProv.isEmpty() ? "none" : targetProv)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_my_army_destroyed(JSONObject sight) {
        try {
            long id = sight.getLong("id");
            sense(createLiteral("my_army_destroyed_update", createNumber(id)));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_neighbor_nations_update(JSONObject sight) {
        try {
            sense(createLiteral("clear_neighbor_nations"));
            JSONObject neighborsData = sight.getJSONObject("neighbor_nations");
            for (String neighborName : neighborsData.keySet()) {
                JSONObject neighborRes = neighborsData.getJSONObject(neighborName);
                for (String resName : neighborRes.keySet()) {
                    sense(createLiteral("neighbor_resource_update", createAtom(neighborName), createAtom(resName), createNumber(neighborRes.getInt(resName))));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_day_update(JSONObject sight) {
        try {
            int day = sight.getInt("day");
            sense(createLiteral("day_cycle_update", createNumber(day)));

            JSONObject strengths = sight.getJSONObject("nation_strengths");
            for (String key : strengths.keySet()) {
                sense(createLiteral("nation_strength_update", createAtom(key), createNumber(strengths.getInt(key))));
            }

            if (sight.has("neighbor_nations")) {
                handle_neighbor_nations_update(sight);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void handle_match_over(JSONObject sight) {
        try {
            sense(createLiteral("match_over"));
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
            case "match_over":
                handle_match_over(sight);
                break;
            case "day_update":
                handle_day_update(sight);
                break;
            case "neighbor_nations_update":
                handle_neighbor_nations_update(sight);
                break;
            case "resource_change":
                handle_resource_change(sight);
                break;
            case "war_declared":
                handle_war_declared(sight);
                break;
            case "foreign_army_moving":
                handle_foreign_army_moving(sight);
                break;
            case "foreign_army_destroyed":
                handle_foreign_army_destroyed(sight);
                break;
            case "another_new_my_armie":
                handle_another_new_my_armie(sight);
                break;
            case "enemy_province_defense_update":
                handle_enemy_province_defense_update(sight);
                break;
            case "province_morale_update":
                handle_province_morale_update(sight);
                break;
            case "province_owner_update":
                handle_province_owner_update(sight);
                break;
            case "my_army_update":
                handle_my_army_update(sight);
                break;
            case "my_army_destroyed":
                handle_my_army_destroyed(sight);
                break;
            case "peace_request_received":
                handle_peace_request_received(sight);
                break;
            case "peace_request_declined":
                handle_peace_request_declined(sight);
                break;
            case "peace_established":
                handle_peace_established(sight);
                break;
            case "alliance_request_received":
                handle_alliance_request_received(sight);
                break;
            case "alliance_request_declined":
                handle_alliance_request_declined(sight);
                break;
            case "alliance_established":
                handle_alliance_established(sight);
                break;
            case "alliance_broken":
                handle_alliance_broken(sight);
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