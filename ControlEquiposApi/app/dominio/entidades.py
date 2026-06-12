import uuid
from datetime import datetime, timezone
from enum import Enum
from sqlalchemy import String, DateTime, ForeignKey, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, mapped_column, relationship

class Base(DeclarativeBase):
    pass

class CondicionEnum(str, Enum):
    NUEVO = "Nuevo"
    USADO = "Usado"
    DEFECTUOSO = "Defectuoso"

# ==========================================
# ENTIDAD: ROLES
# ==========================================
class Rol(Base):
    __tablename__ = "roles"

    id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nombre = mapped_column(String(50), unique=True, nullable=False, index=True)
    descripcion = mapped_column(String(250), nullable=True)

    usuarios = relationship("Usuario", back_populates="rol_relacion")

# ==========================================
# ENTIDAD: USUARIO
# ==========================================
class Usuario(Base):
    __tablename__ = "usuarios"

    id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = mapped_column(String(150), unique=True, nullable=False, index=True)
    password_hash = mapped_column(String(250), nullable=False)
    is_active = mapped_column(Boolean, default=True)
    
    # Llave foránea corregida: hace referencia al ID del rol
    rol_id = mapped_column(UUID(as_uuid=True), ForeignKey("roles.id", ondelete="RESTRICT"), nullable=False)
    
    # Uso de timezone.utc para buenas prácticas de fechas
    fecha_registro = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    ultimo_login = mapped_column(DateTime, nullable=True)
    
    mfa_secret = mapped_column(String(100), nullable=True) 
    is_mfa_enabled = mapped_column(Boolean, default=False)

    rol_relacion = relationship("Rol", back_populates="usuarios")

# ==========================================
# OTRAS ENTIDADES
# ==========================================
class Departamento(Base):
    __tablename__ = "departamentos"
    id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nombre = mapped_column(String(100), unique=True, nullable=False)
    empleados = relationship("Empleado", back_populates="departamento")

class Empleado(Base):
    __tablename__ = "empleados"
    id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nombre = mapped_column(String(100), nullable=False)
    apellido = mapped_column(String(100), nullable=False)
    codigo_empleado = mapped_column(String(50), unique=True, nullable=False)
    departamento_id = mapped_column(UUID(as_uuid=True), ForeignKey("departamentos.id", ondelete="RESTRICT"), nullable=False)
    is_active = mapped_column(Boolean, default=True)
    departamento = relationship("Departamento", back_populates="empleados")
    asignaciones = relationship("Asignacion", back_populates="empleado")

class Marca(Base):
    __tablename__ = "marcas"
    id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nombre = mapped_column(String(100), unique=True, nullable=False)
    equipos = relationship("EquipoTecnologico", back_populates="marca")

class EquipoTecnologico(Base):
    __tablename__ = "equipos_tecnologicos"
    id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    categoria = mapped_column(String(100), nullable=False)
    modelo = mapped_column(String(100), nullable=False)
    serial = mapped_column(String(100), unique=True, nullable=False)
    marca_id = mapped_column(UUID(as_uuid=True), ForeignKey("marcas.id", ondelete="RESTRICT"), nullable=False)
    condicion = mapped_column(String(20), default=CondicionEnum.NUEVO, nullable=False)
    is_asignado = mapped_column(Boolean, default=False)
    marca = relationship("Marca", back_populates="equipos")
    asignaciones = relationship("Asignacion", back_populates="equipo")

class Asignacion(Base):
    __tablename__ = "asignaciones"
    id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    empleado_id = mapped_column(UUID(as_uuid=True), ForeignKey("empleados.id", ondelete="RESTRICT"), nullable=False)
    equipo_id = mapped_column(UUID(as_uuid=True), ForeignKey("equipos_tecnologicos.id", ondelete="RESTRICT"), nullable=False)
    fecha_asignacion = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    fecha_devolucion = mapped_column(DateTime, nullable=True)
    observaciones = mapped_column(String(500), nullable=True)
    is_activa = mapped_column(Boolean, default=True)
    empleado = relationship("Empleado", back_populates="asignaciones")
    equipo = relationship("EquipoTecnologico", back_populates="asignaciones")