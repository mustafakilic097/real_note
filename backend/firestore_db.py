from google.cloud import firestore
import os

def get_db():
    return firestore.Client()
