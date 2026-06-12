from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from app.appsettings import settings 
# Importamos Rol y Usuario
from app.dominio.entidades import Base, Usuario, Rol
from app.infraestructura.seguridad import Seguridad

# 1. Construimos las URLs de conexión dinámicamente
DATABASE_URL = f"postgresql+pg8000://{settings.DB_USER}:{settings.DB_PASSWORD}@{settings.DB_SERVER}:{settings.DB_PORT}/{settings.DB_NAME}"
MASTER_URL = f"postgresql+pg8000://{settings.DB_USER}:{settings.DB_PASSWORD}@{settings.DB_SERVER}:{settings.DB_PORT}/postgres"

# 2. Inicializamos el Engine principal
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def asegurar_base_de_datos_existe():
    db_nombre = settings.DB_NAME
    master_engine = create_engine(MASTER_URL, isolation_level="AUTOCOMMIT")
    try:
        with master_engine.connect() as conn:
            exists = conn.execute(
                text("SELECT 1 FROM pg_database WHERE datname = :name"), 
                {"name": db_nombre}
            ).scalar()
            
            if not exists:
                conn.execute(text(f'CREATE DATABASE "{db_nombre}"'))
                print(f"✅ Base de datos '{db_nombre}' no existía. ¡Creada con éxito!")
    except Exception as e:
        print(f"❌ Error al verificar/crear la base de datos: {e}")
    finally:
        master_engine.dispose()

def crear_admin_si_no_existe():
    """Siembra el rol y el usuario administrador inicial."""
    db = SessionLocal()
    try:
        # 1. Asegurar que el rol 'Admin' existe
        admin_rol = db.query(Rol).filter(Rol.nombre == "Admin").first()
        if not admin_rol:
            admin_rol = Rol(nombre="Admin", descripcion="Administrador del sistema")
            db.add(admin_rol)
            db.commit()
            db.refresh(admin_rol)
            print("✅ Rol 'Admin' registrado.")

        # 2. Verificar si el admin ya existe
        admin = db.query(Usuario).filter(Usuario.email == "admin@peralme.com").first()
        if not admin:
            print("👤 Creando administrador inicial...")
            nuevo_admin = Usuario(
                email="admin@peralme.com",
                password_hash=Seguridad.hash_password("Admin123456"),
                rol_id=admin_rol.id  # Usamos la relación correcta
            )
            db.add(nuevo_admin)
            db.commit()
            print("✅ Administrador creado con éxito.")
    except Exception as e:
        db.rollback()
        print(f"❌ Error al crear admin inicial: {e}")
    finally:
        db.close()

def inicializar_base_de_datos():
    asegurar_base_de_datos_existe()
    try:
        Base.metadata.create_all(bind=engine)
        print("🚀 Esquema de tablas sincronizado.")
        crear_admin_si_no_existe()
    except Exception as e:
        print(f"❌ Error en inicialización: {e}")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()