from flask import Flask, jsonify
from flask_cors import CORS
from config import Config
from database import Database
from routes.auth import auth_bp
from routes.adventures import adventures_bp
import logging

# Configura logging
logging.basicConfig(
    level=logging.INFO if Config.FLASK_DEBUG else logging.WARNING,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def create_app():
    app = Flask(__name__)
    app.config['JSON_SORT_KEYS'] = False
    
    # CORS per Flutter (localhost in dev)
    CORS(app, resources={r"/api/*": {"origins": Config.CORS_ORIGINS}})
    
    # Registra blueprint
    app.register_blueprint(auth_bp)
    app.register_blueprint(adventures_bp)
    
    # Health check endpoint
    @app.route('/api/health', methods=['GET'])
    def health():
        try:
            # Testa connessione DB
            conn = Database.get_connection()
            conn.close()
            return jsonify({'status': 'healthy', 'database': 'connected'}), 200
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return jsonify({'status': 'unhealthy', 'error': str(e)}), 503
    
    # Error handler globale
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

if __name__ == '__main__':
    logger.info(f"🔧 Ambiente: {Config.FLASK_ENV}, Debug: {Config.FLASK_DEBUG}")
    app.run(
        host='0.0.0.0',
        port=8000,
        debug=Config.FLASK_DEBUG
    )