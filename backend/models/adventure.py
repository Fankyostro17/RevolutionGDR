from database import Database
import uuid
import string
import random
from datetime import datetime

class AdventureModel:
    TABLE = 'adventures'
    PARTICIPANTS_TABLE = 'adventure_participants'
    
    @staticmethod
    def _generate_join_code() -> str:
        return ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))
    
    @staticmethod
    def create(title: str, subtitle: str, description: str, created_by: str, 
               role: str = 'master', status: str = 'active', 
               level_min: int = 1, level_max: int = 20, max_players: int = 0,
               next_session: str = None, is_one_shot: bool = False) -> dict | None:
        try:
            adventure_id = str(uuid.uuid4())
            join_code = AdventureModel._generate_join_code()
            
            mysql_next = None
            if next_session:
                try: mysql_next = datetime.fromisoformat(next_session).strftime('%Y-%m-%d %H:%M:%S')
                except: mysql_next = next_session[:19]

            query = f"""
                INSERT INTO {AdventureModel.TABLE} 
                (id, title, subtitle, description, role, status, created_by, created_at, 
                 level_min, level_max, max_players, next_session, join_code, is_one_shot)
                VALUES (%s, %s, %s, %s, %s, %s, %s, NOW(), %s, %s, %s, %s, %s, %s)
            """
            params = (adventure_id, title, subtitle, description, role, status, created_by,
                      level_min, level_max, max_players, mysql_next, join_code, is_one_shot)
            
            Database.execute_query(query, params, fetch=False)
            return AdventureModel.get_by_id(adventure_id)
        except Exception as e:
            print(f"❌ Errore creazione avventura: {e}")
            return None
    
    @staticmethod
    def get_by_id(adventure_id: str) -> dict | None:
        query = f"""
            SELECT a.*, u.nickname as creator_nickname,
                   (SELECT COUNT(*) FROM {AdventureModel.PARTICIPANTS_TABLE} WHERE adventure_id = a.id) as current_players
            FROM {AdventureModel.TABLE} a
            LEFT JOIN users u ON a.created_by = u.id
            WHERE a.id = %s
        """
        result = Database.execute_query(query, (adventure_id,))
        return result[0] if result else None
    
    @staticmethod
    def get_by_user(user_id: str, role: str) -> list[dict]:
        if role == 'master':
            query = f"""
                SELECT a.*, u.nickname as creator_nickname,
                       (SELECT COUNT(*) FROM {AdventureModel.PARTICIPANTS_TABLE} WHERE adventure_id = a.id) as current_players
                FROM {AdventureModel.TABLE} a
                LEFT JOIN users u ON a.created_by = u.id
                WHERE a.created_by = %s ORDER BY a.created_at DESC
            """
            return Database.execute_query(query, (user_id,)) or []
        else:
            query = f"""
                SELECT a.*, u.nickname as creator_nickname,
                       (SELECT COUNT(*) FROM {AdventureModel.PARTICIPANTS_TABLE} WHERE adventure_id = a.id) as current_players
                FROM {AdventureModel.TABLE} a
                JOIN {AdventureModel.PARTICIPANTS_TABLE} ap ON a.id = ap.adventure_id
                LEFT JOIN users u ON a.created_by = u.id
                WHERE ap.user_id = %s ORDER BY a.created_at DESC
            """
            return Database.execute_query(query, (user_id,)) or []
    
    @staticmethod
    def add_participant(adventure_id: str, user_id: str) -> bool:
        """Aggiunge un giocatore a una campagna"""
        try:
            participation_id = str(uuid.uuid4())
            query = f"""
                INSERT INTO {AdventureModel.PARTICIPANTS_TABLE} 
                (id, adventure_id, user_id)
                VALUES (%s, %s, %s)
            """
            params = (participation_id, adventure_id, user_id)
            Database.execute_query(query, params, fetch=False)
            return True
        except Exception as e:
            print(f"❌ Errore aggiunta partecipante: {e}")
            return False
    
    @staticmethod
    def update(adventure_id: str, user_id: str, **kwargs) -> dict | None:
        try:
            adventure = AdventureModel.get_by_id(adventure_id)
            if not adventure or adventure.get('created_by') != user_id: return None

            allowed = ['title', 'subtitle', 'description', 'status', 'next_session', 
                       'level_min', 'level_max', 'max_players', 'is_one_shot']
            updates = {k: v for k, v in kwargs.items() if k in allowed and v is not None}
            if not updates: return adventure

            set_clause = ", ".join([f"{k} = %s" for k in updates.keys()])
            values = list(updates.values()) + [adventure_id]
            Database.execute_query(f"UPDATE {AdventureModel.TABLE} SET {set_clause} WHERE id = %s", tuple(values), fetch=False)
            return AdventureModel.get_by_id(adventure_id)
        except Exception as e:
            print(f"❌ Errore update: {e}")
            return None
        
    @staticmethod
    def delete(adventure_id: str, user_id: str) -> bool:
        try:
            adventure = AdventureModel.get_by_id(adventure_id)
            if not adventure or adventure.get('created_by') != user_id: return False
            Database.execute_query(f"DELETE FROM {AdventureModel.TABLE} WHERE id = %s", (adventure_id,), fetch=False)
            return True
        except Exception as e:
            print(f"❌ Errore delete: {e}")
            return False