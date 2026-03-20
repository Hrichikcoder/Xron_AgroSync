from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from typing import List

router = APIRouter(prefix="/api/notifications", tags=["Notifications"])

# Schema for the incoming ESP32 payload
class NotificationPayload(BaseModel):
    message: str
    type: str = "alert" # "alert", "info", "warning"
    node_id: str = "esp32_zone_1"

# Connection manager to handle active frontend WebSocket connections
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            await connection.send_json(message)

manager = ConnectionManager()

# 1. Endpoint for the Frontend to connect to (Real-time stream)
@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text() 
    except WebSocketDisconnect:
        manager.disconnect(websocket)

# 2. Endpoint for the ESP32 to send alerts to
@router.post("/send")
async def receive_notification_from_esp32(notification: NotificationPayload):
    # Broadcast the ESP32 message directly to all connected frontends
    await manager.broadcast(notification.dict())
    return {"status": "Notification broadcasted successfully"}