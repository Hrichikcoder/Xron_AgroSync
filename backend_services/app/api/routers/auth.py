# app/api/routers/auth.py
import random
import httpx
import jwt 
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends
from pydantic import BaseModel
from app.db.redis_client import redis_client
from app.core.config import settings 
from app.models.user import UserProfile
from app.db.postgres import get_db
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordBearer
router = APIRouter(prefix="/auth", tags=["Authentication"])

SECRET_KEY = getattr(settings, 'SECRET_KEY', "your_super_secret_key")
ALGORITHM = "HS256"

TEXTBEE_API_KEY = "d5420e5b-f4d3-469a-9003-d343de65c4a1"
TEXTBEE_DEVICE_ID = "69c546b6c3538b609d13d100"

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/verify-otp")
class PhonePayload(BaseModel):
    phone: str
    is_register: bool = False

class VerifyPayload(BaseModel):
    phone: str
    otp: str

# NEW: Payload for direct registration without OTP
class DirectRegisterPayload(BaseModel):
    phone: str
    name: str
    email: str

def create_access_token(data: dict, expires_delta: timedelta = timedelta(days=7)):
    to_encode = data.copy()
    expire = datetime.utcnow() + expires_delta
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

# --- NEW: Dependency to get the current user from the JWT token ---
def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # Decode the JWT token
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError:
        raise credentials_exception
    
    # Fetch the user from the database
    user = db.query(UserProfile).filter(UserProfile.id == int(user_id)).first()
    if user is None:
        raise credentials_exception
        
    return user
# -------------------------------------------------------------------


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
    user = db.query(UserProfile).filter(UserProfile.phone == payload.phone).first()
    
    # Send OTP is now strictly for Sign In. User must exist.
    if not user:
        raise HTTPException(status_code=404, detail="User not found. Please sign up first.")

    cooldown_key = f"otp_cooldown:{payload.phone}"
    if redis_client.get(cooldown_key):
        raise HTTPException(
            status_code=429, 
            detail="OTP already sent. Please wait 60 seconds."
        )
    
    redis_client.setex(cooldown_key, 60, "locked")

    otp = str(random.randint(100000, 999999))
    redis_key = f"otp:{payload.phone}"
    redis_client.setex(redis_key, 300, otp)
    
    message = f"Your AgroSync login code is: {otp}. It will expire in 5 minutes."
    background_tasks.add_task(send_textbee_sms, payload.phone, message)
    
    return {"status": "success", "message": "OTP sent successfully"}

@router.post("/verify-otp")
async def verify_otp(payload: VerifyPayload, db: Session = Depends(get_db)):
    redis_key = f"otp:{payload.phone}"
    stored_otp = redis_client.get(redis_key)
    
    stored_val = stored_otp.decode('utf-8') if isinstance(stored_otp, bytes) else stored_otp
    if not stored_val or stored_val != payload.otp:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")
    
    redis_client.delete(redis_key)
    
    user = db.query(UserProfile).filter(UserProfile.phone == payload.phone).first()
    
    if not user:
        return {
            "status": "success", 
            "message": "User profile not found. Please sign up.",
            "is_registered": False,
            "phone": payload.phone 
        }
        
    token_payload = {"sub": str(user.id), "phone": user.phone}
    access_token = create_access_token(data=token_payload)
    
    return {
        "status": "success", 
        "message": "Login successful",
        "is_registered": True,
        "user": {
            "id": user.id,
            "phone": user.phone,
            "name": user.name
        },
        "token": access_token
    }

# UPDATED: Direct Registration Endpoint
@router.post("/register")
async def register_user(payload: DirectRegisterPayload, db: Session = Depends(get_db)):
    existing_user = db.query(UserProfile).filter(UserProfile.phone == payload.phone).first()
    
    if existing_user:
        raise HTTPException(status_code=400, detail="User with this phone number already exists.")

    new_user = UserProfile(
        phone=payload.phone,
        name=payload.name,
        email=payload.email
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {
        "status": "success",
        "message": "Registration successful. Please sign in.",
        "user": {
            "id": new_user.id,
            "phone": new_user.phone,
            "name": new_user.name
        }
    }