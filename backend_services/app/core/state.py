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

# Live Diagnostics State
live_sensor_data = {
    "temperature": 0.0,
    "humidity": 0.0,
    "ldr": 0,
    "soil_moisture": 4095,
    "rain_level": 4095,
    "depth_level": 0,
    "water_flow": 0.0,
    "flow_rate": 0.0
}

trigger_hw_diag = False


# --- Added: Sensor Override States ---
disable_soil_moisture = False
disable_depth = False
disable_temperature = False
disable_ldr = False
disable_rain_level = False