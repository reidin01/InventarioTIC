import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.infraestructura.conexion import get_db
from app.infraestructura.seguridad import obtener_usuario_autenticado
from app.shared.esquemas import MarcaCreateDto, MarcaReadDto, EquipoCreateDto, AsignacionCreateDto
from app.aplicacion.inventario_service import InventarioService

router = APIRouter(prefix="/api/inventario", tags=["Gestión de Inventario & Asignaciones"])

# --- Gestión de Marcas ---

@router.post("/marcas", response_model=MarcaReadDto, status_code=status.HTTP_201_CREATED)
def crear_marca(
    dto: MarcaCreateDto, 
    db: Session = Depends(get_db), 
    usuario_id: uuid.UUID = Depends(obtener_usuario_autenticado)
):
    """
    **Registrar Nueva Marca**
    
    Inserta una marca para el inventario de equipos tecnológicos. El nombre de la marca 
    debe ser **estrictamente único** en la base de datos para evitar duplicados. Requiere JWT válido.
    """
    servicio = InventarioService(db)
    if servicio.existe_marca(dto.nombre):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, 
            detail=f"La marca '{dto.nombre}' ya se encuentra registrada en el sistema."
        )
    return servicio.guardar_marca(dto)

@router.get("/marcas", response_model=List[MarcaReadDto], status_code=status.HTTP_200_OK)
def obtener_marcas(
    db: Session = Depends(get_db), 
    usuario_id: uuid.UUID = Depends(obtener_usuario_autenticado)
):
    """
    **Listar Marcas Registradas**
    
    Retorna todas las marcas configuradas en la base de datos Postgres. 
    Útil para alimentar los selectores del frontend.
    """
    servicio = InventarioService(db)
    return servicio.listar_marcas()

# --- Gestión de Equipos Tecnológicos ---

@router.post("/equipos", status_code=status.HTTP_201_CREATED)
def registrar_equipo(
    dto: EquipoCreateDto, 
    db: Session = Depends(get_db), 
    usuario_id: uuid.UUID = Depends(obtener_usuario_autenticado)
):
    """
    **Ingresar Equipo Tecnológico al Inventario**
    
    Registra un dispositivo electrónico en el almacén asociándole un `IdMarca` y un `Serial` único. 
    Maneja validación de estados permitidos como 'Nuevo' y 'Usado'.
    """
    servicio = InventarioService(db)
    if not servicio.existe_marca_por_id(dto.marca_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, 
            detail="La marca (IdMarca) especificada no existe en la base de datos."
        )
    
    resultado = servicio.registrar_equipo_tecnologico(dto)
    if not resultado:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Error al guardar el equipo. Verifique si el número de Serial ya fue registrado."
        )
    return {"message": "Equipo tecnológico agregado al inventario de manera exitosa."}

# --- Control de Asignaciones ---

@router.post("/asignaciones", status_code=status.HTTP_201_CREATED)
def asignar_equipo_a_empleado(
    dto: AsignacionCreateDto, 
    db: Session = Depends(get_db), 
    usuario_id: uuid.UUID = Depends(obtener_usuario_autenticado)
):
    """
    **Asignar un Equipo Tecnológico a un Empleado**
    
    Genera un registro de asignación vinculando un empleado con un equipo. 
    Cambia de manera automática el estado del equipo tecnológico a `is_asignado = True`. 
    Falla si el equipo ya está asignado a otra persona o si el empleado está inactivo.
    """
    servicio = InventarioService(db)
    exito = servicio.procesar_asignacion(dto)
    if not exito:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="No se pudo procesar la asignación. Valide que el empleado exista y el equipo esté libre."
        )
    return {"message": "Asignación de equipo autorizada y registrada con éxito."}