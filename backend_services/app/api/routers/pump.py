from fastapi import APIRouter
from app.schemas.payloads import PumpControl
import app.core.state as state

router = APIRouter(prefix="/api/control", tags=["Pump Control"])

@router.post("/pump")
async def control_pump(command: PumpControl):
    state.pump_mode = command.mode
    state.pump1_state = command.pump1
    state.pump2_state = command.pump2
    state.shade_state = command.shade
    state.sprinkler_state = command.sprinkler
    return {
        "message": "Pump state updated",
        "state": {
            "mode": state.pump_mode,
            "pump1": state.pump1_state,
            "pump2": state.pump2_state,
            "shade": state.shade_state,
            "sprinkler": state.sprinkler_state
        }
    }

@router.get("/status")
async def get_pump_status():
    return {
        "mode": state.pump_mode,
        "pump1": state.pump1_state,
        "pump2": state.pump2_state,
        "shade": state.shade_state,
        "sprinkler": state.sprinkler_state
    }