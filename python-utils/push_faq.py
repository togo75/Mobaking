import json
import sys
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

def seed_data(json_file_path):
    # 1. Initialize the SDK with your Service Account
    try:
        cred = credentials.Certificate('.service-keys/mobilebamking-faq-manager.json')
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"❌ Error initializing Firebase: {e}")
        return

    db = firestore.client()

    # 2. Load the JSON data
    try:
        with open(json_file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"❌ Error: File '{json_file_path}' not found.")
        return
    except json.JSONDecodeError:
        print(f"❌ Error: Failed to decode JSON. Check your file format.")
        return

    # 3. Prepare the batch
    batch = db.batch()
    collection_ref = db.collection('FAQ')

    print(f"🚀 Preparing to upload {len(data)} entries...")

    for entry in data:
        # Create a new document reference with an auto-generated ID
        doc_ref = collection_ref.document()

        # Add the entry to the batch
        batch.set(doc_ref, {
            "question": entry.get("question"),
            "answer": entry.get("answer"),
            "topic": entry.get("topic"),
            "category": entry.get("category"),
            "createdAt": firestore.SERVER_TIMESTAMP
        })

    # 4. Commit the batch
    try:
        batch.commit()
        print(f"✅ Success! {len(data)} entries pushed to the 'FAQ' collection.")
    except Exception as e:
        print(f"❌ Failed to commit batch: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python seed_faq.py data.json")
    else:
        seed_data(sys.argv[1])