import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import transforms, models
from PIL import Image
import os

DISEASE_MODEL_PATH = 'ml_models/plant_disease_model_finetuned.pth'
LEAF_DETECTOR_PATH = 'ml_models/leaf_detector_binary.pth'
NUM_DISEASE_CLASSES = 52

image_transforms = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

def load_models():
    disease_model = models.resnet34() 
    disease_model.fc = nn.Linear(disease_model.fc.in_features, NUM_DISEASE_CLASSES)
    disease_model.load_state_dict(torch.load(DISEASE_MODEL_PATH, map_location=torch.device('cpu')))
    disease_model.eval()

    leaf_detector = models.mobilenet_v2()
    leaf_detector.classifier[1] = nn.Linear(leaf_detector.last_channel, 1)
    
    if os.path.exists(LEAF_DETECTOR_PATH):
        leaf_detector.load_state_dict(torch.load(LEAF_DETECTOR_PATH, map_location=torch.device('cpu')))
    else:
        print("Warning: Leaf detector model not found. Gatekeeper is disabled.")
        
    leaf_detector.eval()

    return disease_model, leaf_detector

def process_uploaded_image(image_path, disease_model, leaf_detector):
    try:
        image = Image.open(image_path).convert('RGB')
        image_tensor = image_transforms(image).unsqueeze(0)
    except Exception as e:
        return {"error": "Invalid image format.", "confidence": 0.0}

    if os.path.exists(LEAF_DETECTOR_PATH):
        with torch.no_grad():
            output = leaf_detector(image_tensor)
            prob = torch.sigmoid(output).item()
            
            if prob > 0.5:
                return {
                    "status": "rejected",
                    "message": "Image does not appear to be a plant leaf. Please upload a clear picture of a leaf.",
                    "confidence": f"{prob:.2f}"
                }

    with torch.no_grad():
        outputs = disease_model(image_tensor)
        probabilities = F.softmax(outputs, dim=1)
        max_prob, predicted_class = torch.max(probabilities, 1)
        
        if max_prob.item() < 0.80:
            return {
                "status": "uncertain",
                "message": "Uncertain diagnosis. The leaf might be healthy or have a disease I don't recognize. Please upload a clearer image.",
                "confidence": f"{max_prob.item():.2f}"
            }
            
        return {
            "status": "success",
            "class_id": predicted_class.item(),
            "confidence": f"{max_prob.item():.2f}"
        }

if __name__ == "__main__":
    print("Loading models...")
    disease_net, leaf_net = load_models()
    
    test_image = "leaf_vs_not_leaf_dataset/leaf/leaf_291.jpg" 
    
    if os.path.exists(test_image):
        print(f"Processing {test_image}...")
        result = process_uploaded_image(test_image, disease_net, leaf_net)
        print("Result:", result)
    else:
        print("Please provide a valid test image path at the bottom of the script.")