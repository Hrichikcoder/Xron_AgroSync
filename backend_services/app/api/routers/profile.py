from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from app.db.postgres import get_db
from app.models.user import UserProfile
from pydantic import BaseModel
from app.models.user import FarmField
import base64
import traceback

router = APIRouter(prefix="/api", tags=["Profile"])

@router.get("/get_profile")
async def get_profile(db: Session = Depends(get_db)):
    try:
        user = db.query(UserProfile).first()
        
        if not user:
            raise HTTPException(status_code=404, detail="No user found in database.")

        dp_base64 = None
        if user.profile_pic:
            dp_base64 = base64.b64encode(user.profile_pic).decode('utf-8')

        return {
            "status": "success",
            "user": {
                "name": user.name,
                "email": user.email,
                "phone": user.phone,
                "location": user.location,
                "profile_pic_base64": dp_base64
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
    location: str = Form(...),
    profile_pic: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    try:
        image_bytes = None
        if profile_pic:
            image_bytes = await profile_pic.read()

        user = db.query(UserProfile).first()
        
        if user:
            user.name = name
            user.email = email
            user.phone = phone
            user.location = location
            if image_bytes:
                user.profile_pic = image_bytes
            db.commit()
            return {"status": "success", "message": "Profile updated!"}
        else:
            raise HTTPException(status_code=404, detail="No user found to update. Did you run the INSERT SQL query?")
            
    except HTTPException:
        raise # Let normal HTTP exceptions pass through
    except Exception as e:
        db.rollback()
        # THIS PRINTS THE EXACT CRASH REASON TO YOUR TERMINAL
        print(f"\n--- ERROR IN UPDATE_PROFILE ---\n{traceback.format_exc()}\n-------------------------------\n")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    
# Create a Pydantic schema for input validation
class FieldCreate(BaseModel):
    name: str
    area: str

# ADD THESE ROUTES
@router.get("/get_fields")
async def get_fields(db: Session = Depends(get_db)):
    try:
        fields = db.query(FarmField).all()
        return {
            "status": "success", 
            "fields": [{"id": f.id, "name": f.name, "area": f.area} for f in fields]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/add_field")
async def add_field(field: FieldCreate, db: Session = Depends(get_db)):
    try:
        new_field = FarmField(name=field.name, area=field.area)
        db.add(new_field)
        db.commit()
        return {"status": "success", "field": {"id": new_field.id, "name": new_field.name, "area": new_field.area}}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/delete_field/{field_id}")
async def delete_field(field_id: int, db: Session = Depends(get_db)):
    try:
        db.query(FarmField).filter(FarmField.id == field_id).delete()
        db.commit()
        return {"status": "success"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    
    # Add to routers/profile.py (or a new settings router)
from pydantic import BaseModel
import app.core.state as state

class ActiveFieldPayload(BaseModel):
    area_acres: float

@router.post("/set_active_field")
async def set_active_field(payload: ActiveFieldPayload):
    state.active_field_area_cm2 = payload.area_acres
    return {"status": "success", "active_area_cm2": state.active_field_area_cm2}