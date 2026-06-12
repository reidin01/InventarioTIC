from sqlalchemy.orm import Session
from sqlalchemy import text
from fastapi import HTTPException, status
from app.dominio.entidades import Marca, EquipoTecnologico, Asignacion, Empleado
from app.shared.esquemas import MarcaCreateDto, EquipoCreateDto, AsignacionCreateDto

class InventarioService:
    
    def __init__(self, db: Session):
        self.db = db

    # ==========================================
    # LOGICA DE MARCAS
    # ==========================================
    def existe_marca(self, nombre: str) -> bool:
        """Verifica si ya existe una marca ignorando mayúsculas/minúsculas."""
        marca = self.db.query(Marca).filter(
            text("LOWER(nombre) = LOWER(:nombre)")
        ).params(nombre=nombre).first()
        return marca is not None

    def existe_marca_por_id(self, marca_id) -> bool:
        """Verifica la existencia física de una marca mediante su ID."""
        marca = self.db.query(Marca).filter(Marca.id == marca_id).first()
        return marca is not None

    def guardar_marca(self, dto: MarcaCreateDto):
        """Registra una nueva marca en el sistema."""
        nueva_marca = Marca(
            nombre=dto.nombre
        )
        self.db.add(nueva_marca)
        self.db.commit()
        self.db.refresh(nueva_marca)
        return nueva_marca

    def listar_marcas(self):
        """Retorna el listado completo de marcas."""
        return self.db.query(Marca).all()

    # ==========================================
    # LÓGICA DE EQUIPOS / PRODUCTOS
    # ==========================================
    def registrar_equipo_tecnologico(self, dto: EquipoCreateDto):
        """Inserta un dispositivo o servicio en la base de datos."""
        # Evitar duplicados por número de serial si no es un servicio virtual
        if not getattr(dto, 'es_servicio', False) and dto.numero_serie:
            serial_existe = self.db.query(EquipoTecnologico).filter(
                EquipoTecnologico.serial == dto.numero_serie
            ).first()
            if serial_existe:
                return None

        nuevo_equipo = EquipoTecnologico(
            categoria=dto.nombre,  # Mapeado al campo 'categoria' de tu entidad
            modelo=dto.modelo,
            serial=dto.numero_serie if not getattr(dto, 'es_servicio', False) else "N/A",
            marca_id=dto.marca_id,
            condicion="Nuevo",     # Cumple con el Enum predeterminado
            is_asignado=False      # Inicializa libre
        )
        self.db.add(nuevo_equipo)
        self.db.commit()
        self.db.refresh(nuevo_equipo)
        return nuevo_equipo

    # ==========================================
    # LÓGICA DE ASIGNACIONES
    # ==========================================
    def procesar_asignacion(self, dto: AsignacionCreateDto) -> bool:
        """Valida las reglas e inserta la asignación de un equipo a un empleado."""
        # 1. Validar que el empleado exista y se encuentre activo
        empleado = self.db.query(Empleado).filter(Empleado.id == dto.empleado_id).first()
        if not empleado or not getattr(empleado, 'is_active', True):
            return False

        # 2. Validar que el equipo exista y esté libre
        equipo = self.db.query(EquipoTecnologico).filter(EquipoTecnologico.id == dto.equipo_id).first()
        if not equipo or equipo.is_asignado:
            return False

        # 3. Cambiar bandera de asignación del equipo físico
        equipo.is_asignado = True

        nueva_asignacion = Asignacion(
            empleado_id=dto.empleado_id,
            equipo_id=dto.equipo_id,
            fecha_asignacion=dto.fecha_asignacion,
            observaciones=dto.observaciones,
            is_activa=True
        )
        
        self.db.add(nueva_asignacion)
        self.db.commit()
        return True