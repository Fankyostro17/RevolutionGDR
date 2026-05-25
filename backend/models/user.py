from database import Database
import bcrypt
import uuid

class UserModel:
    TABLE = 'users'
    
    @staticmethod
    def hash_password(password: str) -> str:
        """Hasha la password con bcrypt"""
        return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt(rounds=12)).decode('utf-8')
    
    @staticmethod
    def verify_password(password: str, password_hash: str) -> bool:
        """Verifica la password contro l'hash"""
        return bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8'))
    
    @staticmethod
    def create(email: str, nickname: str, password: str, date_of_birth: str) -> dict | None:
        """Crea un nuovo utente. Restituisce i dati utente o None se fallisce."""
        try:
            user_id = str(uuid.uuid4())
            password_hash = UserModel.hash_password(password)
            
            query = f"""
                INSERT INTO {UserModel.TABLE} 
                (id, email, nickname, password_hash, date_of_birth)
                VALUES (%s, %s, %s, %s, %s)
            """
            params = (user_id, email, nickname, password_hash, date_of_birth)
            
            Database.execute_query(query, params, fetch=False)
            
            return UserModel.get_by_id(user_id)
        except Exception as e:
            print(f"❌ Errore creazione utente: {e}")
            return None
    
    @staticmethod
    def get_by_id(user_id: str) -> dict | None:
        """Ottiene un utente per ID (senza password_hash)"""
        query = f"""
            SELECT id, email, nickname, date_of_birth, created_at 
            FROM {UserModel.TABLE} 
            WHERE id = %s
        """
        result = Database.execute_query(query, (user_id,))
        return result[0] if result else None
    
    @staticmethod
    def get_by_identifier(identifier: str) -> dict | None:
        """Cerca utente per email O nickname (per login)"""
        query = f"""
            SELECT id, email, nickname, password_hash, date_of_birth, created_at 
            FROM {UserModel.TABLE} 
            WHERE email = %s OR nickname = %s
        """
        result = Database.execute_query(query, (identifier, identifier))
        return result[0] if result else None
    
    @staticmethod
    def email_exists(email: str) -> bool:
        """Verifica se un'email è già registrata"""
        query = f"SELECT COUNT(*) as count FROM {UserModel.TABLE} WHERE email = %s"
        result = Database.execute_query(query, (email,))
        return result[0]['count'] > 0 if result else False
    
    @staticmethod
    def nickname_exists(nickname: str) -> bool:
        """Verifica se un nickname è già registrato"""
        query = f"SELECT COUNT(*) as count FROM {UserModel.TABLE} WHERE nickname = %s"
        result = Database.execute_query(query, (nickname,))
        return result[0]['count'] > 0 if result else False