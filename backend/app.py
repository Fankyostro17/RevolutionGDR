from flask import Flask, jsonify, request
from flask_cors import CORS
from config import Config
from database import Database
from routes.auth import auth_bp
from routes.adventures import adventures_bp
import logging
from flask_socketio import SocketIO, emit, join_room
import mimetypes

mimetypes.add_type('audio/mpeg', '.mp3')
mimetypes.add_type('audio/wav', '.wav')
mimetypes.add_type('audio/ogg', '.ogg')
mimetypes.add_type('audio/mp4', '.m4a')

logging.basicConfig(
    level=logging.INFO if Config.FLASK_DEBUG else logging.WARNING,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def create_app():
    app = Flask(__name__)
    app.config['JSON_SORT_KEYS'] = False
    
    CORS(app, resources={r"/api/*": {"origins": "*"}})
    
    app.register_blueprint(auth_bp)
    app.register_blueprint(adventures_bp)
    
    @app.route('/api/health', methods=['GET'])
    def health():
        try:
            conn = Database.get_connection()
            conn.close()
            return jsonify({'status': 'healthy', 'database': 'connected'}), 200
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return jsonify({'status': 'unhealthy', 'error': str(e)}), 503
    
    @app.errorhandler(404)
    def not_found(e):
        return jsonify({'error': 'Endpoint non trovato'}), 404
    
    @app.errorhandler(500)
    def internal_error(e):
        logger.error(f"Internal error: {e}")
        return jsonify({'error': 'Errore interno del server'}), 500
    
    logger.info("🚀 Applicazione Flask avviata")
    return app

app = create_app()
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# 🔹 NUOVO: Dizionario per mantenere lo stato dell'host per ogni avventura
hosting_status = {}
current_playing_tracks = {}

@socketio.on('connect')
def on_connect():
    print(f'🔗 Client connesso: {request.sid}')

@socketio.on('join_session')
def on_join_session(data):
    adventure_id = data.get('adventure_id')
    user_name = data.get('user_name', 'Sconosciuto')
    join_room(adventure_id)
    print(f'👤 {user_name} entrato in sessione {adventure_id} (SID: {request.sid})')
    
    current_hosting = hosting_status.get(adventure_id, False)
    emit('host_status', {'is_hosting': current_hosting})
    
    current_track = current_playing_tracks.get(adventure_id)
    if current_track:
        emit('play_track', {
            'track_name': current_track['name'],
            'track_url': current_track['url']
        }, room=request.sid)
    
    emit('system_message', {'content': f'{user_name} si è unito alla sessione'}, room=adventure_id)

@socketio.on('host_toggle')
def on_host_toggle(data):
    adventure_id = data.get('adventure_id')
    is_hosting = data.get('is_hosting')
    
    hosting_status[adventure_id] = is_hosting
    
    emit('host_status', {'is_hosting': is_hosting}, room=adventure_id)
    
    if not is_hosting:
        emit('host_closed', {}, room=adventure_id)
    
    print(f'🎮 Host status per {adventure_id}: {is_hosting}')

@socketio.on('send_message')
def on_send_message(data):
    adventure_id = data.get('adventure_id')
    emit('new_message', data, room=adventure_id, include_self=False)
    
@socketio.on('play_track')
def on_play_track(data):
    adventure_id = data.get('adventure_id')
    track_name = data.get('track_name')
    track_url = data.get('track_url')
    
    current_playing_tracks[adventure_id] = {
        'name': track_name,
        'url': track_url
    }
    
    emit('play_track', {'track_name': track_name, 'track_url': track_url}, room=adventure_id)

@socketio.on('stop_track')
def on_stop_track(data):
    adventure_id = data.get('adventure_id')
    
    if adventure_id in current_playing_tracks:
        del current_playing_tracks[adventure_id]
        
    emit('stop_track', {}, room=adventure_id)
    
@socketio.on('play_sfx')
def on_play_sfx(data):
    adventure_id = data.get('adventure_id')
    sfx_name = data.get('sfx_name')
    sfx_url = data.get('sfx_url')
    emit('play_sfx', {'sfx_name': sfx_name, 'sfx_url': sfx_url}, room=adventure_id)
    
@socketio.on('map_changed')
def on_map_changed(data):
    adventure_id = data.get('adventure_id')
    map_url = data.get('map_url')
    emit('map_changed', {'map_url': map_url}, room=adventure_id)
    print(f'🗺️ Mappa cambiata per {adventure_id}: {map_url}')

@socketio.on('disconnect')
def on_disconnect():
    print(f'🔌 Client disconnesso: {request.sid}')

if __name__ == '__main__':
    logger.info(f"🔧 Ambiente: {Config.FLASK_ENV}, Debug: {Config.FLASK_DEBUG}")
    socketio.run(app, host='0.0.0.0', port=8000, debug=Config.FLASK_DEBUG, allow_unsafe_werkzeug=True)