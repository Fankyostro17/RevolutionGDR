from database import Database
from flask import Blueprint, request, jsonify
import uuid
from models.adventure import AdventureModel
from utils.jwt_handler import JWTHandler
from models.user import UserModel

adventures_bp = Blueprint('adventures', __name__, url_prefix='/api/adventures')

@adventures_bp.route('', methods=['POST'])
def create_adventure():
    """Crea una nuova campagna (solo per Master)"""
    auth_header = request.headers.get('Authorization')
    token = JWTHandler.token_from_header(auth_header)
    if not token:
        return jsonify({'error': 'Token mancante'}), 401
    
    payload = JWTHandler.verify_token(token)
    if not payload:
        return jsonify({'error': 'Token non valido'}), 401
    
    data = request.get_json()
    if not data or 'title' not in data:
        return jsonify({'error': 'Titolo obbligatorio'}), 400
    
    title = data['title'].strip()
    subtitle = data.get('subtitle', '').strip()
    description = data.get('description', '').strip()
    
    level_min = data.get('level_min', 1)
    level_max = data.get('level_max', 20)
    max_players = data.get('max_players', 0)
    
    next_sess = data.get('next_session')
    is_one_shot = data.get('is_one_shot', False)
    
    if not subtitle:
        subtitle = f"Liv. {level_min}-{level_max} • Max {max_players} giocatori"

    adventure = AdventureModel.create(
        title=title,
        subtitle=subtitle,
        description=description,
        created_by=payload['user_id'],
        role='master',
        status='active',
        level_min=level_min,
        level_max=level_max,
        max_players=max_players,
        next_session=next_sess,
        is_one_shot=is_one_shot
    )
    
    if not adventure:
        return jsonify({'error': 'Creazione fallita'}), 500
    
    _format_dates_for_flutter(adventure)
    
    return jsonify({
        'message': 'Campagna creata',
        'adventure': adventure
    }), 201

@adventures_bp.route('', methods=['GET'])
def get_adventures():
    """Ottiene le avventure dell'utente loggato"""
    auth_header = request.headers.get('Authorization')
    token = JWTHandler.token_from_header(auth_header)
    if not token:
        return jsonify({'error': 'Token mancante'}), 401
    
    payload = JWTHandler.verify_token(token)
    if not payload:
        return jsonify({'error': 'Token non valido'}), 401
    
    role = request.args.get('role', 'master')
    if role not in ['master', 'player']:
        role = 'master'
    
    adventures = AdventureModel.get_by_user(payload['user_id'], role)

    for adv in adventures:
        _format_dates_for_flutter(adv)
    
    return jsonify({'adventures': adventures}), 200

@adventures_bp.route('/<adventure_id>/join', methods=['POST'])
def join_adventure(adventure_id: str):
    """Permette a un player di unirsi a una campagna tramite codice"""
    auth_header = request.headers.get('Authorization')
    token = JWTHandler.token_from_header(auth_header)
    if not token:
        return jsonify({'error': 'Token mancante'}), 401
    
    payload = JWTHandler.verify_token(token)
    if not payload:
        return jsonify({'error': 'Token non valido'}), 401
    
    data = request.get_json()
    campaign_code = data.get('campaign_code') if data else None
    
    adventure = AdventureModel.get_by_id(adventure_id)
    if not adventure or (campaign_code and adventure.get('campaign_code') != campaign_code):
        return jsonify({'error': 'Campagna non trovata'}), 404
    
    if AdventureModel.add_participant(adventure_id, payload['user_id']):
        return jsonify({'message': 'Unito alla campagna'}), 200
    
    return jsonify({'error': 'Impossibile unirsi'}), 500

# 🔹 POST /api/adventures/join-by-code - Unisciti a campagna tramite solo codice
@adventures_bp.route('/join-by-code', methods=['POST'])
def join_by_code():
    """
    Permette a un Player di unirsi a una campagna usando SOLO il codice.
    Il sistema cerca automaticamente la campagna associata al codice.
    """
    # 1. Verifica autenticazione
    auth_header = request.headers.get('Authorization')
    token = JWTHandler.token_from_header(auth_header)
    if not token:
        return jsonify({'error': 'Token mancante'}), 401
    
    payload = JWTHandler.verify_token(token)
    if not payload:
        return jsonify({'error': 'Token non valido o scaduto'}), 401
    
    user_id = payload['user_id']
    
    # 2. Estrai il codice dal body della richiesta
    data = request.get_json()
    if not data or 'campaign_code' not in data:
        return jsonify({'error': 'Codice campagna obbligatorio'}), 400
    
    campaign_code = data['campaign_code'].strip().upper()
    
    # 3. Cerca la campagna nel DB tramite join_code
    query = f"""
        SELECT id, title, status, max_players, join_code, created_by,
               (SELECT COUNT(*) FROM {AdventureModel.PARTICIPANTS_TABLE} WHERE adventure_id = adventures.id) as current_players
        FROM {AdventureModel.TABLE}
        WHERE join_code = %s
    """
    result = Database.execute_query(query, (campaign_code,))
    
    if not result:
        return jsonify({'error': 'Codice non valido. Campagna non trovata.'}), 404
    
    adventure = result[0]
    
    if adventure['status'] in ['ended', 'locked']:
        return jsonify({'error': 'Questa campagna non è più accessibile'}), 403
    
    if adventure['created_by'] == user_id:
        return jsonify({'error': 'Sei il Master di questa campagna. Accedi dalla tab Master.'}), 400
    
    if adventure['max_players'] and adventure['current_players'] >= adventure['max_players']:
        return jsonify({'error': 'Campagna piena. Nessun posto disponibile.'}), 409
    
    try:
        check_query = f"""
            SELECT id FROM {AdventureModel.PARTICIPANTS_TABLE}
            WHERE adventure_id = %s AND user_id = %s
        """
        existing = Database.execute_query(check_query, (adventure['id'], user_id))
        
        if existing:
            return jsonify({'message': 'Sei già unito a questa campagna', 'adventure_id': adventure['id']}), 200
        
        participation_id = str(uuid.uuid4())
        insert_query = f"""
            INSERT INTO {AdventureModel.PARTICIPANTS_TABLE} 
            (id, adventure_id, user_id, joined_at)
            VALUES (%s, %s, %s, NOW())
        """
        Database.execute_query(insert_query, (participation_id, adventure['id'], user_id), fetch=False)
        
        _format_dates_for_flutter(adventure)
        
        return jsonify({
            'message': '✅ Unitto alla campagna con successo!',
            'adventure_id': adventure['id'],
            'adventure': adventure
        }), 200
        
    except Exception as e:
        print(f"❌ Errore join_by_code: {e}")
        return jsonify({'error': 'Impossibile unirsi alla campagna. Riprova.'}), 500

