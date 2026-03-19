import os
import random
import shutil

source_dataset_dir = "dataset/train"
target_leaf_dir = "leaf_vs_not_leaf_dataset/leaf"

os.makedirs(target_leaf_dir, exist_ok=True)

all_images = []
valid_extensions = ('.jpg', '.jpeg', '.png')

for root, dirs, files in os.walk(source_dataset_dir):
    for file in files:
        if file.lower().endswith(valid_extensions):
            all_images.append(os.path.join(root, file))

if not all_images:
    print("No images found in the specified source directory.")
else:
    num_to_select = min(300, len(all_images))
    selected_images = random.sample(all_images, num_to_select)

    for i, img_path in enumerate(selected_images):
        extension = os.path.splitext(img_path)[1]
        new_name = f"leaf_{i+1}{extension}"
        destination = os.path.join(target_leaf_dir, new_name)
        shutil.copy2(img_path, destination)

    print(f"Successfully copied {len(selected_images)} leaf images.")