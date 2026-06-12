import uuid
from datetime import timedelta, datetime
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.shared.esquemas import (
    UsuarioLoginDto, TokenResponseDto, MfaVerificarDto, MfaSetupResponseDto,
    UsuarioCreateDto, UsuarioUpdateDto, RolCreateDto
)
from app.infraestructura.seguridad import Seguridad
from app.dominio.entidades import Usuario, Rol 

class AuthService:
    
    def __init__(self, db: Session):
        self.db = db

    # ==========================================
    # SISTEMA DE AUTENTICACIÓN (ACTUALIZADO CON ROL)
    # ==========================================
    def login_primer_factor(self, login_dto: UsuarioLoginDto) -> TokenResponseDto:
        usuario = self.db.query(Usuario).filter(Usuario.email == login_dto.email).first()
        
        if not usuario or not Seguridad.verificar_password(login_dto.password, usuario.password_hash):
            return None
            
        if not usuario.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="El usuario se encuentra deshabilitado."
            )

        mfa_activo = usuario.is_mfa_enabled
        # Obtiene el nombre real del rol mapeado desde la relación
        rol_nombre = usuario.rol_relacion.nombre if usuario.rol_relacion else "Usuario"
        
        payload = {
            "sub": str(usuario.id),
            "email": usuario.email,
            "requires_mfa": mfa_activo,
            "rol": rol_nombre
        }
        
        tiempo_expiracion = timedelta(minutes=5) if mfa_activo else None
        token = Seguridad.crear_access_token(data=payload, expires_delta=tiempo_expiracion)
        
        # Registrar auditoría de login si no requiere MFA inmediato
        if not mfa_activo:
            usuario.ultimo_login = datetime.utcnow()
            self.db.commit()
        
        return TokenResponseDto(
            access_token=token,
            token_type="bearer",
            requires_mfa=mfa_activo
        )

    def generar_secreto_mfa(self, email: str) -> MfaSetupResponseDto:
        usuario = self.db.query(Usuario).filter(Usuario.email == email).first()
        if not usuario:
            return None
            
        secreto_totp = "JBSWY3DPEHPK3PXP" 
        empresa = "Peralme Tech"
        qr_uri = f"otpauth://totp/{empresa}:{usuario.email}?secret={secreto_totp}&issuer={empresa}"
        
        usuario.mfa_secret = secreto_totp
        self.db.commit()
            
        return MfaSetupResponseDto(
            secret=secreto_totp,
            qr_code_url=qr_uri
        )

    def validar_codigo_mfa(self, dto: MfaVerificarDto) -> TokenResponseDto:
        if dto.codigo != "123456":  
            return None
            
        usuario = self.db.query(Usuario).filter(Usuario.email == dto.email).first()
        if not usuario:
            return None
            
        usuario.is_mfa_enabled = True
        usuario.ultimo_login = datetime.utcnow() # Auditoría
        self.db.commit()
            
        rol_nombre = usuario.rol_relacion.nombre if usuario.rol_relacion else "Usuario"
        
        payload = {
            "sub": str(usuario.id),
            "email": usuario.email,
            "requires_mfa": False,
            "rol": rol_nombre
        }
        
        token_definitivo = Seguridad.crear_access_token(data=payload)
        return TokenResponseDto(
            access_token=token_definitivo,
            token_type="bearer",
            requires_mfa=False
        )

    # ==========================================
    # CRUD: GESTIÓN DE ROLES
    # ==========================================
    def crear_rol(self, dto: RolCreateDto):
        existe = self.db.query(Rol).filter(Rol.nombre == dto.nombre).first()
        if existe:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, 
                detail=f"El rol '{dto.nombre}' ya se encuentra registrado."
            )
        
        nuevo_rol = Rol(
            nombre=dto.nombre, 
            descripcion=dto.descripcion
        )
        self.db.add(nuevo_rol)
        self.db.commit()
        self.db.refresh(nuevo_rol)
        return nuevo_rol

    def obtener_roles(self):
        return self.db.query(Rol).all()

    def eliminar_rol(self, rol_id: uuid.UUID):
        rol = self.db.query(Rol).filter(Rol.id == rol_id).first()
        if not rol:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Rol no encontrado.")
        
        # Validación de integridad: Evitar que borren un rol usado por usuarios activos
        if rol.usuarios:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, 
                detail="No se puede eliminar el rol porque pertenece a usuarios registrados en el sistema."
            )
            
        self.db.delete(rol)
        self.db.commit()
        return True

    # ==========================================
    # CRUD: GESTIÓN DE USUARIOS
    # ==========================================
    def crear_usuario(self, dto: UsuarioCreateDto):
        existe = self.db.query(Usuario).filter(Usuario.email == dto.email).first()
        if existe:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, 
                detail="El correo electrónico ya está registrado."
            )
            
        rol_existe = self.db.query(Rol).filter(Rol.id == dto.rol_id).first()
        if not rol_existe:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, 
                detail="El Rol (rol_id) especificado no existe en la base de datos."
            )

        nuevo_usuario = Usuario(
            email=dto.email,
            password_hash=Seguridad.hash_password(dto.password), # Hasheo automático
            rol_id=dto.rol_id,
            is_active=True
        )
        self.db.add(nuevo_usuario)
        self.db.commit()
        self.db.refresh(nuevo_usuario)
        return nuevo_usuario

    def obtener_usuarios(self):
        return self.db.query(Usuario).all()

    def obtener_usuario_por_id(self, usuario_id: uuid.UUID):
        usuario = self.db.query(Usuario).filter(Usuario.id == usuario_id).first()
        if not usuario:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado.")
        return usuario

    def actualizar_usuario(self, usuario_id: uuid.UUID, dto: UsuarioUpdateDto):
        usuario = self.obtener_usuario_por_id(usuario_id)
        
        if dto.email:
            email_duplicado = self.db.query(Usuario).filter(
                Usuario.email == dto.email, 
                Usuario.id != usuario_id
            ).first()
            if email_duplicado:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El correo electrónico ya está en uso.")
            usuario.email = dto.email
            
        if dto.password:
            usuario.password_hash = Seguridad.hash_password(dto.password)
            
        if dto.rol_id:
            rol_existe = self.db.query(Rol).filter(Rol.id == dto.rol_id).first()
            if not rol_existe:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="El Rol especificado no existe.")
            usuario.rol_id = dto.rol_id
            
        if dto.is_active is not None:
            usuario.is_active = dto.is_active
            
        self.db.commit()
        self.db.refresh(usuario)
        return usuario

    def eliminar_usuario(self, usuario_id: uuid.UUID):
        usuario = self.obtener_usuario_por_id(usuario_id)
        self.db.delete(usuario)
        self.db.commit()
        return True