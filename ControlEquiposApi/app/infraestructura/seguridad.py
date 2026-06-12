import jwt
from datetime import datetime, timedelta, timezone
from typing import Optional
from fastapi import HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from bcrypt import hashpw, gensalt, checkpw
from app.appsettings import settings

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

class Seguridad:
    """Lógica pura de cifrado y gestión de JWT."""
    
    @staticmethod
    def hash_password(password: str) -> str:
        return hashpw(password.encode('utf-8'), gensalt()).decode('utf-8')

    @staticmethod
    def verificar_password(plain_password: str, hashed_password: str) -> bool:
        return checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

    @staticmethod
    def crear_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
        """
        Crea un token JWT. Acepta un delta de tiempo opcional; si no se proporciona,
        utiliza el valor configurado por defecto.
        """
        if expires_delta:
            expire = datetime.now(timezone.utc) + expires_delta
        else:
            expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
            
        to_encode = data.copy()
        to_encode.update({"exp": expire})
        return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

    @staticmethod
    def verificar_access_token(token: str) -> dict:
        try:
            return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, 
                detail="Token inválido o expirado"
            )