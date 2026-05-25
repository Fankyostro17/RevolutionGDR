import mysql.connector
from mysql.connector import pooling, Error
from config import Config
import logging

logger = logging.getLogger(__name__)

class Database:
    _pool = None
    
    @classmethod
    def get_pool(cls):
        """Restituisce il connection pool (singleton)"""
        if cls._pool is None:
            try:
                cls._pool = pooling.MySQLConnectionPool(**Config.get_db_config())
                logger.info("✅ Pool di connessioni MySQL creato")
            except Error as e:
                logger.error(f"❌ Errore nella creazione del pool: {e}")
                raise
        return cls._pool
    
    @classmethod
    def get_connection(cls):
        """Ottiene una connessione dal pool"""
        return cls.get_pool().get_connection()
    
    @classmethod
    def execute_query(cls, query: str, params: tuple = None, fetch: bool = True):
        """Esegue una query e restituisce i risultati (se fetch=True)"""
        conn = cls.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(query, params or ())
            if fetch:
                result = cursor.fetchall()
                return result
            conn.commit()
            return cursor.lastrowid
        except Error as e:
            conn.rollback()
            logger.error(f"❌ Errore query: {e}\nQuery: {query}")
            raise
        finally:
            cursor.close()
            conn.close()
    
    @classmethod
    def execute_many(cls, query: str, params_list: list):
        """Esegue INSERT/UPDATE multipli"""
        conn = cls.get_connection()
        cursor = conn.cursor()
        try:
            cursor.executemany(query, params_list)
            conn.commit()
            return cursor.rowcount
        except Error as e:
            conn.rollback()
            logger.error(f"❌ Errore executemany: {e}")
            raise
        finally:
            cursor.close()
            conn.close()