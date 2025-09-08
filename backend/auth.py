
from functools import wraps
from flask import request, jsonify, g
import firebase_admin
import os
import json
import base64
from firebase_admin import auth as fb_auth, credentials
from firebase_admin.auth import ExpiredIdTokenError, InvalidIdTokenError, RevokedIdTokenError


def _expected_project_id():

    try:
        with open(os.environ["GOOGLE_APPLICATION_CREDENTIALS"], "r", encoding="utf-8") as f:
            return json.load(f).get("project_id")
    except Exception:
        return None


def _decode_jwt_no_verify(token: str):

    def b64url(s):
        s += "=" * (-len(s) % 4)
        return base64.urlsafe_b64decode(s.encode())
    try:
        header_b64, payload_b64, _sig = token.split(".")
        header = json.loads(b64url(header_b64))
        payload = json.loads(b64url(payload_b64))
        return header, payload
    except Exception:
        return None, None


if not firebase_admin._apps:
    cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not cred_path or not os.path.exists(cred_path):
        raise RuntimeError(
            "GOOGLE_APPLICATION_CREDENTIALS eksik veya dosya yok.")

    with open(cred_path, "r", encoding="utf-8") as f:
        pj = json.load(f).get("project_id")
    firebase_admin.initialize_app(
        credentials.Certificate(cred_path), {'projectId': pj})


def require_auth(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        h = request.headers.get("Authorization", "")
        if not h.startswith("Bearer "):
            return jsonify({"error": "invalid_token", "reason": "missing_bearer"}), 401
        token = h.split(" ", 1)[1].strip().strip('"').strip(
            "'")

        if token.count(".") != 2 or len(token) < 100:
            return jsonify({"error": "invalid_token", "reason": "not_jwt_like"}), 401

        header, payload = _decode_jwt_no_verify(token)
        expected_pid = _expected_project_id()

        try:
            decoded = fb_auth.verify_id_token(token)
            g.user_id = decoded["uid"]

        except ExpiredIdTokenError as e:
            return jsonify({"error": "invalid_token", "reason": "expired", "detail": str(e)}), 401
        except RevokedIdTokenError as e:
            return jsonify({"error": "invalid_token", "reason": "revoked", "detail": str(e)}), 401
        except InvalidIdTokenError as e:

            return jsonify({
                "error": "invalid_token",
                "reason": "invalid",
                "detail": str(e),
                "debug": {
                    "expected_project_id": expected_pid,
                    "iss": payload.get("iss") if payload else None,
                    "aud": payload.get("aud") if payload else None
                }
            }), 401
        except Exception as e:

            return jsonify({"error": "invalid_token", "reason": "other", "detail": str(e)}), 401

        return f(*args, **kwargs)
    return wrapper
