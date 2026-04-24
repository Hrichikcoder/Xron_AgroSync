FROM python:3.12-slim

WORKDIR /code

COPY requirements.txt .

# --- NEW: Force the lightweight CPU-only version of PyTorch ---
RUN pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# --- Install the rest of the dependencies ---
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

# Added --reload here
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]