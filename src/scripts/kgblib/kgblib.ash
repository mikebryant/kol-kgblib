script "kgblib.ash";
notify "LeaChim";

int [6] dial_state;
int [6] light_state;
boolean handle_is_up;
boolean crank_is_unlocked;
boolean buttons_are_unlocked;
boolean left_drawer_is_unlocked;
boolean right_drawer_is_unlocked;
boolean martini_hose_is_unlocked;

string dial_letters = "0123456789a";

string dial_number_to_letter(int dial_num) {
  return substring(dial_letters, dial_num, dial_num + 1);
}

void debug_state() {
  print(
    "KGB:: dials: " +
    dial_number_to_letter(dial_state[0]) +
    dial_number_to_letter(dial_state[1]) +
    dial_number_to_letter(dial_state[2]) +
    dial_number_to_letter(dial_state[3]) +
    dial_number_to_letter(dial_state[4]) +
    dial_number_to_letter(dial_state[5]) +
    ", lights: " +
    light_state[0] +
    light_state[1] +
    light_state[2] +
    light_state[3] +
    light_state[4] +
    light_state[5] +
    ", handle: " + (handle_is_up ? "up" : "down") +
    ", crank: " + (crank_is_unlocked ? "unlocked" : "unavailable") +
    ", buttons: " + (buttons_are_unlocked ? "unlocked" : "unavailable") +
    ", left drawer: " + (left_drawer_is_unlocked ? "unlocked" : "unavailable") +
    ", right drawer: " + (right_drawer_is_unlocked ? "unlocked" : "unavailable") +
    ", martini hose: " + (martini_hose_is_unlocked ? "unlocked" : "unavailable")
  );
}

void parse_state() {
  string page = visit_url("place.php?whichplace=kgb");

  matcher dial_matcher = create_matcher("kgb_dial([1-6])(.+?)char([0-9a])\\.gif", page);

  while (find(dial_matcher)) {
    dial_state[dial_matcher.group(1).to_int() - 1] = index_of(dial_letters, dial_matcher.group(3));
  }

  matcher light_matcher = create_matcher("kgb_light([1-6])(.+?)light_(off|blinking|on)\\.gif", page);
  while (find(light_matcher)) {
    string light_name = light_matcher.group(3);
    light_state[light_matcher.group(1).to_int() - 1] = (
      (light_name == "off") ? 0 :
      (light_name == "blinking") ? 1 :
      (light_name == "on") ? 2 : 999
    );
  }

  handle_is_up = (page.index_of("action=kgb_handleup") > -1);

  crank_is_unlocked = (page.index_of("action=kgb_crank") > -1);

  buttons_are_unlocked = (page.index_of("action=kgb_button1") > -1);

  left_drawer_is_unlocked = (page.index_of("action=kgb_drawer2") > -1);
  right_drawer_is_unlocked = (page.index_of("action=kgb_drawer1") > -1);

  martini_hose_is_unlocked = (page.index_of("action=kgb_dispenser") > -1);

  return;
}

// Kick off our global variables by pulling in the current dial state
parse_state();


void wind_dial(int dial, int set)
{
  // 11 clicks will bring dial back to starting position
  string url = "place.php?whichplace=kgb&action=kgb_dial"+dial;

  int start_pos = dial_state[dial - 1];

  int clicks = 0;
  if (set == start_pos) {
    return;
  } else if (set > start_pos) {
    clicks = set - start_pos;
  } else if (set < start_pos) {
    clicks = 11 - start_pos + set;
  }

  while (clicks > 0) {
    visit_url(url,false);
    clicks--;
  }

  parse_state();
  debug_state();
  return;
}

void wind_dials(int dial1, int dial2, int dial3, int dial4, int dial5, int dial6) {
  wind_dial(1, dial1);
  wind_dial(2, dial2);
  wind_dial(3, dial3);
  wind_dial(4, dial4);
  wind_dial(5, dial5);
  wind_dial(6, dial6);
}


void handle_down() {
  // Make sure handle is down
  if (handle_is_up)
  {
    visit_url("place.php?whichplace=kgb&action=kgb_handleup", false);
  }
  handle_is_up = false;

  return;
}

void handle_up() {
  // Make sure handle is up
  if (!handle_is_up) {
    visit_url("place.php?whichplace=kgb&action=kgb_handledown", false);
  }
  handle_is_up = true;

  return;
}

void reset_case() {
  handle_down();
  handle_up();
  handle_down();
  handle_up();
  handle_down();

  return;
}

void left_actuator() {
  string left = visit_url("place.php?whichplace=kgb&action=kgb_actuator1", false);
  return;
}

void right_actuator() {
  string right = visit_url("place.php?whichplace=kgb&action=kgb_actuator2", false);
  return;
}

void turn_crank() {
  string crank = visit_url("place.php?whichplace=kgb&action=kgb_crank", false);
  return;
}


void unlock_light_one() {
  if (light_state[0] == 2) return;

  left_actuator();
  right_actuator();

  parse_state();

  return;
}

void unlock_crank() {
  if (crank_is_unlocked) return;

  wind_dials(0, 0, 0, 0, 0, 0);
  parse_state();

  handle_down();
  left_actuator();

  parse_state();

  return;
}

void charge_flywheel() {
  if (get_property("_kgb_flywheel_charged").to_boolean()) return;

  handle_up();
  for x from 1 to 11 by 1
  {
    turn_crank();
  }

  handle_down();

  set_property("_kgb_flywheel_charged", "true");

  return;
}


void unlock_buttons() {
  if (buttons_are_unlocked) return;

  wind_dials(0, 1, 2, 2, 1, 0);
  left_actuator();

  parse_state();

  return;
}

void unlock_left_drawer() {
  if (left_drawer_is_unlocked) return;
  wind_dials(2, 2, 2, 0, 0, 0);
  left_actuator();
  parse_state();
}

void unlock_right_drawer() {
  if (left_drawer_is_unlocked) return;
  wind_dials(0, 0, 0, 2, 2, 2);
  right_actuator();
  parse_state();
}

void unlock_drawers() {
  unlock_left_drawer();
  unlock_right_drawer();
  return;
}

void left_drawer() {
  if (get_property("_kgb_left_drawer_used").to_boolean()) return;

  unlock_left_drawer();
  visit_url("place.php?whichplace=kgb&action=kgb_drawer2", false);

  set_property("_kgb_left_drawer_used", "true");
  return;
}

void right_drawer() {
  if (get_property("_kgb_right_drawer_used").to_boolean()) return;

  unlock_right_drawer();
  visit_url("place.php?whichplace=kgb&action=kgb_drawer1", false);

  set_property("_kgb_right_drawer_used", "true");
  return;
}

void unlock_martini_hose() {
  if (martini_hose_is_unlocked) return;
  wind_dials(0, 0, 0, 0, 0, 0);
  handle_up();
  left_actuator();
  parse_state();
}

void kgb_auto() {
  unlock_light_one();
  unlock_crank();
  unlock_buttons();
  unlock_drawers();
  charge_flywheel();
  unlock_martini_hose();

  left_drawer();
  right_drawer();
}

void main() {
  debug_state();
  kgb_auto();
  debug_state();
}
