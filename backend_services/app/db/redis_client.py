import redis
import json
from app.core.config import settings

redis_client = redis.Redis.from_url(settings.REDIS_URL, decode_responses=True)

def set_cache(key: str, data: dict, expire: int = 3600):
    redis_client.setex(key, expire, json.dumps(data))

def get_cache(key: str):
    data = redis_client.get(key)
    if data:
        return json.loads(data)
    return None