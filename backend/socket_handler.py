from flask_socketio import SocketIO, emit, join_room, leave_room
from flask import request

# In app.py, dopo gli altri import:
from flask_socketio import SocketIO
socketio = SocketIO(cors_allowed_origins="*")

# 🔹 Eventi WebSocket
@socketio.on('connect')
def on_connect():
    print(f'🔗 Client connesso: {request.sid}')
    emit('connected', {'msg': 'Connesso al server'})

@socketio.on('join_session')
def on_join_session(data):
    adventure_id = data.get('adventure_id')
    join_room(adventure_id)
    print(f'👤 {data.get("user")} entrato in sessione {adventure_id}')
    emit('user_joined', {'user': data.get('user')}, room=adventure_id)

@socketio.on('host_toggle')
def on_host_toggle(data):
    adventure_id = data.get('adventure_id')
    is_hosting = data.get('is_hosting')
    # Broadcast a tutti nella stanza
    emit('host_status', {'is_hosting': is_hosting}, room=adventure_id)

@socketio.on('send_message')
def on_send_message(data):
    adventure_id = data.get('adventure_id')
    # Broadcast chat/dadi a tutti tranne il mittente
    emit('new_message', data, room=adventure_id, include_self=False)

@socketio.on('disconnect')
def on_disconnect():
    print(f'🔌 Client disconnesso: {request.sid}')