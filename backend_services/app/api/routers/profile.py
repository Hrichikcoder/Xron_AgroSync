# app/api/routers/profile.py
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException, Header
from sqlalchemy.orm import Session
from app.db.postgres import get_db
from app.models.user import UserProfile, FarmField
from pydantic import BaseModel
import base64
import traceback
import jwt
from app.core.config import settings
import app.core.state as state

router = APIRouter(prefix="/api", tags=["Profile & Fields"])

# JWT Configuration (Must match auth.py)
SECRET_KEY = getattr(settings, 'SECRET_KEY', "your_super_secret_key")
ALGORITHM = "HS256"

# ---------------------------------------------------------
# DEPENDENCY: DECODE JWT TOKEN & GET USER ID
# ---------------------------------------------------------
async def get_current_user_id(authorization: str = Header(...)):
    """Extracts the user ID from the JWT Bearer token sent by the Flutter app."""
    try:
        scheme, token = authorization.split()
        if scheme.lower() != "bearer":
            raise HTTPException(status_code=401, detail="Invalid authentication scheme")
            
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub") 
        
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token payload")
        return int(user_id)
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid token")

# ---------------------------------------------------------
# PROFILE MANAGEMENT (USER SPECIFIC)
# ---------------------------------------------------------

@router.get("/get_profile")
async def get_profile(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    try:
        # Strictly fetch the profile matching the token's User ID
        user = db.query(UserProfile).filter(UserProfile.id == user_id).first()
        
        if not user:
            raise HTTPException(status_code=404, detail="User not found in database.")

        dp_base64 = None
        if user.profile_pic:
            dp_base64 = base64.b64encode(user.profile_pic).decode('utf-8')

        return {
            "status": "success",
            "user": {
                "name": user.name,
                "email": user.email,
                "phone": user.phone,
                "location": getattr(user, 'location', 'Unknown'), # Failsafe if location isn't in DB yet
                "profile_pic_base64": dp_base64,
                "sms_alerts": getattr(user, 'sms_alerts', False) # NEW: Include SMS alerts preference
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"\n--- ERROR IN GET_PROFILE ---\n{traceback.format_exc()}\n----------------------------\n")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.post("/update_profile")
async def update_profile(
    name: str = Form(...),
    email: str = Form(...),
    phone: str = Form(...),
    location: str = Form("Unknown"),
    sms_alerts: str = Form(None), # NEW: Added sms_alerts parameter
    profile_pic: UploadFile = File(None),
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    try:
        image_bytes = None
        if profile_pic:
            image_bytes = await profile_pic.read()

        # Strictly update the profile matching the token's User ID
        user = db.query(UserProfile).filter(UserProfile.id == user_id).first()
        
        if user:
            user.name = name
            user.email = email
            user.phone = phone
            # Update location if the column exists in your DB model
            if hasattr(user, 'location'):
                user.location = location
                
            # NEW: Update SMS alerts if provided and column exists
            if sms_alerts is not None and hasattr(user, 'sms_alerts'):
                user.sms_alerts = (sms_alerts.lower() == 'true')
                
            if image_bytes:
                user.profile_pic = image_bytes
            db.commit()
            return {"status": "success", "message": "Profile updated!"}
        else:
            raise HTTPException(status_code=404, detail="User not found.")
            
    except HTTPException:
        raise 
    except Exception as e:
        db.rollback()
        print(f"\n--- ERROR IN UPDATE_PROFILE ---\n{traceback.format_exc()}\n-------------------------------\n")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# ---------------------------------------------------------
# FIELD MANAGEMENT (USER SPECIFIC)
# ---------------------------------------------------------

class FieldCreate(BaseModel):
    name: str
    area: str

class FieldUpdate(BaseModel):
    name: str
    area: str

@router.get("/get_fields")
async def get_fields(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    try:
        # Fetch ONLY fields belonging to the logged-in user
        fields = db.query(FarmField).filter(FarmField.user_id == user_id).all()
        return {
            "status": "success", 
            "fields": [{"id": f.id, "name": f.name, "area": f.area} for f in fields]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/add_field")
async def add_field(
    field: FieldCreate, 
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    try:
        # Attach the field strictly to the logged-in user
        new_field = FarmField(name=field.name, area=field.area, user_id=user_id)
        db.add(new_field)
        db.commit()
        db.refresh(new_field)
        return {"status": "success", "field": {"id": new_field.id, "name": new_field.name, "area": new_field.area}}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/update_field/{field_id}")
async def update_field(
    field_id: int, 
    field: FieldUpdate, 
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    try:
        # Ensure the field belongs to this exact user before updating
        db_field = db.query(FarmField).filter(FarmField.id == field_id, FarmField.user_id == user_id).first()
        if not db_field:
            raise HTTPException(status_code=404, detail="Field not found or unauthorized")
        
        db_field.name = field.name
        db_field.area = field.area
        db.commit()
        db.refresh(db_field)
        
        return {"status": "success", "field": {"id": db_field.id, "name": db_field.name, "area": db_field.area}}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/delete_field/{field_id}")
async def delete_field(
    field_id: int, 
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    try:
        # Ensure the field belongs to this exact user before deleting
        db_field = db.query(FarmField).filter(FarmField.id == field_id, FarmField.user_id == user_id).first()
        if not db_field:
            raise HTTPException(status_code=404, detail="Field not found or unauthorized")
        
        db.delete(db_field)
        db.commit()
        return {"status": "success"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

# ---------------------------------------------------------
# ACTIVE FIELD STATE MANAGEMENT
# ---------------------------------------------------------

class ActiveFieldPayload(BaseModel):
    area_acres: float

@router.post("/set_active_field")
async def set_active_field(payload: ActiveFieldPayload):
    # Update global app state for AI calculations
    state.active_field_area_cm2 = payload.area_acres
    return {"status": "success", "active_area_cm2": state.active_field_area_cm2}