from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.infraestructura.conexion import get_db
from app.infraestructura.seguridad import Seguridad, oauth2_scheme
from app.dominio.entidades import Usuario

def obtener_usuario_autenticado(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> Usuario:
    payload = Seguridad.verificar_access_token(token)
    usuario_id = payload.get("sub")
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuario no encontrado")
    return usuario

class EsAdmin:
    def __call__(self, usuario: Usuario = Depends(obtener_usuario_autenticado)) -> Usuario:
        if usuario.rol != "admin":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Requiere rol admin")
        return usuario