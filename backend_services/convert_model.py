import joblib
import m2cgen as m2c
import os

# 1. Setup paths (adjust BASE_DIR if you run this from a different folder)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, 'ml_models', 'irrigation_flow_model.joblib')
C_MODEL_PATH = os.path.join(BASE_DIR, 'ml_models', 'rf_model.h')

print(f"Loading existing model from:\n{MODEL_PATH}")

try:
    # 2. Load your pre-trained Random Forest model
    model = joblib.load(MODEL_PATH)
    print("Model loaded successfully!")
    
    # 3. Convert the model to pure C code
    print("Converting model to C code... (This might take a few seconds)")
    c_code = m2c.export_to_c(model)
    
    # 4. Save the generated C code as a header file
    os.makedirs(os.path.dirname(C_MODEL_PATH), exist_ok=True)
    with open(C_MODEL_PATH, "w") as f:
        f.write(c_code)
        
    print(f"Success! C model saved to:\n{C_MODEL_PATH}")

except FileNotFoundError:
    print("ERROR: Could not find the .joblib file. Check your file paths!")