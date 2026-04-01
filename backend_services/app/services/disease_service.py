import json
import torch
import torch.nn as nn
import torch.nn.functional as F
import torchvision.models as models
from torchvision import transforms
from PIL import Image
import io
import os
from app.data.disease_db import disease_details_db

DISEASE_MODEL_PATH = 'ml_models/plant_disease_model.pth'
CLASSES_JSON_PATH = 'ml_models/unified_classes.json'

with open(CLASSES_JSON_PATH, 'r') as f:
    dynamic_class_names = json.load(f)

NUM_CLASSES = len(dynamic_class_names)

disease_model = models.resnet18(weights=None)
disease_model.fc = nn.Linear(disease_model.fc.in_features, NUM_CLASSES)

state_dict = torch.load(DISEASE_MODEL_PATH, map_location=torch.device('cpu'), weights_only=True)
disease_model.load_state_dict(state_dict)
disease_model.eval()

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

def predict_disease(image_bytes: bytes):
    try:
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        input_tensor = transform(image).unsqueeze(0)
    except Exception:
        return {"status": "error", "message": "Invalid image format."}

    with torch.no_grad():
        outputs = disease_model(input_tensor)
        probabilities = F.softmax(outputs, dim=1)
        max_prob, predicted = torch.max(probabilities, 1)
        class_idx = predicted.item()
        confidence = round(max_prob.item(), 2)

    # Automatically handle whether the JSON is a List or a Dictionary
    if isinstance(dynamic_class_names, list):
        if class_idx < len(dynamic_class_names):
            raw_diagnosis = dynamic_class_names[class_idx]
        else:
            raw_diagnosis = f"Unknown Code {class_idx}"
    else:
        str_class_idx = str(class_idx)
        raw_diagnosis = dynamic_class_names.get(str_class_idx, f"Unknown Code {class_idx}")

    if "non_leaf" in raw_diagnosis.lower() or "not_leaf" in raw_diagnosis.lower():
        return {
            "status": "rejected",
            "message": "This is not a plant leaf. Please upload a clear leaf photo.",
            "confidence": confidence
        }

    if confidence < 0.80:
        return {
            "status": "uncertain",
            "message": "The system is unsure. Please try a clearer photo or a different angle.",
            "confidence": confidence
        }

    clean_diagnosis = raw_diagnosis.replace("__", " - ").replace("_", " ").title()
    
    # 1. Strip everything down to pure lowercase letters (e.g., "potatoearlyblight")
    normalized_target = raw_diagnosis.lower().replace("_", "").replace(" ", "").replace("-", "")
    
    # 2. Search the database ignoring all special characters and cases
    details = None
    for db_key, db_value in disease_details_db.items():
        normalized_db_key = db_key.lower().replace("_", "").replace(" ", "").replace("-", "")
        if normalized_db_key == normalized_target:
            details = db_value
            break
            
    # 3. Apply fallback ONLY if it truly doesn't exist anywhere in the DB
    if details is None:
        details = {
            "type": "Information Pending",
            "remedy": {
                "chemical": ["Consult local agricultural extension."],
                "maintenance": ["Ensure proper spacing and airflow."],
                "cultural": ["Rotate crops seasonally."],
                "biological": ["Introduce natural predators if applicable."],
                "notes": "Data for this specific disease is being updated."
            }
        }

    return {
        "status": "success",
        "diagnosis": clean_diagnosis,
        "details": details,
        "confidence": confidence,
        "prediction": class_idx
    }