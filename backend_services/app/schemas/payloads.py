from pydantic import BaseModel
from typing import Optional

class SensorData(BaseModel):
    temperature: float
    humidity: float
    ldr: int
    soil_moisture: int
    rain_level: int
    depth_level: int
    water_flow: Optional[float] = 0.0
    last_cycle_volume: Optional[float] = 0.0
    node_id: Optional[str] = "esp32_zone_1"

class PredictionRequest(BaseModel):
    crop: str
    lat: float
    lon: float
    transport_rate: float = 2.5

class PumpControl(BaseModel):
    mode: str = "auto"
    pump1: bool = False
    pump2: bool = False
    shade: bool = False
    sprinkler: bool = False