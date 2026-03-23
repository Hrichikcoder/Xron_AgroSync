import json
import torch
import torch.nn as nn
import torch.nn.functional as F
import torchvision.models as models
from torchvision import transforms
from PIL import Image
import io
import os
from app.core.config import settings
from app.data.disease_db import disease_details_db

DISEASE_MODEL_PATH = 'ml_models/plant_disease_model_finetuned.pth'
LEAF_DETECTOR_PATH = 'ml_models/leaf_detector_binary.pth'
CLASSES_JSON_PATH = 'ml_models/plantdoc_classes.json'

with open(CLASSES_JSON_PATH, 'r') as f:
    dynamic_class_names = json.load(f)

NUM_DISEASE_CLASSES = len(dynamic_class_names)

disease_model = models.resnet34(weights=None)
disease_model.fc = nn.Linear(disease_model.fc.in_features, NUM_DISEASE_CLASSES)

state_dict = torch.load(DISEASE_MODEL_PATH, map_location=torch.device('cpu'), weights_only=True)
disease_model.load_state_dict(state_dict)
disease_model.eval()

leaf_detector = models.mobilenet_v2()
leaf_detector.classifier[1] = nn.Linear(leaf_detector.last_channel, 1)

if os.path.exists(LEAF_DETECTOR_PATH):
    leaf_detector.load_state_dict(torch.load(LEAF_DETECTOR_PATH, map_location=torch.device('cpu'), weights_only=True))

leaf_detector.eval()

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

    if os.path.exists(LEAF_DETECTOR_PATH):
        with torch.no_grad():
            output = leaf_detector(input_tensor)
            prob = torch.sigmoid(output).item()
            
            if prob > 0.5:
                return {
                    "status": "rejected",
                    "message": "This is not a plant leaf. Please upload a clear leaf photo.",
                    "confidence": round(prob, 2)
                }

    with torch.no_grad():
        outputs = disease_model(input_tensor)
        probabilities = F.softmax(outputs, dim=1)
        max_prob, predicted = torch.max(probabilities, 1)
        class_idx = predicted.item()

    if max_prob.item() > 0.80:
        return {
            "status": "uncertain",
            "message": "The system is unsure. Please try a clearer photo or a different angle.",
            "confidence": round(max_prob.item(), 2)
        }

    if class_idx < len(dynamic_class_names):
        raw_diagnosis = dynamic_class_names[class_idx]
        clean_diagnosis = raw_diagnosis.replace("__", " - ").replace("_", " ")
        details = disease_details_db.get(raw_diagnosis, {
            "type": "Data Unavailable",
            "remedy": {
                "notes": "Consult local agricultural extension for this specific disease."
            }
        })
    else:
        clean_diagnosis = f"Unknown Disease Code {class_idx}"
        details = {}

    return {
        "status": "success",
        "diagnosis": clean_diagnosis,
        "details": details,
        "confidence": round(max_prob.item(), 2),
        "prediction": class_idx
    }
