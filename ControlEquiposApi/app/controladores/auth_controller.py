import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.infraestructura.conexion import get_db
from app.dependencias import obtener_usuario_autenticado, EsAdmin
from app.shared.esquemas import (
    UsuarioLoginDto, MfaVerificarDto, TokenResponseDto, MfaSetupResponseDto,
    UsuarioCreateDto, UsuarioUpdateDto, UsuarioReadDto, RolCreateDto, RolReadDto
)
from app.aplicacion.auth_service import AuthService

router = APIRouter(prefix="/api/auth", tags=["Autenticación & MFA"])

# ==========================================
# ENDPOINTS DE AUTENTICACIÓN EXISTENTES
# ==========================================

@router.post("/login", response_model=TokenResponseDto, status_code=status.HTTP_200_OK)
def login(dto: UsuarioLoginDto, db: Session = Depends(get_db)):
    """
    **Autenticación de Usuario (Primer Factor)**
    
    Valida el correo electrónico y la contraseña hash. Si el usuario requiere
    segundo factor (MFA activo), el campo `requires_mfa` retornará `true` 
    y el token devuelto será temporal y restringido.
    """
    servicio = AuthService(db)
    resultado = servicio.login_primer_factor(dto)
    if not resultado:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Credenciales de acceso incorrectas."
        )
    return resultado

@router.post("/mfa/setup", response_model=MfaSetupResponseDto, status_code=status.HTTP_201_CREATED)
def inicializar_mfa(email: str, db: Session = Depends(get_db)):
    """
    **Configuración Inicial de MFA (TOTP)**
    
    Genera una semilla secreta única compatible con Google Authenticator y 
    la URL necesaria para renderizar el código QR en el Frontend.
    """
    servicio = AuthService(db)
    setup_mfa = servicio.generar_secreto_mfa(email)
    if not setup_mfa:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, 
            detail="El usuario especificado no existe en el sistema."
        )
    return setup_mfa

@router.post("/mfa/verify", response_model=TokenResponseDto, status_code=status.HTTP_200_OK)
def verificar_mfa(dto: MfaVerificarDto, db: Session = Depends(get_db)):
    """
    **Validación del Segundo Factor (MFA)**
    
    Verifica el código de 6 dígitos del autenticador dinámico. Si es correcto 
    y es la primera vez, activa el MFA en el perfil del usuario de forma permanente 
    y genera el token JWT definitivo.
    """
    servicio = AuthService(db)
    token_final = servicio.validar_codigo_mfa(dto)
    if not token_final:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Código de verificación MFA inválido o expirado."
        )
    return token_final


# ==========================================
# NUEVOS: ENDPOINTS PARA GESTIÓN DE ROLES
# ==========================================

@router.post("/roles", response_model=RolReadDto, status_code=status.HTTP_201_CREATED)
def crear_nuevo_rol(
    dto: RolCreateDto, 
    db: Session = Depends(get_db), 
    current_user: uuid.UUID = Depends(obtener_usuario_autenticado)
):
    """
    **Registrar Nuevo Rol**
    
    Crea un rol de acceso en el sistema (ej: Admin, Soporte, Tecnico). 
    El nombre debe ser único. Requiere autenticación Bearer Token.
    """
    servicio = AuthService(db)
    return servicio.crear_rol(dto)

@router.get("/roles", response_model=List[RolReadDto], status_code=status.HTTP_200_OK)
def listar_todos_los_roles(
    db: Session = Depends(get_db), 
    current_user: uuid.UUID = Depends(obtener_usuario_autenticado)
):
    """
    **Listar Roles**
    
    Retorna la colección completa de roles configurados en la base de datos.
    """
    servicio = AuthService(db)
    return servicio.obtener_roles()

@router.delete("/roles/{rol_id}", status_code=status.HTTP_200_OK)
def eliminar_un_rol(
    rol_id: uuid.UUID, 
    db: Session = Depends(get_db), 
    current_user: uuid.UUID = Depends(obtener_usuario_autenticado)
):
    """
    **Eliminar Rol**
    
    Remueve un rol por su ID. El sistema bloqueará la acción si existen usuarios 
    asociados activamente a dicho rol para resguardar la integridad.
    """
    servicio = AuthService(db)
    servicio.eliminar_rol(rol_id)
    return {"message": "Rol removido correctamente del sistema."}


# ==========================================
# NUEVOS: ENDPOINTS PARA CRUD DE USUARIOS
# ==========================================

@router.post("/usuarios", response_model=UsuarioReadDto, status_code=status.HTTP_201_CREATED)
def registrar_usuario(
    dto: UsuarioCreateDto, 
    db: Session = Depends(get_db), 
    current_user: uuid.UUID = Depends(obtener_usuario_autenticado)
):
    """
    **Crear Nuevo Usuario**
    
    Registra una cuenta de usuario en el almacén, hasheando automáticamente su credencial 
    e interceptando si el `rol_id` referenciado es válido.
    """
    servicio = AuthService(db)
    return servicio.crear_usuario(dto)

@router.get("/usuarios", response_model=List[UsuarioReadDto], status_code=status.HTTP_200_OK)
def listar_usuarios(
    db: Session = Depends(get_db), 
    current_user: uuid.UUID = Depends(obtener_usuario_autenticado)
):
    """
    **Listar Usuarios Registrados**
    
    Retorna el listado general de usuarios junto con su estado de actividad y rol vinculado.
    """
    servicio = AuthService(db)
    return servicio.obtener_usuarios()

@router.get("/usuarios/{usuario_id}", response_model=UsuarioReadDto, status_code=status.HTTP_200_OK)
def buscar_usuario_por_id(
    usuario_id: uuid.UUID, 
    db: Session = Depends(get_db), 
    current_user: uuid.UUID = Depends(obtener_usuario_autenticado)
):
    """
    **Obtener Usuario por ID**
    
    Busca un usuario específico mediante su identificador UUID único.
    """
    servicio = AuthService(db)
    return servicio.obtener_usuario_por_id(usuario_id)

@router.put("/usuarios/{usuario_id}", response_model=UsuarioReadDto, status_code=status.HTTP_200_OK)
def modificar_usuario(
    usuario_id: uuid.UUID, 
    dto: UsuarioUpdateDto, 
    db: Session = Depends(get_db), 
    current_user: uuid.UUID = Depends(obtener_usuario_autenticado)
):
    """
    **Actualizar Datos de Usuario**
    
    Permite la edición parcial o total de la cuenta (email, contraseña, rol o estado activo).
    """
    servicio = AuthService(db)
    return servicio.actualizar_usuario(usuario_id, dto)

@router.delete("/usuarios/{usuario_id}", status_code=status.HTTP_200_OK)
def borrar_usuario(
    usuario_id: uuid.UUID, 
    db: Session = Depends(get_db), 
    current_user: uuid.UUID = Depends(obtener_usuario_autenticado)
):
    """
    **Eliminar Usuario del Sistema**
    
    Borra físicamente el registro del usuario basado en su ID.
    """
    servicio = AuthService(db)
    servicio.eliminar_usuario(usuario_id)
    return {"message": "El usuario ha sido eliminado exitosamente."}