import torch
import torch.nn as nn
import torchvision.models as models
from torchvision import transforms
from PIL import Image
import io
from app.core.config import settings
from app.data.disease_db import class_names, disease_details_db

# Load Model
state_dict = torch.load(settings.DISEASE_MODEL_PATH, map_location=torch.device('cpu'), weights_only=True)
model = models.resnet34(weights=None)

num_features = model.fc.in_features
num_classes = state_dict['fc.weight'].shape[0]

model.fc = nn.Linear(num_features, num_classes)
model.load_state_dict(state_dict)
model.eval()

# Image Transform
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

def predict_disease(image_bytes: bytes):
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    input_tensor = transform(image).unsqueeze(0)

    with torch.no_grad():
        outputs = model(input_tensor)
        _, predicted = torch.max(outputs, 1)
        class_idx = predicted.item()

    if class_idx < len(class_names):
        raw_diagnosis = class_names[class_idx]
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

    return clean_diagnosis, details