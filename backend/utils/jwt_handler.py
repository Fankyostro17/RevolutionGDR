import jwt
import datetime
from config import Config

class JWTHandler:
    @staticmethod
    def generate_token(user_id: str, nickname: str) -> str:
        """Genera un JWT token per l'utente"""
        payload = {
            'user_id': user_id,
            'nickname': nickname,
            'exp': datetime.datetime.utcnow() + datetime.timedelta(
                hours=Config.JWT_EXPIRATION_HOURS
            ),
            'iat': datetime.datetime.utcnow()
        }
        return jwt.encode(payload, Config.JWT_SECRET_KEY, algorithm='HS256')
    
    @staticmethod
    def verify_token(token: str) -> dict | None:
        """Verifica e decodifica un token, restituisce il payload o None"""
        try:
            payload = jwt.decode(token, Config.JWT_SECRET_KEY, algorithms=['HS256'])
            return payload
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None
    
    @staticmethod
    def token_from_header(header: str) -> str | None:
        """Estrae il token da un header 'Authorization: Bearer <token>'"""
        if not header or not header.startswith('Bearer '):
            return None
        return header[7:]  # Rimuove 'Bearer '