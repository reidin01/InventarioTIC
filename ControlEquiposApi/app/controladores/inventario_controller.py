from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import uuid

# Importaciones de tu arquitectura
from app.infraestructura.conexion import get_db
from app.dependencias import obtener_usuario_autenticado, EsAdmin
from app.shared.esquemas import MarcaCreateDto, MarcaReadDto, EquipoCreateDto, AsignacionCreateDto
from app.aplicacion.inventario_service import InventarioService
from app.dominio.entidades import Usuario

router = APIRouter(prefix="/api/inventario", tags=["Gestión de Inventario & Asignaciones"])

# --- Gestión de Marcas (Solo Administradores) ---

@router.post("/marcas", response_model=MarcaReadDto, status_code=status.HTTP_201_CREATED)
def crear_marca(
    dto: MarcaCreateDto, 
    db: Session = Depends(get_db), 
    admin: Usuario = Depends(EsAdmin())  # Protegido: Solo Admin
):
    servicio = InventarioService(db)
    if servicio.existe_marca(dto.nombre):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, 
            detail=f"La marca '{dto.nombre}' ya existe."
        )
    return servicio.guardar_marca(dto)

@router.get("/marcas", response_model=List[MarcaReadDto], status_code=status.HTTP_200_OK)
def obtener_marcas(
    db: Session = Depends(get_db), 
    usuario: Usuario = Depends(obtener_usuario_autenticado) # Protegido: Cualquier logueado
):
    servicio = InventarioService(db)
    return servicio.listar_marcas()

# --- Gestión de Equipos (Solo Administradores) ---

@router.post("/equipos", status_code=status.HTTP_201_CREATED)
def registrar_equipo(
    dto: EquipoCreateDto, 
    db: Session = Depends(get_db), 
    admin: Usuario = Depends(EsAdmin())  # Protegido: Solo Admin
):
    servicio = InventarioService(db)
    if not servicio.existe_marca_por_id(dto.marca_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, 
            detail="La marca especificada no existe."
        )
    
    resultado = servicio.registrar_equipo_tecnologico(dto)
    if not resultado:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Error: Verifique si el número de Serial ya fue registrado."
        )
    return {"message": "Equipo tecnológico agregado exitosamente."}

# --- Control de Asignaciones (Permitido para todos los empleados del sistema) ---

@router.post("/asignaciones", status_code=status.HTTP_201_CREATED)
def asignar_equipo_a_empleado(
    dto: AsignacionCreateDto, 
    db: Session = Depends(get_db), 
    usuario: Usuario = Depends(obtener_usuario_autenticado) # Protegido: Cualquier logueado
):
    servicio = InventarioService(db)
    exito = servicio.procesar_asignacion(dto)
    if not exito:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Error al procesar asignación. Valide disponibilidad."
        )
    return {"message": "Asignación registrada con éxito."}