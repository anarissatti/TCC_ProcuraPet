import firebase_admin
from firebase_admin import firestore, storage, functions
from google.cloud import vertexai
from google.cloud.storage import Blob
import numpy as np

# --- INICIALIZAÇÃO --
firebase_admin.initialize_app()
db = firestore.client()
# Inicializa a Vertex AI
vertex_ai = vertexai.init(project="tcc-procurapet", location="us-central1")
model = vertex_ai.get_generative_model(model_id="multimodalembedding@001")


# Helper function para calcular a Similaridade de Cosseno
def cosine_similarity(vec_a: list, vec_b: list) -> float:
    """Calcula a similaridade de cosseno entre dois vetores."""
    dot_product = np.dot(vec_a, vec_b)
    norm_a = np.linalg.norm(vec_a)
    norm_b = np.linalg.norm(vec_b)
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot_product / (norm_a * norm_b)


@functions.firestore.on_document_created(document='animals/{animalId}')
def generate_image_vector(data, context):
    """
    Função acionada quando um novo animal é cadastrado.
    Ela busca a foto no Storage, gera o vetor e salva no Firestore.
    """
    animal_id = context.params['animalId']
    print(f"Processando imagem para o animal ID: {animal_id}")

    try:
        # A URL da foto precisa ser salva no Firestore no momento do cadastro do animal
        photo_url = data.get("fotoUrl")
        if not photo_url:
            print("Documento sem fotoUrl. Ignorando.")
            return

        # Busca o blob da imagem no Storage a partir da URL
        blob_name = photo_url.split("animals%2F")[1].split("?")[0]
        bucket = storage.bucket()
        blob = Blob(blob_name, bucket)
        image_bytes = blob.download_as_bytes()

        # Chama a API de IA para obter o embedding (vetor)
        request = {
            "contents": [{
                "parts": [
                    {"inlineData": {"mime_type": "image/jpeg", "data": image_bytes}}
                ],
            }],
        }
        
        response = model.generate_content(request=request)
        image_vector = response.candidates[0].content.parts[0].embedding.values

        # Salva o vetor no documento do animal no Firestore
        db.collection("animals").document(animal_id).update({
            "imageVector": image_vector,
            "vectorGeneratedAt": firestore.SERVER_TIMESTAMP
        })
        print(f"Vetor gerado e salvo para o animal {animal_id}")
    except Exception as e:
        print(f"Erro ao processar a imagem do animal {animal_id}: {e}")
        return

@functions.https.on_request()
def find_similar_animals(request):
    """
    Função HTTP que busca animais parecidos com base em uma imagem.
    """
    try:
        request_json = request.get_json()
        image_base64 = request_json.get("image")
        
        if not image_base64:
            return functions.https.Response({"error": "A imagem em base64 é necessária."}, 400)

        # 1. Gera o vetor para a imagem de busca
        request = {
            "contents": [{
                "parts": [
                    {"inlineData": {"mime_type": "image/jpeg", "data": image_base64}}
                ],
            }],
        }
        response = model.generate_content(request=request)
        search_vector = response.candidates[0].content.parts[0].embedding.values

        # 2. Busca todos os animais no Firestore que já têm um vetor
        animals_snapshot = db.collection("animals") \
            .where("imageVector", "!=", None) \
            .stream()

        similar_animals = []
        for doc in animals_snapshot:
            animal_data = doc.to_dict()
            stored_vector = animal_data.get("imageVector")
            if stored_vector:
                similarity = cosine_similarity(search_vector, stored_vector)
                similar_animals.append({
                    "id": doc.id,
                    "data": animal_data,
                    "similarity": similarity
                })

        # 3. Ordena por maior similaridade e retorna os 10 melhores
        similar_animals.sort(key=lambda x: x["similarity"], reverse=True)
        return functions.https.Response(similar_animals[:10])

    except Exception as e:
        print(f"Erro ao chamar a função: {e}")
        return functions.https.Response({"error": str(e)}, 500)