from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

# Importaciones de tu arquitectura
from app.infraestructura.conexion import inicializar_base_de_datos
from app.controladores.auth_controller import router as auth_router
from app.controladores.inventario_controller import router as inventario_router

# Configuración de logs
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        logger.info("🔄 Iniciando sincronización de base de datos...")
        inicializar_base_de_datos()
        logger.info("✅ Base de datos inicializada correctamente.")
    except Exception as e:
        logger.error(f"❌ Error crítico al inicializar la base de datos: {e}")
    yield
    logger.info("⏹️ Apagando el servidor Peralme Tech...")

app = FastAPI(
    title="Sistema de Inventario y Asignación TIC - Peralme Tech",
    description="API de gestión para control de activos tecnológicos.",
    version="1.0",
    lifespan=lifespan
)

# Configuración de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inclusión de Routers
# Asegúrate de que el router de auth_controller tenga prefix="/auth"
app.include_router(auth_router, prefix="/api")
app.include_router(inventario_router, prefix="/api")

# --- AUDITORÍA DE RUTAS ---
# Esto imprimirá en tu consola todas las rutas que FastAPI ha registrado.
# Úsalo para verificar la ruta exacta antes de hacer la petición desde Flet.
@app.on_event("startup")
async def startup_event():
    print("\n--- RUTAS REGISTRADAS EN FASTAPI ---")
    for route in app.routes:
        if hasattr(route, "path"):
            methods = getattr(route, "methods", {"GET"})
            print(f"✅ RUTA: {route.path} | MÉTODOS: {methods}")
    print("------------------------------------\n")

@app.get("/")
def read_root():
    return {"message": "Bienvenido al sistema de control de inventario Peralme Tech"}