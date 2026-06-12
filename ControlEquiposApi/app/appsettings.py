from pydantic_settings import BaseSettings
from pydantic import ConfigDict

class Settings(BaseSettings):
    # Configuración de la Base de Datos (PostgreSQL con pg8000)
    DB_SERVER: str = "127.0.0.1"
    DB_PORT: int = 5432
    DB_NAME: str = "control_equipos_db"
    DB_USER: str = "postgres"
    DB_PASSWORD: str = "Thefather12*"  # <-- Cambia esto por tu contraseña real

    # Configuración de Seguridad (JWT)
    SECRET_KEY: str = "super_secret_key_para_los_tokens_jwt_1234567890"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # Permitir leer desde un archivo .env externo si existe
    model_config = ConfigDict(env_file=".env", env_file_encoding="utf-8")

# Instancia global que será importada por los demás módulos
settings = Settings()