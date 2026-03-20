import os
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

class Settings:
    INFLUXDB_URL = os.getenv("INFLUXDB_URL", "http://localhost:8086")
    INFLUXDB_TOKEN = os.getenv("INFLUXDB_TOKEN")
    INFLUXDB_ORG = os.getenv("INFLUXDB_ORG", "smart_irrigation")
    INFLUXDB_BUCKET = os.getenv("INFLUXDB_BUCKET", "sensor_data")
    
    REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    
    DATASET_DIR = os.path.join(BASE_DIR, "dataset")
    DISEASE_MODEL_PATH = os.path.join(BASE_DIR, "ml_models", "plant_disease_model_finetuned.pth")
    MARKET_MODEL_PATH = os.path.join(BASE_DIR, "ml_models", "price_prediction_model.json")

    POSTGRES_URL = os.getenv("POSTGRES_URL", "postgresql://postgres:password@localhost:5432/agrosync_db")
    
settings = Settings()