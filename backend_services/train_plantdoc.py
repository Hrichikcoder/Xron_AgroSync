import os
import shutil
import json
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader
from tqdm import tqdm

def merge_multiple_datasets(dataset_dirs, combined_dir):
    os.makedirs(combined_dir, exist_ok=True)
    for d in dataset_dirs:
        if os.path.exists(d):
            for class_name in os.listdir(d):
                src_class_dir = os.path.join(d, class_name)
                dst_class_dir = os.path.join(combined_dir, class_name)
                if os.path.isdir(src_class_dir):
                    os.makedirs(dst_class_dir, exist_ok=True)
                    for file_name in os.listdir(src_class_dir):
                        src_file = os.path.join(src_class_dir, file_name)
                        dst_file = os.path.join(dst_class_dir, file_name)
                        if not os.path.exists(dst_file):
                            shutil.copy2(src_file, dst_file)

def train_optimal_model(dataset_dirs, base_epochs=10, finetune_epochs=40, batch_size=32):
    combined_dir = 'dataset/CombinedData/train'
    print("Merging datasets into CombinedData folder...")
    merge_multiple_datasets(dataset_dirs, combined_dir)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"\nDevice: {device.type.upper()}")

    train_transforms = transforms.Compose([
        transforms.RandomResizedCrop(224),
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(20),
        transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ])

    train_dataset = datasets.ImageFolder(combined_dir, transform=train_transforms)
    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)

    num_classes = len(train_dataset.classes)
    print(f"Total combined classes: {num_classes}\n")

    os.makedirs('ml_models', exist_ok=True)
    with open('ml_models/plantdoc_classes.json', 'w') as f:
        json.dump(train_dataset.classes, f, indent=4)

    model = models.resnet34(weights=models.ResNet34_Weights.DEFAULT)
    
    for param in model.parameters():
        param.requires_grad = False

    num_ftrs = model.fc.in_features
    model.fc = nn.Linear(num_ftrs, num_classes)
    model = model.to(device)

    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.fc.parameters(), lr=0.001)

    print(f"--- PHASE 1: Training Classification Head ({base_epochs} Epochs) ---")
    for epoch in range(base_epochs):
        model.train()
        running_loss = 0.0
        correct = 0
        total = 0
        progress_bar = tqdm(train_loader, desc=f"Phase 1 - Epoch {epoch+1}/{base_epochs}", unit="batch")

        for inputs, labels in progress_bar:
            inputs, labels = inputs.to(device), labels.to(device)
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            running_loss += loss.item() * inputs.size(0)
            _, predicted = outputs.max(1)
            total += labels.size(0)
            correct += predicted.eq(labels).sum().item()
            progress_bar.set_postfix(loss=f"{(running_loss / total):.4f}", acc=f"{(100. * correct / total):.2f}%")

    for param in model.parameters():
        param.requires_grad = True

    optimizer = optim.Adam(model.parameters(), lr=0.0001)

    print(f"\n--- PHASE 2: Deep Fine-Tuning Entire Model ({finetune_epochs} Epochs) ---")
    for epoch in range(finetune_epochs):
        model.train()
        running_loss = 0.0
        correct = 0
        total = 0
        progress_bar = tqdm(train_loader, desc=f"Phase 2 - Epoch {epoch+1}/{finetune_epochs}", unit="batch")

        for inputs, labels in progress_bar:
            inputs, labels = inputs.to(device), labels.to(device)
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            running_loss += loss.item() * inputs.size(0)
            _, predicted = outputs.max(1)
            total += labels.size(0)
            correct += predicted.eq(labels).sum().item()
            progress_bar.set_postfix(loss=f"{(running_loss / total):.4f}", acc=f"{(100. * correct / total):.2f}%")

    save_path = 'ml_models/plant_disease_model_finetuned.pth'
    torch.save(model.state_dict(), save_path)
    print(f"\n✅ Training Complete! Overwrote previous model at: {save_path}")
    
    junk_model = 'ml_models/plantdoc_disease_model.pth'
    if os.path.exists(junk_model):
        os.remove(junk_model)
        print("🧹 Cleaned up unnecessary models.")

if __name__ == '__main__':
    datasets_to_merge = [

        
        'dataset/train',
        'leaf_vs_not_leaf_dataset/train',
        'dataset/PlantDoc/train'
    ]
    
    train_optimal_model(dataset_dirs=datasets_to_merge, base_epochs=10, finetune_epochs=40)