from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.postgres import get_db
from app.models.community import Post, Reply, GovScheme
from app.schemas.community import PostCreate, PostResponse, ReplyCreate, ReplyResponse, GovSchemeResponse
from typing import List
from app.api.routers.auth import get_current_user

router = APIRouter(prefix="/api/community", tags=["Community"])

@router.get("/posts", response_model=List[PostResponse])
def get_posts(db: Session = Depends(get_db)):
    # Returns all posts ordered by newest first
    posts = db.query(Post).order_by(Post.created_at.desc()).all()
    return posts

# --- NEW: Get logged in user's posts ---
@router.get("/my_posts", response_model=List[PostResponse])
def get_my_posts(db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    posts = db.query(Post).filter(Post.user_id == str(current_user.id)).order_by(Post.created_at.desc()).all()
    return posts

# --- NEW: Get posts the logged in user has replied to ---
@router.get("/my_replies", response_model=List[PostResponse])
def get_my_replies(db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    posts = db.query(Post).join(Reply).filter(Reply.user_id == str(current_user.id)).distinct().order_by(Post.created_at.desc()).all()
    return posts

@router.post("/posts", response_model=PostResponse)
def create_post(post: PostCreate, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    new_post = Post(
        user_id=str(current_user.id),
        author_name=current_user.name,
        title=post.title,
        content=post.content
    )
    db.add(new_post)
    db.commit()
    db.refresh(new_post)
    return new_post

@router.put("/posts/{post_id}", response_model=PostResponse)
def update_post(post_id: int, post_update: PostCreate, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    
    if str(post.user_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Not authorized to edit this post")
    
    post.title = post_update.title
    post.content = post_update.content
    db.commit()
    db.refresh(post)
    return post

@router.delete("/posts/{post_id}")
def delete_post(post_id: int, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    
    if str(post.user_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Not authorized to delete this post")
    
    db.delete(post)
    db.commit()
    return {"message": "Post deleted successfully"}

@router.post("/posts/{post_id}/replies", response_model=ReplyResponse)
def add_reply(post_id: int, reply: ReplyCreate, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    
    if str(post.user_id) == str(current_user.id):
        raise HTTPException(status_code=400, detail="You cannot reply to your own post.")
    
    new_reply = Reply(
        post_id=post_id, 
        user_id=str(current_user.id),
        author_name=current_user.name,
        content=reply.content
    )
    db.add(new_reply)
    db.commit()
    db.refresh(new_reply)
    return new_reply

@router.get("/schemes", response_model=List[GovSchemeResponse])
def get_schemes(state: str = None, db: Session = Depends(get_db)):
    query = db.query(GovScheme)
    if state:
        query = query.filter(GovScheme.state == state)
    return query.all()