import joblib
import numpy as np
import os
import pandas as pd

# Path to the uploaded model
MODEL_PATH = "ml_models//irrigation_flow_model.joblib"

try:
    rf_model = joblib.load(MODEL_PATH)
    print("Irrigation Flow Model loaded successfully.")
except Exception as e:
    rf_model = None
    print(f"Failed to load ML model: {e}")

def predict_water_requirement(temperature, humidity, soil_moisture, ldr, rain_level, area_cm2):
    
    rf_model = joblib.load(MODEL_PATH)

    if rf_model is None:
        return 500.0  # Fallback target volume in mL if model fails
        
    try:
        # 1. Convert raw capacitive soil moisture (ESP32: ~4000 dry, ~1000 wet) to a percentage (0-100%)
        dry_value = 4095.0
        wet_value = 1000.0
        
        raw_pct = ((dry_value - soil_moisture) / (dry_value - wet_value)) * 100.0
        current_moisture_pct = max(0.0, min(100.0, raw_pct))

        # 2. Define static field parameters           
        target_moisture_pct = 95.0 

        # 3. Create the initial DataFrame with the correct names
        features = pd.DataFrame([{
            'area_cm2': area_cm2, 
            'current_moisture_pct': current_moisture_pct, 
            'humidity_pct': humidity, 
            'target_moisture_pct': target_moisture_pct, 
            'temp_c': temperature
        }])
        
        # 4. FORCE the columns into the exact order the model expects from training
        features = features[rf_model.feature_names_in_]
        
        # 5. Make the prediction
        predicted_vol = rf_model.predict(features)[0]
        return round(float(predicted_vol), 2)
        
    except Exception as e:
        print(f"Prediction error: {e}")
        return 500.0 # Fallback