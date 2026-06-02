from database import Database
import uuid

class AdventureFileModel:
    TABLE = 'adventure_files'
    
    @staticmethod
    def create(adventure_id: str, file_name: str, file_url: str, file_type: str, file_size: int) -> dict | None:
        """Salva un file nel database"""
        try:
            file_id = str(uuid.uuid4())
            query = f"""
                INSERT INTO {AdventureFileModel.TABLE} 
                (id, adventure_id, file_name, file_url, file_type, file_size, uploaded_at)
                VALUES (%s, %s, %s, %s, %s, %s, NOW())
            """
            params = (file_id, adventure_id, file_name, file_url, file_type, file_size)
            Database.execute_query(query, params, fetch=False)
            return AdventureFileModel.get_by_id(file_id)
        except Exception as e:
            print(f"❌ Errore creazione file: {e}")
            return None
    
    @staticmethod
    def get_by_id(file_id: str) -> dict | None:
        query = f"SELECT * FROM {AdventureFileModel.TABLE} WHERE id = %s"
        result = Database.execute_query(query, (file_id,))
        return result[0] if result else None
    
    @staticmethod
    def get_by_adventure(adventure_id: str) -> list[dict]:
        """Ottiene tutti i file di un'avventura"""
        query = f"""
            SELECT * FROM {AdventureFileModel.TABLE} 
            WHERE adventure_id = %s 
            ORDER BY uploaded_at DESC
        """
        return Database.execute_query(query, (adventure_id,)) or []
    
    @staticmethod
    def delete(file_id: str, adventure_id: str) -> bool:
        """Elimina un file dal database"""
        try:
            query = f"DELETE FROM {AdventureFileModel.TABLE} WHERE id = %s AND adventure_id = %s"
            Database.execute_query(query, (file_id, adventure_id), fetch=False)
            return True
        except Exception as e:
            print(f"❌ Errore eliminazione file: {e}")
            return False
    
    @staticmethod
    def delete_by_filename(filename: str, adventure_id: str) -> bool:
        """Elimina un file dal database usando il nome del file"""
        try:
            query = f"DELETE FROM {AdventureFileModel.TABLE} WHERE file_url LIKE %s AND adventure_id = %s"
            Database.execute_query(query, (f'%{filename}%', adventure_id), fetch=False)
            return True
        except Exception as e:
            print(f"❌ Errore eliminazione file: {e}")
            return False