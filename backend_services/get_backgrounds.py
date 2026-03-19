import os
import urllib.request
import time
import socket

socket.setdefaulttimeout(10)

base_dir = "leaf_vs_not_leaf_dataset/not_leaf"
os.makedirs(base_dir, exist_ok=True)

existing_files = [f for f in os.listdir(base_dir) if os.path.isfile(os.path.join(base_dir, f)) and os.path.getsize(os.path.join(base_dir, f)) > 0]
current_count = len(existing_files)
target_count = 300

needed = target_count - current_count

print(f"Found {current_count} existing images.")

if needed <= 0:
    print("You already have 300 or more images. No need to download!")
else:
    print(f"Need to download {needed} more images...")
    
    downloads_completed = 0
    i = 1
    
    while downloads_completed < needed:
        filename = os.path.join(base_dir, f"random_bg_{i}.jpg")
        
        if os.path.exists(filename) and os.path.getsize(filename) > 0:
            i += 1
            continue
            
        url = f"https://picsum.photos/224/224?random={i}"
        
        try:
            urllib.request.urlretrieve(url, filename)
            downloads_completed += 1
            
            if downloads_completed % 10 == 0 or downloads_completed == needed:
                print(f"Downloaded {downloads_completed}/{needed} missing images...")
            time.sleep(0.1)
        except Exception as e:
            print(f"Failed to download image {i}: {e}")
        
        i += 1

    print(f"Download complete! You now have exactly {target_count} images.")