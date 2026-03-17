from influxdb_client import InfluxDBClient
from influxdb_client.client.write_api import SYNCHRONOUS
from app.core.config import settings

client = InfluxDBClient(
    url=settings.INFLUXDB_URL, 
    token=settings.INFLUXDB_TOKEN, 
    org=settings.INFLUXDB_ORG
)

write_api = client.write_api(write_options=SYNCHRONOUS)
query_api = client.query_api()