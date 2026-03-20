from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from app.db.postgres import get_db
from app.models.user import UserProfile
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