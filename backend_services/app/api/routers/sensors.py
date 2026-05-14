from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from influxdb_client import Point, WritePrecision
from app.schemas.payloads import SensorData, FlowData, SensorToggle, CeaTargetPayload
from app.db.influx import write_api, query_api
from app.core.config import settings
import app.core.state as state
from app.services.ml_service import predict_water_requirement

router = APIRouter(prefix="/api/sensors", tags=["Sensors"])

class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception:
                pass

manager = ConnectionManager()

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)

@router.post("/flow_update")
async def update_flow(data: FlowData):
    state.current_water_flow = data.water_flow
    state.current_flow_rate = data.flow_rate
    
    await manager.broadcast({
        "type": "flow_update",
        "water_flow": data.water_flow,
        "flow_rate": data.flow_rate
    })
    
    return {"message": "Flow data updated"}

@router.post("/update")
async def update_sensors(data: SensorData):
    try:
        state.live_sensor_data.update({
            "temperature": data.temperature,
            "humidity": data.humidity,
            "ldr": data.ldr,
            "soil_moisture": data.soil_moisture,
            "rain_level": data.rain_level,
            "depth_level": data.depth_level,
            "water_flow": getattr(data, 'water_flow', 0.0),
            "flow_rate": getattr(data, 'flow_rate', 0.0)
        })

        state.current_water_flow = getattr(data, 'water_flow', 0.0)
        state.current_flow_rate = getattr(data, 'flow_rate', 0.0)
        
        try:
            point = (
                Point("environment")
                .tag("node_id", data.node_id)
                .field("temperature", data.temperature)
                .field("humidity", data.humidity)
                .field("ldr", data.ldr)
                .field("soil_moisture", data.soil_moisture)
                .field("rain_level", data.rain_level)
                .field("depth", data.depth_level)
                .field("water_flow", getattr(data, 'water_flow', 0.0))
                .field("flow_rate", getattr(data, 'flow_rate', 0.0))
                .field("last_cycle_volume", getattr(data, 'last_cycle_volume', 0.0))
                .time(None, WritePrecision.NS)
            )
            write_api.write(bucket=settings.INFLUXDB_BUCKET, org=settings.INFLUXDB_ORG, record=point)
        except Exception as db_e:
            print(f"InfluxDB Write Error: {db_e}")

        predicted_vol = getattr(state, 'target_volume', 500.0)
        try:
            area = getattr(state, 'active_field_area_cm2', 40468564.2)
            if area is None or area == 0:
                area = 40468564.2

            predicted_vol = predict_water_requirement(
                temperature=data.temperature,
                humidity=data.humidity,
                soil_moisture=data.soil_moisture,
                ldr=data.ldr,
                rain_level=data.rain_level,
                area_cm2=area
            )
            state.target_volume = predicted_vol
        except Exception as ml_e:
            print(f"ML Prediction Error: {ml_e}")

        await manager.broadcast({
            "type": "sensor_update",
            "temperature": data.temperature,
            "humidity": data.humidity,
            "ldr": data.ldr,
            "soil_moisture": data.soil_moisture,
            "rain_level": data.rain_level,
            "depth": data.depth_level,
            "water_flow": getattr(data, 'water_flow', 0.0),
            "flow_rate": getattr(data, 'flow_rate', 0.0),
            "last_cycle_volume": getattr(data, 'last_cycle_volume', 0.0),
            "predicted_volume": predicted_vol
        })

        return {"message": "Data processed", "predicted_volume": predicted_vol}
    
    except Exception as e:
        print(f"Critical Route Error: {e}")
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

@router.get("/current")
async def get_current_sensors(node_id: str = "esp32_zone_1"):
    try:
        query = f"""
        from(bucket: "{settings.INFLUXDB_BUCKET}")
          |> range(start: -1h)
          |> filter(fn: (r) => r["_measurement"] == "environment")
          |> filter(fn: (r) => r["node_id"] == "{node_id}")
          |> last()
        """
        tables = query_api.query(query, org=settings.INFLUXDB_ORG)

        if not tables:
            raise HTTPException(status_code=404, detail="No recent sensor data found")

        latest_data = {}
        for table in tables:
            for record in table.records:
                latest_data[record.get_field()] = record.get_value()

        return latest_data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to query database: {str(e)}")

@router.get("/history")
async def get_sensor_history(hours: int = 24, node_id: str = "esp32_zone_1"):
    try:
        query = f"""
        from(bucket: "{settings.INFLUXDB_BUCKET}")
          |> range(start: -{hours}h)
          |> filter(fn: (r) => r["_measurement"] == "environment")
          |> filter(fn: (r) => r["node_id"] == "{node_id}")
          |> aggregateWindow(every: 5m, fn: mean, createEmpty: false)
          |> yield(name: "mean")
        """
        tables = query_api.query(query, org=settings.INFLUXDB_ORG)

        history = {
            "temperature": [], "humidity": [], "ldr": [],
            "soil_moisture": [], "rain_level": [], "depth": [], 
            "water_flow": [], "last_cycle_volume": []
        }

        for table in tables:
            for record in table.records:
                field = record.get_field()
                if field in history:
                    history[field].append({
                        "time": record.get_time().isoformat(),
                        "value": record.get_value()
                    })

        return history
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to query history: {str(e)}")

@router.get("/live_flow")
async def get_live_flow():
    return {
        "water_flow": state.current_water_flow,
        "flow_rate": state.current_flow_rate
    }

@router.get("/live")
async def get_live_sensor_data():
    return state.live_sensor_data

@router.post("/toggle")
async def toggle_sensor(data: SensorToggle):
    is_disabled = (data.state == 'off')
    
    if data.sensor == "soil_moisture":
        state.disable_soil_moisture = is_disabled
    elif data.sensor == "depth":
        state.disable_depth = is_disabled
    elif data.sensor == "temperature":
        state.disable_temperature = is_disabled
    elif data.sensor == "ldr":
        state.disable_ldr = is_disabled
    elif data.sensor == "rain_level":
        state.disable_rain_level = is_disabled
        
    return {"message": f"Sensor {data.sensor} disabled state set to {is_disabled}"}


@router.post("/set_targets")
async def set_cea_targets(data: CeaTargetPayload):
    # Save targets to global state so your actuator logic can use them
    state.cea_target_temp = data.target_temp
    state.cea_target_humidity = data.target_humidity
    
    # Broadcast new targets to web socket clients if needed
    await manager.broadcast({
        "type": "target_update",
        "crop": data.crop_name,
        "temp": data.target_temp,
        "humidity": data.target_humidity
    })
    
    return {"message": "CEA targets updated successfully"}