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
    flow_rate: Optional[float] = 0.0
    last_cycle_volume: Optional[float] = 0.0
    node_id: Optional[str] = "esp32_zone_1"

class FlowData(BaseModel):
    water_flow: float
    flow_rate: float
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

class FeedbackPayload(BaseModel):
    user_id: str
    crop_name: str
    selling_price: float
    market_name: str
    lat: Optional[float] = None
    lon: Optional[float] = None

class SensorToggle(BaseModel):
    sensor: str
    state: str

class PhonePayload(BaseModel):
    phone: str
    is_register: bool = False

class VerifyPayload(BaseModel):
    phone: str
    otp: str

# NEW: Payload for the actual sign-up step
class RegisterPayload(BaseModel):
    phone: str
    name: str
    email: str
    otp: str

class CeaTargetPayload(BaseModel):
    crop_name: str
    target_temp: float
    target_humidity: float
    target_light: float
    mode: str = "auto"