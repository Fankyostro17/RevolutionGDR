import os
from dotenv import load_dotenv

load_dotenv()  # Carica variabili da .env

class Config:
    # Database
    DB_HOST = os.getenv('DB_HOST', 'localhost')
    DB_PORT = int(os.getenv('DB_PORT', 3306))
    DB_NAME = os.getenv('DB_NAME', 'rpg_portal_db')
    DB_USER = os.getenv('DB_USER', 'Fanky17')
    DB_PASSWORD = os.getenv('DB_PASSWORD', 'Thom.2007')
    
    # JWT
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'dev-secret-key-change-in-prod')
    JWT_EXPIRATION_HOURS = int(os.getenv('JWT_EXPIRATION_HOURS', 24))
    
    # App
    FLASK_ENV = os.getenv('FLASK_ENV', 'development')
    FLASK_DEBUG = os.getenv('FLASK_DEBUG', '1') == '1'
    CORS_ORIGINS = os.getenv('CORS_ORIGINS', 'http://localhost:*').split(',')
    
    # DB Connection Pool
    DB_POOL_NAME = 'rpg_portal_pool'
    DB_POOL_SIZE = 5
    DB_POOL_RESET_SESSION = True
    
    @staticmethod
    def get_db_config():
        return {
            'host': Config.DB_HOST,
            'port': Config.DB_PORT,
            'database': Config.DB_NAME,
            'user': Config.DB_USER,
            'password': Config.DB_PASSWORD,
            'pool_name': Config.DB_POOL_NAME,
            'pool_size': Config.DB_POOL_SIZE,
            'pool_reset_session': Config.DB_POOL_RESET_SESSION,
            'charset': 'utf8mb4',
            'use_unicode': True,
        }
        
if __name__ == '__main__':
    print("🔍 DEBUG CONFIG:")
    print(f"  DB_USER: '{Config.DB_USER}'")
    print(f"  DB_PASSWORD: '{Config.DB_PASSWORD}'")
    print(f"  DB_NAME: '{Config.DB_NAME}'")
    print(f"  JWT_SECRET_KEY: '{Config.JWT_SECRET_KEY[:10]}...'")