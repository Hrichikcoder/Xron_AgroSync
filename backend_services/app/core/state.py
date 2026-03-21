# Global state variables
pump_mode = "auto"
pump1_state = False
pump2_state = False
shade_state = False
sprinkler_state = False

# Live Flow variables 
current_water_flow = 0.0
current_flow_rate = 0.0

target_volume: float = 500.0
active_field_area_cm2: float = 150.0