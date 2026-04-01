from fastapi import APIRouter
from app.schemas.payloads import PumpControl
import app.core.state as state

router = APIRouter(prefix="/api/control", tags=["Pump Control"])

@router.post("/pump")
async def control_pump(command: PumpControl):
    state.pump_mode = command.mode
    state.pump1_state = command.pump1
    state.pump2_state = command.pump2
    state.sprinkler_state = command.sprinkler
    
    return {
        "message": "Pump state updated",
        "state": {
            "mode": state.pump_mode,
            "pump1": state.pump1_state,
            "pump2": state.pump2_state,
            "sprinkler": state.sprinkler_state,
            "target_volume": getattr(state, "target_volume", 500.0)
        }
    }

@router.post("/shade")
async def control_shade(payload: dict):
    state.shade_state = payload.get("shade", False)
    return {"message": "Shade state updated", "shade": state.shade_state}

@router.post("/shade_override")
async def set_shade_override(payload: dict):
    state.shade_override = payload.get("override", False)
    return {"message": "Shade override updated", "override": getattr(state, "shade_override", False)}

@router.get("/status")
async def get_pump_status():
    should_run_diag = state.trigger_hw_diag
    if should_run_diag:
        state.trigger_hw_diag = False
    return {
        "mode": state.pump_mode,
        "pump1": state.pump1_state,
        "pump2": state.pump2_state,
        "shade": state.shade_state,
        "sprinkler": state.sprinkler_state,
        "target_volume": getattr(state, "target_volume", 500.0), 
        "run_diag": should_run_diag,
        "shade_override": getattr(state, "shade_override", False),
        "disable_soil_moisture": getattr(state, "disable_soil_moisture", False),
        "disable_depth": getattr(state, "disable_depth", False),
        "disable_temperature": getattr(state, "disable_temperature", False),
        "disable_ldr": getattr(state, "disable_ldr", False),
        "disable_rain_level": getattr(state, "disable_rain_level", False)
    }

@router.post("/trigger_diagnostics")
async def trigger_diagnostics():
    state.trigger_hw_diag = True
    return {"message": "Hardware diagnostics triggered"}