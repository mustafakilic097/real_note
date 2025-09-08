from flask import Flask, jsonify, request, g
from flask_cors import CORS
from datetime import datetime, timezone
from uuid import uuid4
import os

from auth import require_auth
from firestore_db import get_db
from models import NoteIn, NoteOut

app = Flask(__name__)


origins_env = os.environ.get("CORS_ORIGINS", "*")
origins = [o.strip() for o in origins_env.split(",")] if origins_env else ["*"]
CORS(app, resources={
     r"/*": {"origins": origins, "supports_credentials": False}})


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def to_note_out(id: str, data: dict) -> dict:
    return NoteOut(
        id=id,
        userId=data["userId"],
        title=data.get("title", ""),
        content=data.get("content", ""),
        createdAt=data.get("createdAt"),
        updatedAt=data.get("updatedAt"),
    ).model_dump()


@app.get("/health")
def health():
    return jsonify({"status": "ok"})


@app.get("/notes")
@require_auth
def list_notes():
    db = get_db()

    q = db.collection("notes").where("userId", "==", g.user_id).stream()
    items = []
    for doc in q:
        data = doc.to_dict()
        items.append(to_note_out(doc.id, data))

    items.sort(key=lambda x: x["updatedAt"], reverse=True)
    return jsonify(items)


@app.get("/whoami")
@require_auth
def whoami():
    return jsonify({"uid": g.user_id})

@app.post("/notes")
@require_auth
def create_note():
    try:
        payload = NoteIn.model_validate_json(request.data)
    except Exception as e:
        return jsonify({"error": "bad_request", "details": str(e)}), 400

    db = get_db()
    body_id = (request.get_json() or {}).get("id")
    doc_id = body_id or str(uuid4())
    ref = db.collection("notes").document(doc_id)
    snap = ref.get()

    if snap.exists:
        doc = snap.to_dict()

        if doc.get("userId") != g.user_id:
            return jsonify({"error": "forbidden", "reason": "id_taken_by_other"}), 403

        return jsonify({"error": "conflict", "reason": "id_already_exists"}), 409

    ts = now_iso()
    body = {
        "userId": g.user_id,
        "title": payload.title,
        "content": payload.content or "",
        "createdAt": ts,
        "updatedAt": ts,
    }
    ref.set(body)
    return jsonify(to_note_out(doc_id, body)), 201


@app.put("/notes/<note_id>")
@require_auth
def update_note(note_id):
    try:
        payload = NoteIn.model_validate_json(request.data)
    except Exception as e:
        return jsonify({"error": "bad_request", "details": str(e)}), 400

    db = get_db()
    ref = db.collection("notes").document(note_id)
    snap = ref.get()
    if not snap.exists:
        return jsonify({"error": "not_found"}), 404

    doc = snap.to_dict()
    if doc.get("userId") != g.user_id:
        return jsonify({"error": "forbidden"}), 403

    updated = {
        **doc,
        "title": payload.title,
        "content": payload.content or "",
        "updatedAt": now_iso(),
    }
    ref.set(updated, merge=True)
    return jsonify(to_note_out(note_id, updated))


@app.delete("/notes/<note_id>")
@require_auth
def delete_note(note_id):
    db = get_db()
    ref = db.collection("notes").document(note_id)
    snap = ref.get()
    if not snap.exists:
        return jsonify({"error": "not_found"}), 404
    doc = snap.to_dict()
    if doc.get("userId") != g.user_id:
        return jsonify({"error": "forbidden"}), 403
    ref.delete()
    return jsonify({"ok": True})


if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()
    port = int(os.environ.get("PORT", 8000))
    app.run(host="0.0.0.0", port=port, debug=True)
