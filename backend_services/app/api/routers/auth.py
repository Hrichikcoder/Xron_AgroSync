# app/api/routers/auth.py
import random
import httpx
from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends
from pydantic import BaseModel
from app.db.redis_client import redis_client # Using your existing Redis client
from app.core.config import settings # Assuming you have a config file for keys
from app.models.user import UserProfile
from app.db.postgres import get_db
from sqlalchemy.orm import Session
from app.schemas.payloads import RegisterPayload

router = APIRouter(prefix="/auth", tags=["Authentication"])

# In a real app, put these in your .env / config.py
TEXTBEE_API_KEY = "d5420e5b-f4d3-469a-9003-d343de65c4a1"
TEXTBEE_DEVICE_ID = "69c546b6c3538b609d13d100"

class PhonePayload(BaseModel):
    phone: str
    is_register: bool = False

class VerifyPayload(BaseModel):
    phone: str
    otp: str

async def send_textbee_sms(phone: str, message: str):
    url = f"https://api.textbee.dev/api/v1/gateway/devices/{TEXTBEE_DEVICE_ID}/send-sms"
    headers = {
        "x-api-key": TEXTBEE_API_KEY,
        "Content-Type": "application/json"
    }
    payload = {
        "recipients": [phone],
        "message": message
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(url, headers=headers, json=payload)
        if response.status_code not in [200, 201]:
            print(f"TextBee Error: {response.text}")

@router.post("/send-otp")
async def send_otp(payload: PhonePayload, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    # 0. Check if User Exists according to Auth intent (Sign In vs Sign Up)
    user = db.query(UserProfile).filter(UserProfile.phone == payload.phone).first()
    
    if not payload.is_register and not user:
        raise HTTPException(status_code=404, detail="User not found. Please sign up first.")
    if payload.is_register and user:
        raise HTTPException(status_code=400, detail="User already exists. Please sign in.")

    cooldown_key = f"otp_cooldown:{payload.phone}"
    if redis_client.get(cooldown_key):
        raise HTTPException(
            status_code=429, 
            detail="OTP already sent. Please wait 60 seconds before requesting a new one."
        )
    
    # Set a 60-second lock to prevent multiple SMS fires
    redis_client.setex(cooldown_key, 60, "locked")

    # 1. Generate a 6-digit OTP
    otp = str(random.randint(100000, 999999))
    
    # 2. Store in Redis with a 5-minute (300 seconds) expiration
    redis_key = f"otp:{payload.phone}"
    redis_client.setex(redis_key, 300, otp)
    
    # 3. Send SMS via TextBee in the background so the API responds instantly
    message = f"Your IntelliFarm verification code is: {otp}. It will expire in 5 minutes."
    background_tasks.add_task(send_textbee_sms, payload.phone, message)
    
    return {"status": "success", "message": "OTP sent successfully"}

@router.post("/verify-otp")
async def verify_otp(payload: VerifyPayload, db: Session = Depends(get_db)):
    redis_key = f"otp:{payload.phone}"
    stored_otp = redis_client.get(redis_key)
    
    # 1. Check if OTP exists and matches
    stored_val = stored_otp.decode('utf-8') if isinstance(stored_otp, bytes) else stored_otp
    if not stored_val or stored_val != payload.otp:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")
    
    # 2. Delete OTP after successful verification to prevent reuse
    redis_client.delete(redis_key)
    
    # 3. Check if user exists in PostgreSQL database
    user = db.query(UserProfile).filter(UserProfile.phone == payload.phone).first()
    
    # 4. IF USER DOES NOT EXIST
    if not user:
        return {
            "status": "success", 
            "message": "OTP verified, but user profile not found. Please sign up.",
            "is_registered": False, # Frontend checks this to navigate to the Signup Screen
            "phone": payload.phone 
        }
        
    # 5. IF USER EXISTS -> Complete the Login
    fake_jwt_token = f"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fake_payload_for_user_{user.id}"
    
    return {
        "status": "success", 
        "message": "Login successful",
        "is_registered": True, # Frontend checks this to navigate to Dashboard
        "user": {
            "id": user.id,
            "phone": user.phone,
            "name": user.name
        },
        "token": fake_jwt_token
    }

# NEW ENDPOINT: Dedicated Sign-Up Route
@router.post("/register")
async def register_user(payload: RegisterPayload, db: Session = Depends(get_db)):
    # 1. Verify OTP first
    redis_key = f"otp:{payload.phone}"
    stored_otp = redis_client.get(redis_key)
    
    stored_val = stored_otp.decode('utf-8') if isinstance(stored_otp, bytes) else stored_otp
    if not stored_val or stored_val != payload.otp:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")
        
    # 2. Delete OTP to prevent reuse
    redis_client.delete(redis_key)

    # 3. Double-check if the user already exists to prevent duplicates
    existing_user = db.query(UserProfile).filter(UserProfile.phone == payload.phone).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="User with this phone number already exists.")

    # 4. Create the new user profile
    new_user = UserProfile(
        phone=payload.phone,
        name=payload.name,
        email=payload.email
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # 5. Generate JWT Token for the newly registered user
    fake_jwt_token = f"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fake_payload_for_user_{new_user.id}"

    return {
        "status": "success",
        "message": "User registered and logged in successfully",
        "user": {
            "id": new_user.id,
            "phone": new_user.phone,
            "name": new_user.name
        },
        "token": fake_jwt_token
    }