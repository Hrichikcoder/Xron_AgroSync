from fastapi import APIRouter, WebSocket, WebSocketDisconnect, BackgroundTasks, Depends
from pydantic import BaseModel
from typing import List
from datetime import datetime
import asyncio
from sqlalchemy.orm import Session
from app.db.postgres import get_db
from app.models.user import UserProfile
from app.api.routers.auth import send_textbee_sms # Importing the SMS function from auth.py

router = APIRouter(prefix="/api/notifications", tags=["Notifications"])

# Schema for the incoming ESP32 payload
class NotificationPayload(BaseModel):
    message: str
    type: str = "alert" # "alert", "info", "warning"
    node_id: str = "esp32_zone_1"

# --- NEW: In-Memory Storage for Notification History ---
# For production, replace this list with a database table insertion
notification_history = [] 

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        async def send_to_one(connection: WebSocket):
            try:
                await connection.send_json(message)
            except Exception:
                # If a send fails (e.g., mobile app went to background/lost WiFi),
                # assume the connection is dead and clean it up immediately.
                self.disconnect(connection)

        # Use asyncio.gather to fire all messages concurrently instead of sequentially
        if self.active_connections:
            await asyncio.gather(*(send_to_one(c) for c in self.active_connections))

manager = ConnectionManager()

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text() 
    except WebSocketDisconnect:
        manager.disconnect(websocket)

@router.post("/send")
async def receive_notification_from_esp32(
    notification: NotificationPayload,
    background_tasks: BackgroundTasks, # Added for async SMS sending
    db: Session = Depends(get_db)      # Added to fetch user preferences
):
    # 1. Create the notification object with a timestamp
    notif_data = notification.dict()
    notif_data["timestamp"] = datetime.now().isoformat()
    notif_data["id"] = str(int(datetime.now().timestamp() * 1000))

    # 2. Save it to history (keeping only the latest 50 for memory safety)
    notification_history.insert(0, notif_data)
    if len(notification_history) > 50:
        notification_history.pop()

    # 3. Broadcast to currently connected apps
    await manager.broadcast(notif_data)

    # --- NEW: Check if notification is critical and send SMS ---
    is_critical = False
    lower_message = notification.message.lower()
    
    if notification.type == "critical":
        is_critical = True
    elif "water depth less than 0" in lower_message or "empty tank" in lower_message:
        is_critical = True
    elif "irrigation cycle completion" in lower_message or "completed watering" in lower_message:
        is_critical = True

    if is_critical:
        # Fetch all users who have opted in for SMS alerts
        users = db.query(UserProfile).all()
        for user in users:
            # Check if user has sms_alerts column enabled and a phone number
            if getattr(user, 'sms_alerts', False) and user.phone:
                sms_message = f"AgroSync Alert: {notification.message}"
                background_tasks.add_task(send_textbee_sms, user.phone, sms_message)

    return {"status": "Notification broadcasted successfully"}

# --- NEW ENDPOINT: Fetch history on App Load ---
@router.get("/history")
async def get_notification_history():
    return {"status": "success", "notifications": notification_history}