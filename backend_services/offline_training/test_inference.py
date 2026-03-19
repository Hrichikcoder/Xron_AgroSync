import sys
import os
import pandas as pd
import xgboost as xgb

# Add project root to path so we can import the config
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.core.config import settings

def test_model_inference():
    print(f"Loading model from: {settings.MARKET_MODEL_PATH}")
    model = xgb.XGBRegressor()
    
    try:
        model.load_model(settings.MARKET_MODEL_PATH)
        print("✅ Model loaded successfully!")
    except Exception as e:
        print(f"❌ Failed to load model. Did you run the training script yet? Error: {e}")
        return

    # Dynamically extract the features the model was trained on
    try:
        expected_features = model.feature_names_in_
    except AttributeError:
        expected_features = model.get_booster().feature_names
        
    print(f"\nModel expects {len(expected_features)} features. Top 5 features:")
    print(expected_features[:5])
    
    # Create a dummy DataFrame initialized with zeros for all expected features
    print("\nGenerating dummy data for a test prediction...")
    dummy_data = {feature: [0.0] for feature in expected_features}
    df_dummy = pd.DataFrame(dummy_data)
    
    # Inject some realistic numbers if these columns exist in your trained model
    if 'Latitude' in df_dummy.columns: df_dummy.at[0, 'Latitude'] = 26.8467   # Lucknow, UP Latitude
    if 'Longitude' in df_dummy.columns: df_dummy.at[0, 'Longitude'] = 80.9462 # Lucknow, UP Longitude
    if 'Min_Price' in df_dummy.columns: df_dummy.at[0, 'Min_Price'] = 2400.0
    if 'Max_Price' in df_dummy.columns: df_dummy.at[0, 'Max_Price'] = 2600.0
    if 'Lag_7' in df_dummy.columns: df_dummy.at[0, 'Lag_7'] = 2450.0
    if 'Lag_30' in df_dummy.columns: df_dummy.at[0, 'Lag_30'] = 2420.0
    if 'Price_Spread' in df_dummy.columns: df_dummy.at[0, 'Price_Spread'] = 200.0
    
    # Run the prediction
    print("Running prediction engine...")
    prediction = model.predict(df_dummy)[0]
    
    print("\n🔥 --- INFERENCE SUCCESSFUL --- 🔥")
    print(f"Predicted Modal Price: ₹{prediction:.2f} / Quintal")

if __name__ == "__main__":
    test_model_inference()