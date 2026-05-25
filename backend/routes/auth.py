from flask import Blueprint, request, jsonify
from models.user import UserModel
from utils.jwt_handler import JWTHandler
import re

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')

# 🔹 Validazioni helper
def validate_email(email: str) -> bool:
    return bool(re.match(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$', email))

def validate_nickname(nickname: str) -> bool:
    return bool(re.match(r'^[a-zA-Z0-9_]{3,50}$', nickname))

def validate_password(password: str) -> bool:
    return len(password) >= 8

def validate_date(date_str: str) -> bool:
    try:
        from datetime import datetime
        datetime.strptime(date_str, '%Y-%m-%d')
        return True
    except:
        return False

# 🔹 POST /api/auth/register
@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    
    # Validazione input
    required = ['email', 'password', 'nickname', 'date_of_birth']
    if not all(k in data for k in required):
        return jsonify({'error': 'Campi obbligatori mancanti'}), 400
    
    email = data['email'].strip().lower()
    nickname = data['nickname'].strip()
    password = data['password']
    date_of_birth = data['date_of_birth']  # Formato: 'YYYY-MM-DD'
    
    # Validazioni
    if not validate_email(email):
        return jsonify({'error': 'Email non valida'}), 400
    if not validate_nickname(nickname):
        return jsonify({'error': 'Nickname: 3-50 caratteri, solo lettere/numeri/underscore'}), 400
    if not validate_password(password):
        return jsonify({'error': 'Password: minimo 8 caratteri'}), 400
    if not validate_date(date_of_birth):
        return jsonify({'error': 'Data di nascita: formato YYYY-MM-DD'}), 400
    
    # Controlla duplicati
    if UserModel.email_exists(email):
        return jsonify({'error': 'Email già registrata'}), 409
    if UserModel.nickname_exists(nickname):
        return jsonify({'error': 'Nickname già in uso'}), 409
    
    # Crea utente
    user = UserModel.create(email, nickname, password, date_of_birth)
    if not user:
        return jsonify({'error': 'Registrazione fallita'}), 500
    
    # Rimuovi campi sensibili per la risposta
    user.pop('password_hash', None)
    
    return jsonify({
        'message': 'Registrazione completata',
        'user': user
    }), 201

# 🔹 POST /api/auth/login
@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    
    if not data or 'identifier' not in data or 'password' not in data:
        return jsonify({'error': 'Email/nickname e password richiesti'}), 400
    
    identifier = data['identifier'].strip()
    password = data['password']
    
    # Cerca utente
    user = UserModel.get_by_identifier(identifier)
    if not user:
        return jsonify({'error': 'Credenziali non valide'}), 401
    
    # Verifica password
    if not UserModel.verify_password(password, user['password_hash']):
        return jsonify({'error': 'Credenziali non valide'}), 401
    
    # Genera token JWT
    token = JWTHandler.generate_token(user['id'], user['nickname'])
    
    # 🔹 FIX: Prepara risposta sicura e formatta le date per Flutter
    user_safe = {k: v for k, v in user.items() if k != 'password_hash'}
    
    # Forza formato ISO 8601 per le date (Flutter le legge nativamente)
    if user_safe.get('date_of_birth'):
        # Se è un oggetto datetime, convertilo a stringa
        if hasattr(user_safe['date_of_birth'], 'isoformat'):
            user_safe['date_of_birth'] = user_safe['date_of_birth'].isoformat()
        # Se è già una stringa, assicurati che sia YYYY-MM-DD
        elif isinstance(user_safe['date_of_birth'], str):
            user_safe['date_of_birth'] = user_safe['date_of_birth'][:10] # Prendi solo la data
            
    if user_safe.get('created_at'):
        if hasattr(user_safe['created_at'], 'isoformat'):
            user_safe['created_at'] = user_safe['created_at'].isoformat()
    
    return jsonify({
        'message': 'Login effettuato',
        'access_token': token,
        'token_type': 'bearer',
        'user': user_safe
    }), 200

# 🔹 POST /api/auth/logout (opzionale per JWT stateless)
@auth_bp.route('/logout', methods=['POST'])
def logout():
    # Per JWT stateless, il logout è client-side (elimina il token)
    # Se vuoi invalidare server-side, serve una blacklist Redis/DB
    return jsonify({'message': 'Logout effettuato'}), 200

# 🔹 GET /api/auth/me (ottieni dati utente corrente)
@auth_bp.route('/me', methods=['GET'])
def get_current_user():
    auth_header = request.headers.get('Authorization')
    token = JWTHandler.token_from_header(auth_header)
    
    if not token:
        return jsonify({'error': 'Token mancante'}), 401
    
    payload = JWTHandler.verify_token(token)
    if not payload:
        return jsonify({'error': 'Token non valido o scaduto'}), 401
    
    user = UserModel.get_by_id(payload['user_id'])
    if not user:
        return jsonify({'error': 'Utente non trovato'}), 404
    
    return jsonify({'user': user}), 200