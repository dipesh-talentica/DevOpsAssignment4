import sqlite3
import jwt
import datetime
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel
from passlib.context import CryptContext

app = FastAPI()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
SECRET_KEY = "my_secret_key"
DB_FILE = "sqlite.db"

def init_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS users (username TEXT PRIMARY KEY, password TEXT)''')
    
    # Initialize with default admin user
    c.execute("SELECT * FROM users WHERE username='admin'")
    if not c.fetchone():
        hashed_pw = pwd_context.hash("password123")
        c.execute("INSERT INTO users (username, password) VALUES (?, ?)", ("admin", hashed_pw))
    conn.commit()
    conn.close()

init_db()

class LoginModel(BaseModel):
    username: str
    password: str

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/login")
def login(user: LoginModel):
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT password FROM users WHERE username=?", (user.username,))
    row = c.fetchone()
    conn.close()
    
    if row and pwd_context.verify(user.password, row[0]):
        token = jwt.encode({"iss": user.username, "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=1)}, SECRET_KEY, algorithm="HS256")
        return {"token": token}
    raise HTTPException(status_code=401, detail="Invalid credentials")

@app.get("/verify")
def verify(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    token = authorization.split(" ")[1]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        return {"valid": True, "user": payload.get("iss")}
    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))

@app.get("/users")
def get_users():
    # Kong handles JWT verification before routing here.
    return {"users": ["admin"]}