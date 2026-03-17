from fastapi import APIRouter, HTTPException
from influxdb_client import Point, WritePrecision
from app.schemas.payloads import SensorData
from app.db.influx import write_api, query_api
from app.core.config import settings

router = APIRouter(prefix="/api/sensors", tags=["Sensors"])

@router.post("/update")
async def update_sensors(data: SensorData):
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
            .field("water_flow", data.water_flow)
            .field("last_cycle_volume", getattr(data, 'last_cycle_volume', 0.0))
            .time(None, WritePrecision.NS)
        )
        write_api.write(bucket=settings.INFLUXDB_BUCKET, org=settings.INFLUXDB_ORG, record=point)
        return {"message": "Data successfully written to InfluxDB"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to write to database: {str(e)}")

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