@adventures_bp.route('/<adventure_id>', methods=['GET'])
def get_adventure_detail(adventure_id):
    auth_header = request.headers.get('Authorization')
    token = JWTHandler.token_from_header(auth_header)
    if not token: return jsonify({'error': 'Token mancante'}), 401
    
    payload = JWTHandler.verify_token(token)
    if not payload: return jsonify({'error': 'Token non valido'}), 401
    
    adventure = AdventureModel.get_by_id(adventure_id)
    if not adventure:
        return jsonify({'error': 'Campagna non trovata'}), 404
    
    _format_dates_for_flutter(adventure)
    return jsonify({'adventure': adventure}), 200

@adventures_bp.route('/<adventure_id>', methods=['PUT'])
def update_adventure(adventure_id):
    auth_header = request.headers.get('Authorization')
    token = JWTHandler.token_from_header(auth_header)
    if not token: return jsonify({'error': 'Token mancante'}), 401
    
    payload = JWTHandler.verify_token(token)
    if not payload: return jsonify({'error': 'Token non valido'}), 401
    
    data = request.get_json()
    if not data: return jsonify({'error': 'Dati mancanti'}), 400
    
    updated = AdventureModel.update(adventure_id, payload['user_id'], **data)
    if not updated:
        return jsonify({'error': 'Non autorizzato o campagna non trovata'}), 403
    
    _format_dates_for_flutter(updated)
    return jsonify({'message': 'Campagna aggiornata', 'adventure': updated}), 200

@adventures_bp.route('/<adventure_id>', methods=['DELETE'])
def delete_adventure(adventure_id):
    auth_header = request.headers.get('Authorization')
    token = JWTHandler.token_from_header(auth_header)
    if not token: return jsonify({'error': 'Token mancante'}), 401
    payload = JWTHandler.verify_token(token)
    if not payload: return jsonify({'error': 'Token non valido'}), 401
    
    if AdventureModel.delete(adventure_id, payload['user_id']):
        return jsonify({'message': 'Campagna eliminata e giocatori rimossi'}), 200
    return jsonify({'error': 'Non autorizzato'}), 403

@adventures_bp.route('/<adventure_id>/status', methods=['PATCH'])
def toggle_status(adventure_id):
    auth_header = request.headers.get('Authorization')
    token = JWTHandler.token_from_header(auth_header)
    if not token: 
        return jsonify({'error': 'Token mancante'}), 401
    
    payload = JWTHandler.verify_token(token)
    if not payload: 
        return jsonify({'error': 'Token non valido'}), 401
    
    adv = AdventureModel.get_by_id(adventure_id)
    if not adv or adv.get('created_by') != payload['user_id']:
        return jsonify({'error': 'Non autorizzato'}), 403
    
    current_status = adv.get('status', 'active')
    new_status = 'ended' if current_status == 'active' else 'active'
    
    updated = AdventureModel.update(adventure_id, payload['user_id'], status=new_status)
    if not updated:
        return jsonify({'error': 'Update fallito'}), 500
    
    _format_dates_for_flutter(updated)
    return jsonify({'message': 'Stato aggiornato', 'adventure': updated}), 200

def _format_dates_for_flutter(data: dict) -> dict:
    """Converte datetime → stringa ISO 8601 per Flutter"""
    date_fields = ['created_at', 'updated_at', 'next_session', 'last_session', 'date_of_birth']
    for field in date_fields:
        if field in data and data[field] is not None:
            value = data[field]
            if hasattr(value, 'isoformat'):
                data[field] = value.isoformat()
            elif isinstance(value, str) and 'GMT' in value:
                from email.utils import parsedate_to_datetime
                try:
                    dt = parsedate_to_datetime(value)
                    data[field] = dt.isoformat()
                except:
                    pass
    return data