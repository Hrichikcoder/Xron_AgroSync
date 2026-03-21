import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error
import joblib
import os

# 1. Setup paths based on your folder structure
# This finds the root 'backend_services' folder dynamically
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_PATH = os.path.join(BASE_DIR, 'dataset', 'intellifarm_irrigation_data.csv')
MODEL_PATH = os.path.join(BASE_DIR, 'ml_models', 'irrigation_flow_model.joblib')

print("Loading dataset...")
try:
    df = pd.read_csv(DATA_PATH)
except FileNotFoundError:
    print(f"ERROR: Could not find data at {DATA_PATH}. Did you run generate_data.py?")
    exit()

# 2. Prepare Features (Inputs) and Target (Output)
X = df[['area_cm2', 'current_moisture_pct', 'target_moisture_pct', 'temp_c', 'humidity_pct']]
y = df['required_flow_ml']

# 3. Split data (80% for training, 20% for testing the model's accuracy)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# 4. Train the Random Forest Model
print("Training the Random Forest Regressor...")
model = RandomForestRegressor(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# 5. Evaluate the Model
predictions = model.predict(X_test)
mae = mean_absolute_error(y_test, predictions)
print(f"Model trained successfully!")
print(f"Average Prediction Error: +/- {mae:.2f} ml")

# 6. Save the Model
# Create ml_models directory if it doesn't exist
os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
joblib.dump(model, MODEL_PATH)
print(f"Model saved successfully to:\n{MODEL_PATH}")