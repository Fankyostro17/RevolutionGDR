from flask import Blueprint, request, jsonify
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
    if not token: return jsonify({'error': 'Token mancante'}), 401
    payload = JWTHandler.verify_token(token)
    if not payload: return jsonify({'error': 'Token non valido'}), 401
    
    adv = AdventureModel.get_by_id(adventure_id)
    if not adv or adv.get('created_by') != payload['user_id']:
        return jsonify({'error': 'Non autorizzato'}), 403
    
    new_status = 'ended' if adv['status'] == 'active' else 'active'
    updated = AdventureModel.update(adventure_id, payload['user_id'], status=new_status)
    _format_dates_for_flutter(updated)
    return jsonify({'message': 'Stato aggiornato', 'adventure': updated}), 200

def _format_dates_for_flutter(data: dict) -> dict:
    """
    Converte tutti i campi data in formato ISO 8601 (YYYY-MM-DDTHH:MM:SS)
    che Flutter può parsare con DateTime.parse()
    """
    date_fields = ['created_at', 'updated_at', 'next_session', 'last_session', 'date_of_birth']
    
    for field in date_fields:
        if field in data and data[field] is not None:
            value = data[field]
            # Se è un oggetto datetime, convertilo
            if hasattr(value, 'isoformat'):
                data[field] = value.isoformat()
            # Se è già una stringa ma nel formato sbagliato, prova a parsare e riformattare
            elif isinstance(value, str):
                try:
                    # Prova a parsare e riformattare in ISO
                    from datetime import datetime
                    # Gestione formati comuni di MariaDB/MySQL
                    for fmt in ['%a, %d %b %Y %H:%M:%S GMT', '%Y-%m-%d %H:%M:%S', '%Y-%m-%dT%H:%M:%S']:
                        try:
                            dt = datetime.strptime(value, fmt)
                            data[field] = dt.isoformat()
                            break
                        except ValueError:
                            continue
                except:
                    # Se non riesci a parsare, lascia la stringa originale
                    pass
    
    return data