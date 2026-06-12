from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from datetime import datetime
import uuid

# ==========================================
# ESQUEMAS DE AUTENTICACIÓN Y MFA
# ==========================================
class UsuarioLoginDto(BaseModel):
    email: EmailStr
    password: str

class MfaVerificarDto(BaseModel):
    email: EmailStr
    codigo: str  # Unificado con el servicio (en español)

class TokenResponseDto(BaseModel):
    access_token: str
    token_type: str
    requires_mfa: bool # Indica si el usuario debe pasar al flujo de MFA primero

class MfaSetupResponseDto(BaseModel):
    secret: str
    qr_code_url: str # Para pintar el QR en el Frontend

# ==========================================
# NUEVOS: ESQUEMAS PARA GESTIÓN DE ROLES
# ==========================================
class RolCreateDto(BaseModel):
    nombre: str = Field(..., min_length=2, max_length=50, description="Ej: Admin, Soporte, Tecnico")
    descripcion: Optional[str] = Field(None, max_length=250)

class RolReadDto(BaseModel):
    id: uuid.UUID
    nombre: str
    descripcion: Optional[str]

    class Config:
        from_attributes = True

# ==========================================
# NUEVOS: ESQUEMAS PARA CRUD DE USUARIOS
# ==========================================
class UsuarioCreateDto(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6)
    rol_id: uuid.UUID

class UsuarioUpdateDto(BaseModel):
    email: Optional[EmailStr] = None
    password: Optional[str] = Field(None, min_length=6)
    rol_id: Optional[uuid.UUID] = None
    is_active: Optional[bool] = None

class UsuarioReadDto(BaseModel):
    id: uuid.UUID
    email: EmailStr
    rol_id: uuid.UUID
    is_active: bool

    class Config:
        from_attributes = True

# ==========================================
# ESQUEMAS DE INVENTARIO EXISTING
# ==========================================
class MarcaCreateDto(BaseModel):
    nombre: str = Field(..., min_length=2, max_length=100)

class MarcaReadDto(BaseModel):
    id: uuid.UUID
    nombre: str

    class Config:
        from_attributes = True

class EquipoCreateDto(BaseModel):
    categoria: str
    modelo: str
    serial: str
    marca_id: uuid.UUID
    condicion: str = "Nuevo"

class AsignacionCreateDto(BaseModel):
    empleado_id: uuid.UUID
    equipo_id: uuid.UUID
    observaciones: Optional[str] = None